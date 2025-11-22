// lib/features/auth/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../main.dart';
import '../../core/utils/firebase_error_parser.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _userCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  bool _obscure = true;

  @override
  void dispose() {
    _userCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Card color: dark tone even in light mode
    final loginCardColor = isDark
        ? Theme.of(context).cardTheme.color
        : const Color(0xFF2D232C);

    final loginButtonFgColor = isDark ? Colors.black : const Color(0xFF2D232C);
    final loginButtonBgColor = isDark ? Theme.of(context).colorScheme.primary : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                const SizedBox(height: 24),

                // Logo Badge
                Align(
                  alignment: Alignment.topLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: loginCardColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.calendar_month, color: Colors.white),
                          SizedBox(width: 8),
                          Text(
                            "CAMPUS\nTRACK",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 60),

                const Text(
                  "Login",
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 30),

                // Login Card
                Container(
                  padding: const EdgeInsets.all(24),
                  width: 350,
                  decoration: BoxDecoration(
                    color: loginCardColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Form(
                    key: _formKey,
                    child: AutofillGroup(
                      child: Column(
                        children: [
                          // Email TextFormField
                          TextFormField(
                            controller: _userCtrl,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.username, AutofillHints.email],
                            textInputAction: TextInputAction.next,
                            style: const TextStyle(color: Colors.black87),
                            decoration: const InputDecoration(
                              hintText: "Email",
                              fillColor: Colors.white,
                              filled: true,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return 'Required';
                              if (!v.contains('@')) return 'Enter a valid email';
                              return null;
                            },
                          ),
                          const SizedBox(height: 18),

                          // Password TextFormField
                          TextFormField(
                            controller: _pwdCtrl,
                            obscureText: _obscure,
                            enableSuggestions: false,
                            autocorrect: false,
                            textInputAction: TextInputAction.done,
                            style: const TextStyle(color: Colors.black87),
                            onFieldSubmitted: (_) => _onLogin(),
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              hintText: "Password",
                              fillColor: Colors.white,
                              filled: true,
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'Show' : 'Hide',
                                icon: Icon(
                                  _obscure ? Icons.visibility_off : Icons.visibility,
                                  color: Colors.grey[700],
                                ),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().length < 6) ? 'Min 6 chars' : null,
                          ),

                          const SizedBox(height: 16),

                          // Forgot password button
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotDialog,
                              child: const Text('Forgot password?', style: TextStyle(color: Colors.white70)),
                            ),
                          ),

                          const SizedBox(height: 4),

                          // Login Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _onLogin,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: loginButtonBgColor,
                                foregroundColor: loginButtonFgColor,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              child: _loading
                                  ? SizedBox(
                                height: 24,
                                width: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(loginButtonFgColor),
                                ),
                              )
                                  : const Text(
                                "Login",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _onLogin() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();

    setState(() => _loading = true);

    final auth = ref.read(authRepoProvider);
    final email = _userCtrl.text.trim();
    final password = _pwdCtrl.text.trim();

    try {
      await auth.loginWithEmail(email, password);
      // On success GoRouter will handle redirect based on auth state
    } catch (e) {
      if (!mounted) return;

      final msg = FirebaseErrorParser.getMessage(e);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));

      setState(() => _loading = false);
    }
  }

  Future<void> _showForgotDialog() async {
    final emailCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Forgot Password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Enter your email address to receive a password reset link.'),
              const SizedBox(height: 16),
              TextField(
                controller: emailCtrl,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', filled: false),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Please enter a valid email.')),
                  );
                  return;
                }

                try {
                  await ref.read(authRepoProvider).requestPasswordReset(email);
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reset link sent! Check your email.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(FirebaseErrorParser.getMessage(e)),
                      backgroundColor: Colors.red,
                    ));
                  }
                }
              },
              child: const Text('Send Link'),
            ),
          ],
        );
      },
    );

    emailCtrl.dispose();
  }
}
