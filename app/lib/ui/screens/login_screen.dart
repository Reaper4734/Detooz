import 'package:flutter/material.dart';
import 'package:country_code_picker/country_code_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
// import 'guardian_login_screen.dart'; // Removed
import 'guardians_screen.dart';
import 'admin/admin_login_screen.dart';


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLogin = true;
  bool _isLoading = false;
  
  // Controllers
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  // Name Controllers
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  
  final _phoneController = TextEditingController();

  String _countryCode = "+91";

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  // Validators
  String? _validateEmail(String? value) {
    if (value == null || value.isEmpty) return 'Email is required';
    final regex = RegExp(r"^[a-zA-Z0-9.a-zA-Z0-9.!#$%&'*+-/=?^_`{|}~]+@[a-zA-Z0-9]+\.[a-zA-Z]+");
    if (!regex.hasMatch(value)) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Password is required';
    if (_isLogin) return null; // Relax validation for login, strict for registration

    if (value.length < 8) return 'Min 8 characters';
    if (!value.contains(RegExp(r'[A-Z]'))) return 'Must contain 1 uppercase letter';
    if (!value.contains(RegExp(r'[0-9]'))) return 'Must contain 1 number';
    if (!value.contains(RegExp(r'[@#*&!$%^]'))) return 'Must contain 1 special char';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _isLoading = true);
    
    try {
      bool success;
      if (_isLogin) {
        success = await ref.read(authProvider.notifier).login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
      } else {
        success = await ref.read(authProvider.notifier).register(
          _emailController.text.trim(),
          _passwordController.text.trim(),
          _firstNameController.text.trim(),
          _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
          _lastNameController.text.trim(),
          _phoneController.text.trim(),
          countryCode: _countryCode,
        );
      }
      
      setState(() => _isLoading = false);
      
      // If success
      if (success) {
        if (!_isLogin && mounted) {
          _showAddGuardianPrompt();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(label: 'OK', onPressed: () {}, textColor: Colors.white),
          ),
        );
      }
    }
  }

  Future<void> _showAddGuardianPrompt() async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Registration Successful'),
        content: const Text(
          'Enhance your safety by adding a trusted Guardian.\n'
          'Share an OTP with them to link accounts instantly.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const GuardiansScreen()),
              );
            },
            child: const Text('Add Guardian'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Logo or Title
                const Icon(Icons.security, size: 64, color: AppColors.primary),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Detooz',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
                
                // Fields
                if (!_isLogin) ...[
                  // Name fields
                  TextFormField(
                    controller: _firstNameController,
                    decoration: const InputDecoration(
                      labelText: 'First Name *',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  TextFormField(
                    controller: _middleNameController,
                    decoration: const InputDecoration(
                      labelText: 'Middle Name (Optional)',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  TextFormField(
                    controller: _lastNameController,
                    decoration: const InputDecoration(
                      labelText: 'Last Name *',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty == true ? 'Required' : null,
                  ),
                  const SizedBox(height: AppSpacing.md),
                  
                  // Phone with Country Code
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        margin: const EdgeInsets.only(right: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: CountryCodePicker(
                          onChanged: (country) => setState(() => _countryCode = country.dialCode!),
                          initialSelection: 'IN',
                          favorite: const ['+91', 'US'],
                          showCountryOnly: false,
                          showOnlyCountryWhenClosed: false,
                          alignLeft: false,
                          padding: EdgeInsets.zero,
                        ),
                      ),
                      Expanded(
                        child: TextFormField(
                          controller: _phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone),
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          validator: (v) => v?.isEmpty == true ? 'Required' : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
                
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email),
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateEmail,
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: AppSpacing.md),
                
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    helperText: _isLogin ? null : 'Min 8 chars, 1 Upper, 1 Special, 1 Number',
                    helperMaxLines: 2,
                  ),
                  obscureText: true,
                  validator: _validatePassword,
                ),
                const SizedBox(height: AppSpacing.xl),
                
                // Submit Button
                ElevatedButton(
                  onPressed: _isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: _isLoading 
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(_isLogin ? 'LOGIN' : 'REGISTER'),
                ),
                
                const SizedBox(height: AppSpacing.md),
                
                // Switch Mode
                TextButton(
                  onPressed: () => setState(() => _isLogin = !_isLogin),
                  child: Text(_isLogin ? 'Create an account' : 'Already have an account? Login'),
                ),
                
                const SizedBox(height: 24),
                
// Guardian login section removed (unified user model)
                
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const AdminLoginScreen()),
                    );
                  },
                  child: Text(
                    'Admin Login',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
