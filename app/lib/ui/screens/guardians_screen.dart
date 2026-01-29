import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../components/tr.dart';
import '../providers.dart';

/// Guardian Network Screen with premium dark glassmorphism UI
class GuardiansScreen extends ConsumerStatefulWidget {
  const GuardiansScreen({super.key});

  @override
  ConsumerState<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends ConsumerState<GuardiansScreen> {
  int _selectedTab = 0; // 0 = Protect Me, 1 = Protect Others

  @override
  Widget build(BuildContext context) {
    // Watch language provider to rebuild when translations are loaded
    ref.watch(languageProvider);
    
    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  SizedBox(width: 40), // Spacer for alignment
                  Expanded(
                    child: Tr('Guardian Network',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: 40), // Spacer for alignment
                ],
              ),
            ),

            // Tab Switcher
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Expanded(child: _buildTab('Protect Me', 0)),
                    Expanded(child: _buildTab('Protect Others', 1)),
                  ],
                ),
              ),
            ),

            // Tab Content
            Expanded(
              child: _selectedTab == 0
                  ? const _ProtectMeTab()
                  : const _ProtectOthersTab(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 10)]
              : null,
        ),
        child: Text(
          tr(label),
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            color: isSelected ? Colors.white : const Color(0xFFA1A1AA),
          ),
        ),
      ),
    );
  }
}

// ================== TAB 1: PROTECT ME (My Guardians) ==================

class _ProtectMeTab extends StatefulWidget {
  const _ProtectMeTab();

  @override
  State<_ProtectMeTab> createState() => _ProtectMeTabState();
}

class _ProtectMeTabState extends State<_ProtectMeTab> {
  List<dynamic> _guardians = [];
  bool _isLoading = true;
  String? _error;
  String? _currentOtp;
  bool _isGeneratingOtp = false;

  @override
  void initState() {
    super.initState();
    _loadGuardians();
  }

