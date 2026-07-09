import 'package:flutter/material.dart';
import 'package:rtstrack/dashboard_gride.dart';
import 'package:rtstrack/project_screen.dart';
import 'package:rtstrack/services/auth_services.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _roleCtrl = TextEditingController();
  final _authService = AuthService();
  bool _loading = false;
  bool _obscurePass = true;

  static const _bg = Color(0xFFF4F5FB);
  static const _fieldFill = Color(0xFFEDF1FA);
  static const _heading = Color(0xFF111827);
  static const _subtitle = Color(0xFF6B7280);
  static const _linkBlue = Color(0xFF2F6FED);

  Future<void> _register() async {
    if (_nameCtrl.text.trim().isEmpty ||
        _emailCtrl.text.trim().isEmpty ||
        _passCtrl.text.trim().isEmpty ||
        _roleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter all fields')));
      return;
    }

    setState(() => _loading = true);
    String? error = await _authService.registerUser(
      name: _nameCtrl.text,
      email: _emailCtrl.text,
      password: _passCtrl.text,
      role: _roleCtrl.text.trim(),
    );
    setState(() => _loading = false);

    if (error == null) {
      if (!mounted) return;
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Success'),
          content: const Text('Account created successfully!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // closes the dialog
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const DashboardGridScreen(),
                  ),
                );
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  InputDecoration _decoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      prefixIcon: Icon(icon, color: const Color(0xFF6B7280), size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: _fieldFill,
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _label(String text) => Align(
    alignment: Alignment.centerLeft,
    child: Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 13,
        color: _heading,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          onPressed: () => Navigator.pop(context),
                        ),
                        SizedBox(
                          // 👇 logo PNG me upar/niche transparent padding hai,
                          // OverflowBox se sirf visible content ka height le rahe hain
                          height: 100,
                          width: 200, // gap zyada ho to isko aur kam karo
                          child: OverflowBox(
                            maxHeight: 200, // image ki original render height
                            child: Image.asset('assets/logo.png', width: 200),
                          ),
                        ),
                      ],
                    ),
                    const Text(
                      'Create Account',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: _heading,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Start your journey toward high-performance focus today.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _subtitle, fontSize: 14),
                    ),
                    const SizedBox(height: 26),

                    _label('Full Name'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _nameCtrl,
                      decoration: _decoration(
                        hint: 'Enter your full name',
                        icon: Icons.person_outline,
                      ),
                    ),
                    const SizedBox(height: 18),

                    _label('Gmail / Email'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: _decoration(
                        hint: 'name@gmail.com',
                        icon: Icons.mail_outline,
                      ),
                    ),
                    const SizedBox(height: 18),

                    _label('Password'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _passCtrl,
                      obscureText: _obscurePass,
                      decoration: _decoration(
                        hint: '••••••••',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePass
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: const Color(0xFF6B7280),
                            size: 20,
                          ),
                          onPressed: () =>
                              setState(() => _obscurePass = !_obscurePass),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Role -> simple text input (toggle buttons ki jagah)
                    _label('Primary Role'),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _roleCtrl,
                      decoration: _decoration(
                        hint: 'e.g. Developer, Team Lead, Manager',
                        icon: Icons.badge_outlined,
                      ),
                    ),
                    const SizedBox(height: 26),

                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _loading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Register',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 22),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
