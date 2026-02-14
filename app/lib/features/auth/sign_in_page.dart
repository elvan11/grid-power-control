import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase/supabase_provider.dart';
import '../../core/widgets/gp_buttons.dart';
import '../../core/widgets/gp_scaffold.dart';

class SignInPage extends ConsumerStatefulWidget {
  const SignInPage({super.key});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordHidden = true;
  bool _isLoading = false;
  String? _errorText;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signInWithPassword() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      context.go('/today');
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
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

  Future<void> _signInWithOAuth(OAuthProvider provider) async {
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

  Future<void> _forgotPassword() async {
    final client = ref.read(supabaseClientProvider);
    if (client == null) {
      return;
    }
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter your email first.')));
      return;
    }
    await client.auth.resetPasswordForEmail(email);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Password reset email sent.')));
  }

  @override
  Widget build(BuildContext context) {
    final client = ref.watch(supabaseClientProvider);
    return GpPageScaffold(
      title: 'Sign In',
      maxContentWidth: double.infinity,
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/auth/sign_in_background.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.2),
                    Theme.of(
                      context,
                    ).scaffoldBackgroundColor.withValues(alpha: 0.9),
                  ],
                  stops: const [0.0, 0.45],
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: ListView(
                children: [
                  const SizedBox(height: 12),
                  Text(
                    'Sign In to Energy Manager',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    client == null
                        ? 'Supabase is not configured. You can continue in offline preview mode.'
                        : 'Use OAuth or your email and password.',
                  ),
                  const SizedBox(height: 20),
                  if (_errorText != null) ...[
                    GpSectionCard(
                      child: Text(
                        _errorText!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  GpSecondaryButton(
                    label: 'Continue with Google',
                    icon: Icons.g_mobiledata,
                    onPressed: _isLoading
                        ? null
                        : () => _signInWithOAuth(OAuthProvider.google),
                  ),
                  const SizedBox(height: 8),
                  GpSecondaryButton(
                    label: 'Continue with Microsoft',
                    icon: Icons.business,
                    onPressed: _isLoading
                        ? null
                        : () => _signInWithOAuth(OAuthProvider.azure),
                  ),
                  const SizedBox(height: 8),
                  GpSecondaryButton(
                    label: 'Continue with Apple',
                    icon: Icons.apple,
                    onPressed: _isLoading
                        ? null
                        : () => _signInWithOAuth(OAuthProvider.apple),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
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
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _forgotPassword,
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  GpPrimaryButton(
                    label: _isLoading ? 'Signing In...' : 'Sign In',
                    icon: Icons.login,
                    onPressed: _isLoading ? null : _signInWithPassword,
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () => context.go('/auth/sign-up'),
                    child: const Text('Create account'),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'By continuing, you agree to Terms and Privacy Policy.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