  Future<void> _loadGuardians() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await apiService.getMyGuardians();
      if (mounted) {
        setState(() { _guardians = data; _isLoading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _generateOtp() async {
    setState(() => _isGeneratingOtp = true);
    try {
      final result = await apiService.generateGuardianOtp();
      if (mounted) {
        setState(() { _currentOtp = result['otp_code']; _isGeneratingOtp = false; });
        _showOtpDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Tr('Error: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  void _showOtpDialog() {
    if (_currentOtp == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceDark,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Tr('Share This Code', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tr('Share this code with the person you want to be your guardian.',
              style: TextStyle(color: AppColors.textSecondaryDark),
            ),
            SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SelectableText(
                    _currentOtp!,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 8,
                    ),
                  ),
                  SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _currentOtp!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Tr('Copied to clipboard!')),
                      );
                    },
                    icon: const Icon(Icons.copy, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            SizedBox(height: 12),
            Tr('Expires in 10 minutes',
              style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Tr('Done', style: TextStyle(color: AppColors.primary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceDark,
      onRefresh: _loadGuardians,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Card
          _buildGlassCard(
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.shield_outlined, color: AppColors.primary, size: 22),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Tr('Guardians get alerts when you receive scam messages.',
                    style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Add Guardian Button
          _buildPrimaryButton(
            onPressed: _isGeneratingOtp ? null : _generateOtp,
            icon: _isGeneratingOtp
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add, color: Colors.white),
            label: tr('Add New Guardian'),
          ),
          SizedBox(height: 24),

          // Section Header
          Tr('My Guardians',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
          ),
          SizedBox(height: 12),

          // Guardian List
          if (_isLoading)
            Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_error != null)
            Center(child: Padding(padding: const EdgeInsets.all(32), child: Tr('Error: $_error', style: TextStyle(color: AppColors.danger))))
          else if (_guardians.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Tr('No guardians linked yet.', style: TextStyle(color: AppColors.textSecondaryDark)),
              ),
            )
          else
            ..._guardians.map((g) => _buildPersonCard(
              name: g['guardian_name'] ?? 'Unknown',
              email: g['guardian_email'] ?? '',
              isVerified: true,
              isGuardian: true,
            )),
        ],
      ),
    );
  }
}

// ================== TAB 2: PROTECT OTHERS ==================

class _ProtectOthersTab extends StatefulWidget {
  const _ProtectOthersTab();

  @override
  State<_ProtectOthersTab> createState() => _ProtectOthersTabState();
}

class _ProtectOthersTabState extends State<_ProtectOthersTab> {
  List<dynamic> _protectedUsers = [];
  bool _isLoading = true;
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLinking = false;

  @override
  void initState() {
    super.initState();
    _loadProtectedUsers();
  }

  Future<void> _loadProtectedUsers() async {
    setState(() => _isLoading = true);
    try {
      final data = await apiService.getProtectedUsers();
      if (mounted) setState(() { _protectedUsers = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _linkUser() async {
    final email = _emailController.text.trim();
    final otp = _otpController.text.trim();

    if (email.isEmpty || otp.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Tr('Please enter email and OTP'), backgroundColor: AppColors.warning),
      );
      return;
    }

    setState(() => _isLinking = true);
    try {
      await apiService.verifyGuardianOtp(email, otp);
      if (mounted) {
        setState(() => _isLinking = false);
        _emailController.clear();
        _otpController.clear();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Tr('Successfully linked!'), backgroundColor: AppColors.success),
        );
        _loadProtectedUsers();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLinking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Tr('Failed: $e'), backgroundColor: AppColors.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: AppColors.primary,
      backgroundColor: AppColors.surfaceDark,
      onRefresh: _loadProtectedUsers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Protect Someone Card
          _buildGlassCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_add_outlined, color: AppColors.primary, size: 22),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Tr('Protect Someone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                          Tr('Add a new user to your monitoring network', style: TextStyle(fontSize: 12, color: AppColors.textSecondaryDark)),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Email Input
                _buildInputLabel('User Email'),
                SizedBox(height: 6),
                _buildGlassInput(
                  controller: _emailController,
                  icon: Icons.mail_outline,
                  hint: 'user@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 16),

                // OTP Input
                _buildInputLabel('OTP Code'),
                SizedBox(height: 6),
                _buildGlassInput(
                  controller: _otpController,
                  icon: Icons.lock_outline,
                  hint: 'Enter 6-digit code',
                  keyboardType: TextInputType.number,
                ),
                SizedBox(height: 20),

                // Link Button
                _buildPrimaryButton(
                  onPressed: _isLinking ? null : _linkUser,
                  icon: _isLinking
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : null,
                  label: tr('Link & Protect'),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),

          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Tr('People I Protect', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              TextButton(
                onPressed: () {},
                child: Tr('View All', style: TextStyle(color: AppColors.primary, fontSize: 12)),
              ),
            ],
          ),
          SizedBox(height: 8),

          // Protected Users List
          if (_isLoading)
            Center(child: Padding(padding: EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_protectedUsers.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Tr('You are not protecting anyone yet.', style: TextStyle(color: AppColors.textSecondaryDark)),
              ),
            )
          else
            ..._protectedUsers.map((u) => _buildPersonCard(
              name: u['user_name'] ?? 'Unknown',
              email: u['user_email'] ?? '',
              isVerified: false,
              isGuardian: false,
            )),
        ],
      ),
    );
  }
}

// ================== SHARED WIDGETS ==================

Widget _buildGlassCard({required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.03),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.white.withOpacity(0.08)),
    ),
    child: child,
  );
}

Widget _buildPrimaryButton({
  required VoidCallback? onPressed,
  required String label,
  Widget? icon,
}) {
  return Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      boxShadow: [
        BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 20, offset: const Offset(0, 4)),
      ],
    ),
    child: ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[icon, SizedBox(width: 8)],
          Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
        ],
      ),
    ),
  );
}

Widget _buildInputLabel(String label) {
  return Text(
    label,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: const Color(0xFFD4D4D8)),
  );
}

Widget _buildGlassInput({
  required TextEditingController controller,
  required IconData icon,
  required String hint,
  TextInputType keyboardType = TextInputType.text,
}) {
  return Container(
    decoration: BoxDecoration(
      color: Colors.black.withOpacity(0.4),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.1)),
    ),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: const Color(0xFF52525B)),
        prefixIcon: Icon(icon, color: const Color(0xFF71717A), size: 20),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
  );
}

Widget _buildPersonCard({
  required String name,
  required String email,
  required bool isVerified,
  required bool isGuardian,
}) {
  final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
  
  return Container(
    margin: const EdgeInsets.only(bottom: 12),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.surfaceDark.withOpacity(0.4),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white.withOpacity(0.05)),
    ),
    child: Row(
      children: [
        // Avatar
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.surfaceDark,
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.borderDark, width: 2),
          ),
          child: Center(
            child: Text(
              initial,
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SizedBox(width: 12),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(height: 2),
              Text(email, style: TextStyle(color: AppColors.textSecondaryDark, fontSize: 12)),
            ],
          ),
        ),
        // Status Icon
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isGuardian ? Icons.verified : Icons.security,
            color: isGuardian ? AppColors.success : AppColors.primary,
            size: 18,
          ),
        ),
      ],
    ),
  );
}
