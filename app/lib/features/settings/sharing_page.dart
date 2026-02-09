import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/widgets/gp_buttons.dart';
import '../../core/widgets/gp_scaffold.dart';
import '../../data/plants_provider.dart';
import '../../data/sharing_functions_service.dart';

class SharingPage extends ConsumerStatefulWidget {
  const SharingPage({super.key});

  @override
  ConsumerState<SharingPage> createState() => _SharingPageState();
}

class _SharingPageState extends ConsumerState<SharingPage> {
  final _emailController = TextEditingController();
  List<PlantMemberEntry> _members = const [];
  List<PlantInviteEntry> _invites = const [];
  bool _loading = true;
  bool _submitting = false;
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
    if (plant == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snapshot = await ref
          .read(sharingFunctionsServiceProvider)
          .listSharing(plantId: plant.id);
      _members = snapshot.members;
      _invites = snapshot.invites;
      _errorText = null;
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
    final existsAsMember = _members.any((member) => member.email == candidate);
    final existsAsInvite = _invites.any(
      (invite) =>
          invite.status == 'pending' && invite.invitedEmail == candidate,
    );
    if (existsAsMember || existsAsInvite) {
      setState(() => _errorText = 'This email is already in the access list.');
      return;
    }

    final plant = ref.read(selectedPlantProvider);
    if (plant == null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final result = await ref
          .read(sharingFunctionsServiceProvider)
          .invite(plantId: plant.id, invitedEmail: candidate, role: 'member');
      _emailController.clear();
      final emailDispatch = result['emailDispatch'] as Map<String, dynamic>?;
      final providerMessage = emailDispatch?['providerMessage'] as String?;
      setState(() {
        _errorText = providerMessage;
      });
      await _loadExistingEmails();
    } catch (error) {
      setState(() => _errorText = 'Could not store email: $error');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _removeInvite(PlantInviteEntry invite) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove access?'),
        content: Text('Remove pending invite for ${invite.invitedEmail}?'),
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
    if (plant == null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(sharingFunctionsServiceProvider)
          .revokeInvite(plantId: plant.id, inviteId: invite.id);
      await _loadExistingEmails();
    } catch (error) {
      setState(() => _errorText = 'Could not remove invite: $error');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _removeMember(PlantMemberEntry member) async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove access?'),
        content: Text(
          'Remove ${member.email ?? member.authUserId} from this plant?',
        ),
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
    if (plant == null) {
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref
          .read(sharingFunctionsServiceProvider)
          .removeMember(plantId: plant.id, memberUserId: member.authUserId);
      await _loadExistingEmails();
    } catch (error) {
      setState(() => _errorText = 'Could not remove member: $error');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  bool _isValidEmail(String value) {
    return RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    final plant = ref.watch(selectedPlantProvider);
    final currentUserId = ref
        .watch(supabaseClientProvider)
        ?.auth
        .currentUser
        ?.id;

    final pendingInvites = _invites
        .where((invite) => invite.status == 'pending')
        .toList(growable: false);

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
                          label: _submitting ? 'Adding...' : 'Add Email',
                          icon: Icons.person_add_alt_outlined,
                          onPressed: _submitting ? null : _addEmail,
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
                  if (_members.isEmpty && pendingInvites.isEmpty)
                    const GpSectionCard(
                      child: Text('No emails have access yet.'),
                    )
                  else ...[
                    ..._members.map((member) {
                      final isCurrentUser = currentUserId == member.authUserId;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GpSectionCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${member.email ?? member.authUserId} (${member.role})'
                                  '${isCurrentUser ? ' • You' : ''}',
                                ),
                              ),
                              IconButton(
                                onPressed: _submitting || isCurrentUser
                                    ? null
                                    : () => _removeMember(member),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                    ...pendingInvites.map(
                      (invite) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GpSectionCard(
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '${invite.invitedEmail} (pending ${invite.role})',
                                ),
                              ),
                              IconButton(
                                onPressed: _submitting
                                    ? null
                                    : () => _removeInvite(invite),
                                icon: const Icon(Icons.remove_circle_outline),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
    );
  }
}
