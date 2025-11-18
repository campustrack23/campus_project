// lib/features/auth/login_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/models/role.dart';
import '../../main.dart';
import '../../theme.dart';
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
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final loginCardColor = isDark ? darkTheme().cardTheme.color : const Color(0xFF2D232C);
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
                          TextFormField(
                              controller: _userCtrl,
                              keyboardType: TextInputType.emailAddress,
                              autofillHints: const [AutofillHints.username, AutofillHints.email],
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(hintText: "Email"),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Required';
                                if (!v.contains('@')) return 'Enter a valid email';
                                return null;
                              }
                          ),
                          const SizedBox(height: 18),
                          TextFormField(
                            controller: _pwdCtrl,
                            obscureText: _obscure,
                            enableSuggestions: false,
                            autocorrect: false,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _onLogin(),
                            autofillHints: const [AutofillHints.password],
                            decoration: InputDecoration(
                              hintText: "Password",
                              suffixIcon: IconButton(
                                tooltip: _obscure ? 'Show' : 'Hide',
                                icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                                onPressed: () => setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (v) => (v == null || v.trim().length < 6) ? 'Min 6 chars' : null,
                          ),
                          const SizedBox(height: 16),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotDialog,
                              child: Text('Forgot password?', style: TextStyle(color: isDark ? Colors.white70 : Colors.white)),
                            ),
                          ),
                          const SizedBox(height: 4),
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
    final pwd = _pwdCtrl.text.trim();
    try {
      // --- FIX: The _onLogin method is now ONLY responsible for logging in. ---
      final user = await auth.loginWithEmail(email, pwd);
      if (user == null) throw Exception('Invalid credentials or inactive user.');

      // Navigation is now handled by the GoRouter redirect.
      // All notification logic has been moved to notification_sync_service.dart
      // to make the login feel instantaneous.
      // --- End of Fix ---

    } catch (e) {
      if (!mounted) return;
      final message = FirebaseErrorParser.getMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Login Failed: $message'),
        backgroundColor: Colors.red,
      ));
    } finally {
      if (mounted) setState(() => _loading = false);
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
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            FilledButton(
              onPressed: () async {
                final email = emailCtrl.text.trim();
                if (email.isEmpty || !email.contains('@')) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter a valid email.')));
                  return;
                }
                try {
                  await ref.read(authRepoProvider).requestPasswordReset(email);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Password reset link sent to your email.')));
                } catch (e) {
                  if (!mounted) return;
                  final message = FirebaseErrorParser.getMessage(e);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('Error: $message'),
                    backgroundColor: Colors.red,
                  ));
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