import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/widgets/gp_buttons.dart';
import '../../core/widgets/gp_scaffold.dart';
import '../../data/plants_provider.dart';

class SharingPage extends ConsumerStatefulWidget {
  const SharingPage({super.key});

  @override
  ConsumerState<SharingPage> createState() => _SharingPageState();
}

class _SharingPageState extends ConsumerState<SharingPage> {
  final _emailController = TextEditingController();
  final List<String> _emails = [];
  bool _loading = true;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _loadExistingEmails();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadExistingEmails() async {
    final plant = ref.read(selectedPlantProvider);
    final client = ref.read(supabaseClientProvider);
    if (plant == null || client == null || plant.id.startsWith('local-')) {
      setState(() => _loading = false);
      return;
    }
    try {
      final invites = await client
          .from('plant_invites')
          .select('invited_email')
          .eq('plant_id', plant.id)
          .eq('status', 'pending');
      _emails
        ..clear()
        ..addAll(
          (invites as List<dynamic>)
              .map(
                (row) =>
                    (row as Map<String, dynamic>)['invited_email'] as String? ??
                    '',
              )
              .where((email) => email.isNotEmpty),
        );
    } catch (error) {
      _errorText = 'Could not load invite list: $error';
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _addEmail() async {
    final candidate = _emailController.text.trim().toLowerCase();
    if (!_isValidEmail(candidate)) {
      setState(() => _errorText = 'Enter a valid email address.');
      return;
    }
    if (_emails.contains(candidate)) {
      setState(() => _errorText = 'This email is already in the access list.');
      return;
    }

    final plant = ref.read(selectedPlantProvider);
    final client = ref.read(supabaseClientProvider);

    if (plant != null && client != null && !plant.id.startsWith('local-')) {
      final inviter = client.auth.currentUser?.id;
      if (inviter != null) {
        try {
          final tokenHash =
              '${DateTime.now().microsecondsSinceEpoch}-${candidate.hashCode}';
          await client.from('plant_invites').insert({
            'plant_id': plant.id,
            'invited_email': candidate,
            'invited_by_auth_user_id': inviter,
            'role': 'member',
            'token_hash': tokenHash,
            'status': 'pending',
            'expires_at': DateTime.now()
                .add(const Duration(days: 7))
                .toUtc()
                .toIso8601String(),
          });
        } catch (error) {
          setState(() => _errorText = 'Could not store email: $error');
          return;
        }
      }
    }

    setState(() {
      _errorText = null;
      _emails.add(candidate);
      _emailController.clear();
    });
  }

  Future<void> _removeEmail(String email) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove access?'),
        content: Text('Remove $email from the access list?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldRemove != true) {
      return;
    }

    final plant = ref.read(selectedPlantProvider);
    final client = ref.read(supabaseClientProvider);
    if (plant != null && client != null && !plant.id.startsWith('local-')) {
      try {
        await client
            .from('plant_invites')
            .delete()
            .eq('plant_id', plant.id)
            .eq('status', 'pending')
            .eq('invited_email', email);
      } catch (_) {
        // If backend delete fails we still update local preview list.
      }
    }

    setState(() => _emails.remove(email));
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final plant = ref.watch(selectedPlantProvider);
    return GpPageScaffold(
      title: 'Share Installation Access',
      showBack: true,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                if (plant == null) ...[
                  const GpSectionCard(
                    child: Text(
                      'No selected installation. Select one before sharing access.',
                    ),
                  ),
                ] else ...[
                  GpSectionCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Access list for ${plant.name}',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email address',
                            hintText: 'name@example.com',
                          ),
                        ),
                        const SizedBox(height: 10),
                        GpPrimaryButton(
                          label: 'Add Email',
                          icon: Icons.person_add_alt_outlined,
                          onPressed: _addEmail,
                        ),
                        if (_errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _errorText!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (_emails.isEmpty)
                    const GpSectionCard(
                      child: Text('No emails have access yet.'),
                    )
                  else
                    ..._emails.map(
                      (email) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GpSectionCard(
                          child: Row(
                            children: [
                              Expanded(child: Text(email)),
                              IconButton(
                                onPressed: () => _removeEmail(email),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ],
            ),
    );
  }
}
