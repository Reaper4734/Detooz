import 'package:flutter/material.dart';
import 'admin_dashboard_screen.dart';
import '../../components/tr.dart';

class AdminLoginScreen extends StatefulWidget {
  const AdminLoginScreen({super.key});

  @override
  State<AdminLoginScreen> createState() => _AdminLoginScreenState();
}

class _AdminLoginScreenState extends State<AdminLoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  // Dark Theme Colors (Matching Dashboard)
  final Color bgDark = const Color(0xFF0F172A);
  final Color surfaceDark = const Color(0xFF1E293B);
  final Color accentColor = Colors.blueAccent;
  final Color textPrimary = Colors.white;
  final Color textSecondary = Colors.blueGrey[200]!;

  static const _validEmail = 'admin@detooz.com';
  static const _validPass = 'admin123';

  void _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));

    if (_emailController.text == _validEmail && _passwordController.text == _validPass) {
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminDashboardScreen()),
        );
      }
    } else {
      if (mounted) {
        setState(() {
          _error = 'Invalid admin credentials';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: surfaceDark,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.security, size: 48, color: accentColor),
              ),
              SizedBox(height: 32),
              
              Tr('Detooz Command Center',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: textPrimary,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 8),
              Tr('Restricted Access',
                textAlign: TextAlign.center,
                style: TextStyle(color: textSecondary),
              ),
              
              SizedBox(height: 48),
              
              // Email Field
              _buildDarkTextField(
                controller: _emailController,
                label: tr('Admin Email'),
                icon: Icons.admin_panel_settings_outlined,
              ),
              SizedBox(height: 20),
              
              // Password Field
              _buildDarkTextField(
                controller: _passwordController,
                label: tr('Password'),
                icon: Icons.lock_outline,
                isPassword: true,
                onSubmitted: (_) => _login(),
              ),
              
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: Colors.redAccent, size: 20),
                        SizedBox(width: 12),
                        Expanded(child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
                      ],
                    ),
                  ),
                ),
                
              SizedBox(height: 40),
              
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isLoading ? null : _login,
                  style: FilledButton.styleFrom(
                    backgroundColor: accentColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading
                      ? SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Tr('AUTHENTICATE', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.5)),
                ),
              ),
              SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Tr('Return to Application', style: TextStyle(color: textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDarkTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textSecondary, fontSize: 13, fontWeight: FontWeight.w500)),
        SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: isPassword,
          style: TextStyle(color: textPrimary),
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black.withOpacity(0.2),
            prefixIcon: Icon(icon, color: textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: accentColor),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        ),
      ],
    );
  }
}
