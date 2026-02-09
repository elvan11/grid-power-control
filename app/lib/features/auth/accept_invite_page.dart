import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/widgets/gp_buttons.dart';
import '../../core/widgets/gp_scaffold.dart';
import '../../data/sharing_functions_service.dart';

class AcceptInvitePage extends ConsumerStatefulWidget {
  const AcceptInvitePage({required this.token, super.key});

  final String? token;

  @override
  ConsumerState<AcceptInvitePage> createState() => _AcceptInvitePageState();
}

class _AcceptInvitePageState extends ConsumerState<AcceptInvitePage> {
  bool _isSubmitting = false;
  bool? _isSuccess;
  String? _message;

  Future<void> _acceptInvite() async {
    final token = widget.token?.trim();
    if (token == null || token.isEmpty) {
      setState(() {
        _isSuccess = false;
        _message = 'Invite token is missing.';
      });
      return;
    }

    final client = ref.read(supabaseClientProvider);
    if (client != null && client.auth.currentSession == null) {
      context.go(
        '/auth/sign-in?redirect=${Uri.encodeComponent('/auth/accept-invite?token=$token')}',
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
      _isSuccess = null;
      _message = null;
    });
    try {
      final result = await ref
          .read(sharingFunctionsServiceProvider)
          .acceptInvite(token: token);
      if (!mounted) return;
      setState(() {
        _isSuccess = result['ok'] == true;
        _message = _isSuccess == true
            ? 'Invite accepted. You now have access to this installation.'
            : (result['error']?.toString() ?? 'Failed to accept invite.');
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSuccess = false;
        _message = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _acceptInvite();
    });
  }

  @override
  Widget build(BuildContext context) {
    return GpPageScaffold(
      title: 'Accept Invite',
      body: ListView(
        children: [
          GpSectionCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Installation access invitation',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                if (_isSubmitting)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: LinearProgressIndicator(),
                  ),
                if (_message != null) ...[
                  Text(_message!),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    Expanded(
                      child: GpPrimaryButton(
                        label: _isSubmitting ? 'Processing...' : 'Try Again',
                        icon: Icons.refresh,
                        onPressed: _isSubmitting ? null : _acceptInvite,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: GpSecondaryButton(
                        label: 'Open Installations',
                        icon: Icons.grid_view_outlined,
                        onPressed: () => context.go('/installations'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
