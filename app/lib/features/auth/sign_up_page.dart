import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/widgets/gp_buttons.dart';
import '../../core/widgets/gp_scaffold.dart';

class SignUpPage extends ConsumerStatefulWidget {
  const SignUpPage({super.key});

  @override
  ConsumerState<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends ConsumerState<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _acceptTerms = false;
  bool _isPasswordHidden = true;
  bool _isLoading = false;
  String? _errorText;

  int get _passwordScore {
    final password = _passwordController.text;
    var score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    return score;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signUpWithPassword() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      context.go('/today');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    if (!_acceptTerms) {
      setState(() => _errorText = 'You must accept terms to continue.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await client.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        data: {'full_name': _nameController.text.trim()},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Account created. Check your inbox for verification email.',
          ),
        ),
      );
      context.go('/auth/sign-in');
    } on AuthException catch (error) {
      setState(() => _errorText = error.message);
    } catch (error) {
      setState(() => _errorText = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _signUpWithOAuth(OAuthProvider provider) async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      context.go('/today');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await client.auth.signInWithOAuth(
        provider,
        redirectTo: kIsWeb ? null : 'gridpowercontrol://auth/callback',
      );
    } on AuthException catch (error) {
      setState(() => _errorText = error.message);
    } catch (error) {
      setState(() => _errorText = error.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GpPageScaffold(
      title: 'Create Account',
      showBack: true,
      body: ListView(
        children: [
          Text(
            'Create Your Account',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign up with social providers or create an email account.',
          ),
          const SizedBox(height: 20),
          if (_errorText != null) ...[
            GpSectionCard(
              child: Text(
                _errorText!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
            const SizedBox(height: 12),
          ],
          GpSecondaryButton(
            label: 'Sign up with Google',
            icon: Icons.g_mobiledata,
            onPressed: _isLoading
                ? null
                : () => _signUpWithOAuth(OAuthProvider.google),
          ),
          const SizedBox(height: 8),
          GpSecondaryButton(
            label: 'Sign up with Microsoft',
            icon: Icons.business,
            onPressed: _isLoading
                ? null
                : () => _signUpWithOAuth(OAuthProvider.azure),
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  validator: (value) {
                    if (value == null || !value.contains('@')) {
                      return 'Enter a valid email';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _isPasswordHidden,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () => setState(
                        () => _isPasswordHidden = !_isPasswordHidden,
                      ),
                      icon: Icon(
                        _isPasswordHidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: _passwordScore / 4,
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 6),
          const Text('Password strength'),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _acceptTerms,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text('I agree to Terms and Privacy Policy'),
            onChanged: _isLoading
                ? null
                : (value) => setState(() => _acceptTerms = value ?? false),
          ),
          GpPrimaryButton(
            label: _isLoading ? 'Creating account...' : 'Create Account',
            icon: Icons.person_add_alt_1,
            onPressed: _isLoading ? null : _signUpWithPassword,
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: () => context.go('/auth/sign-in'),
            child: const Text('Already have an account? Sign in'),
          ),
        ],
      ),
    );
  }
}
