import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/offline_cache_service.dart';
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
      backgroundColor: AppColors.background(context),
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
                        color: AppColors.textPrimary(context),
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
                  color: AppColors.surface(context).withOpacity(0.5),
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
            color: isSelected ? Colors.white : AppColors.textSecondary(context),
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
      final data = await apiService.getGuardians();
      if (mounted) {
        setState(() { _guardians = data; _isLoading = false; });
        
        // Cache first guardian's phone for offline SMS alerts
        if (data.isNotEmpty) {
          final guardianPhone = data[0]['guardian_phone'] ?? data[0]['phone'];
          if (guardianPhone != null && guardianPhone.toString().isNotEmpty) {
            await offlineCacheService.saveSetting('guardian_phone', guardianPhone.toString());
            debugPrint('📱 Cached guardian phone for offline alerts: $guardianPhone');
          }
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _showAddGuardianDetailsDialog() async {
    final nameController = TextEditingController();
    final phoneController = TextEditingController();
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Tr('Add Guardian Details', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Tr('Enter their details so we can alert them via SMS immediately, even before they accept.',
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13),
            ),
            SizedBox(height: 16),
            _buildGlassInput(context, controller: nameController, icon: Icons.person_outline, hint: 'Name (Optional)'),
            SizedBox(height: 12),
            _buildGlassInput(context, controller: phoneController, icon: Icons.phone_android, hint: 'Phone Number (Required)', keyboardType: TextInputType.phone),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Tr('Cancel', style: TextStyle(color: AppColors.textSecondary(context))),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              final phone = phoneController.text.trim();
              if (phone.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Tr('Phone number is required')));
                return;
              }
              
              // Save to cache immediately
              await offlineCacheService.saveSetting('guardian_phone', phone);
              if (nameController.text.isNotEmpty) {
                 // We could cache name too if needed, but phone is critical
              }
              
              if (mounted) {
                Navigator.pop(ctx);
                _generateOtp(); // Proceed to generate OTP
              }
            },
            child: Tr('Generate Code'),
          ),
        ],
      ),
    );
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
        backgroundColor: AppColors.surface(context),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Tr('Share This Code', style: TextStyle(color: AppColors.textPrimary(context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Tr('Share this code with the person you want to be your guardian.',
              style: TextStyle(color: AppColors.textSecondary(context)),
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
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                       color: AppColors.textPrimary(context),
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
              style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12),
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
      backgroundColor: AppColors.background(context),
      onRefresh: _loadGuardians,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Card
          _buildGlassCard(
            context,
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
                    style: TextStyle(color: AppColors.textSecondary(context), fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 20),

          // Add Guardian Button
          _buildPrimaryButton(
            onPressed: _isGeneratingOtp ? null : _showAddGuardianDetailsDialog,
            icon: _isGeneratingOtp
                ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.add, color: Colors.white),
            label: tr('Add New Guardian'),
          ),
          SizedBox(height: 24),

          // Section Header
          Tr('My Guardians',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
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
                child: Tr('No guardians linked yet.', style: TextStyle(color: AppColors.textSecondary(context))),
              ),
            )
          else
            ..._guardians.map((g) => _buildPersonCard(
              context,
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
      final result = await apiService.verifyGuardianOtp(email, otp);
      
      // Cache protected user's phone for offline SMS alerts
      if (result != null && result is Map) {
        final userPhone = result['user_phone'] ?? result['phone'];
        if (userPhone != null && userPhone.toString().isNotEmpty) {
          await offlineCacheService.saveSetting('guardian_phone', userPhone.toString());
          debugPrint('📱 Cached protected user phone for offline alerts: $userPhone');
        }
      }
      
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
      backgroundColor: AppColors.background(context),
      onRefresh: _loadProtectedUsers,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Protect Someone Card
          _buildGlassCard(
            context,
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
                          Tr('Protect Someone', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                          Tr('Add a new user to your monitoring network', style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                        ],
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),

                // Email Input
                _buildInputLabel(context, 'User Email'),
                SizedBox(height: 6),
                _buildGlassInput(
                  context,
                  controller: _emailController,
                  icon: Icons.mail_outline,
                  hint: 'user@example.com',
                  keyboardType: TextInputType.emailAddress,
                ),
                SizedBox(height: 16),

                // OTP Input
                _buildInputLabel(context, 'OTP Code'),
                SizedBox(height: 6),
                _buildGlassInput(
                  context,
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
              Tr('People I Protect', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
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
                child: Tr('You are not protecting anyone yet.', style: TextStyle(color: AppColors.textSecondary(context))),
              ),
            )
          else
            ..._protectedUsers.map((u) => _buildPersonCard(
              context,
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

Widget _buildGlassCard(BuildContext context, {required Widget child}) {
  return Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface(context),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.border(context)),
      boxShadow: AppColors.cardShadow(context),
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

Widget _buildInputLabel(BuildContext context, String label) {
  return Text(
    label,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary(context)),
  );
}

Widget _buildGlassInput(BuildContext context, {
  required TextEditingController controller,
  required IconData icon,
  required String hint,
  TextInputType keyboardType = TextInputType.text,
}) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.isDark(context) ? Colors.black.withOpacity(0.4) : const Color(0xFFF4F4F5),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.border(context)),
    ),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14),
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

Widget _buildPersonCard(BuildContext context, {
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
      color: AppColors.surface(context).withOpacity(0.4),
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
            color: AppColors.surface(context),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.border(context), width: 2),
          ),
          child: Center(
            child: Text(
              initial,
              style: TextStyle(color: AppColors.textPrimary(context), fontSize: 16, fontWeight: FontWeight.w700),
            ),
          ),
        ),
        SizedBox(width: 12),
        // Info
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(color: AppColors.textPrimary(context), fontSize: 14, fontWeight: FontWeight.w600)),
              SizedBox(height: 2),
              Text(email, style: TextStyle(color: AppColors.textSecondary(context), fontSize: 12)),
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
