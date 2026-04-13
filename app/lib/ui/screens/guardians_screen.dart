import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../../services/api_service.dart';
import '../../services/offline_cache_service.dart';
import '../components/tr.dart';
import '../providers.dart';

// ════════════════════════════════════════════════════════════════
// GUARDIAN NETWORK — Neo-Brutalist Design
// ════════════════════════════════════════════════════════════════

class GuardiansScreen extends ConsumerStatefulWidget {
  const GuardiansScreen({super.key});

  @override
  ConsumerState<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends ConsumerState<GuardiansScreen> {
  int _activeTab = 0; // 0 = Protect Me, 1 = Protect Others

  @override
  Widget build(BuildContext context) {
    // Watch language provider to rebuild when translations are loaded
    ref.watch(languageProvider);

    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: SafeArea(
        child: Column(
          children: [
            // ─── Header ───
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'GUARDIAN NETWORK',
                  style: TextStyle(
                    fontFamily: 'IntegralCF',
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary(context),
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Segmented Tab Control ───
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface(context),
                  border: Border.all(color: AppColors.divider(context), width: 2),
                ),
                child: Row(
                  children: [
                    _buildTab('PROTECT ME', 0),
                    Container(width: 2, height: 44, color: AppColors.divider(context)),
                    _buildTab('PROTECT OTHERS', 1),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // ─── Tab Content ───
            Expanded(
              child: _activeTab == 0
                  ? _ProtectMeTab(onNotify: _showTopNotification)
                  : _ProtectOthersTab(onNotify: _showTopNotification),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String label, int index) {
    final isActive = _activeTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = index),
        child: Container(
          height: 44,
          color: isActive ? AppColors.primary : Colors.transparent,
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontFamily: 'IntegralCF',
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
                color: isActive
                    ? const Color(0xFF121417)
                    : AppColors.textSecondary(context),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Top-Down Overlay Notification ───
  void _showTopNotification(String message, bool isSuccess) {
    if (!mounted) return;
    final OverlayState? overlayState;
    try {
      overlayState = Overlay.of(context);
    } catch (_) {
      return; // Overlay not available yet
    }
    late OverlayEntry entry;

    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: -150.0, end: 0.0),
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutBack,
          builder: (context, val, child) {
            return Transform.translate(
              offset: Offset(0, val),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSuccess ? AppColors.success : AppColors.danger,
                    border: Border.all(color: AppColors.textPrimary(context), width: 2),
                    boxShadow: [
                      BoxShadow(offset: const Offset(4, 4), color: AppColors.textPrimary(context)),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isSuccess ? Icons.check_circle_outline : Icons.error_outline,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          message.toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'IntegralCF',
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );

    overlayState.insert(entry);
    Future.delayed(const Duration(seconds: 3), () {
      if (entry.mounted) entry.remove();
    });
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 1: PROTECT ME
// ════════════════════════════════════════════════════════════════

class _ProtectMeTab extends StatefulWidget {
  final void Function(String message, bool isSuccess) onNotify;
  const _ProtectMeTab({required this.onNotify});

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
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            border: Border.all(color: AppColors.textPrimary(context), width: 2),
            boxShadow: [BoxShadow(offset: const Offset(6, 6), color: AppColors.textPrimary(context))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ADD GUARDIAN DETAILS',
                style: TextStyle(
                  fontFamily: 'IntegralCF',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr('Enter their details so we can alert them via SMS immediately, even before they accept.'),
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 20),
              _buildNeoInput(controller: nameController, hint: 'Name (Optional)', icon: Icons.person_outline),
              const SizedBox(height: 12),
              _buildNeoInput(controller: phoneController, hint: 'Phone (Required)', icon: Icons.phone_android, keyboardType: TextInputType.phone),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 48,
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.textSecondary(context), width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          'CANCEL',
                          style: TextStyle(fontFamily: 'IntegralCF', fontSize: 13, color: AppColors.textSecondary(context)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 2,
                    child: _NeoButton(
                      onTap: () async {
                        final phone = phoneController.text.trim();
                        if (phone.isEmpty) {
                          widget.onNotify('Phone number is required', false);
                          return;
                        }
                        // Save to cache immediately
                        await offlineCacheService.saveSetting('guardian_phone', phone);
                        if (mounted) {
                          Navigator.pop(ctx);
                          _generateOtp();
                        }
                      },
                      child: const Text(
                        'GENERATE CODE',
                        style: TextStyle(fontFamily: 'IntegralCF', fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF121417)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
        widget.onNotify('Error: $e', false);
      }
    }
  }

  void _showOtpDialog() {
    if (_currentOtp == null) return;
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.surface(context),
            border: Border.all(color: AppColors.textPrimary(context), width: 2),
            boxShadow: [BoxShadow(offset: const Offset(6, 6), color: AppColors.textPrimary(context))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'SHARE THIS CODE',
                style: TextStyle(
                  fontFamily: 'IntegralCF',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tr('Share this code with the person you want to be your guardian.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary(context), fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                  color: AppColors.isDark(context) ? const Color(0xFF1A1F24) : const Color(0xFFF1F4F8),
                  border: Border.all(color: AppColors.textPrimary(context), width: 1.5),
                ),
                child: Center(
                  child: SelectableText(
                    _currentOtp!,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary(context),
                      letterSpacing: 10,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'EXPIRES IN 10 MINUTES',
                style: TextStyle(
                  fontFamily: 'IntegralCF',
                  color: AppColors.danger,
                  fontSize: 10,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 24),
              _NeoButton(
                onTap: () {
                  Clipboard.setData(ClipboardData(text: _currentOtp!));
                  Navigator.pop(ctx);
                  widget.onNotify('Copied to clipboard!', true);
                },
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.copy, color: Color(0xFF121417), size: 18),
                    SizedBox(width: 8),
                    Text(
                      'COPY',
                      style: TextStyle(fontFamily: 'IntegralCF', fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF121417)),
                    ),
                    SizedBox(width: 4),
                    Text('&', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF121417))),
                    SizedBox(width: 4),
                    Text(
                      'CLOSE',
                      style: TextStyle(fontFamily: 'IntegralCF', fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF121417)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        children: [
          // ─── System Notice ───
          _NeoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 10, height: 10, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      'SYSTEM NOTICE',
                      style: TextStyle(
                        fontFamily: 'IntegralCF',
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                        letterSpacing: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Tr(
                  'Guardians get alerts when you receive scam messages. They cannot read your personal chats.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary(context),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ─── Add Guardian Button ───
          _NeoButton(
            onTap: _isGeneratingOtp ? () {} : _showAddGuardianDetailsDialog,
            child: _isGeneratingOtp
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Color(0xFF121417), strokeWidth: 3))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.add, color: Color(0xFF121417), size: 20),
                      SizedBox(width: 8),
                      Text(
                        'ADD NEW GUARDIAN',
                        style: TextStyle(
                          fontFamily: 'IntegralCF',
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF121417),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 32),

          // ─── Section Header ───
          Text(
            'MY GUARDIANS',
            style: TextStyle(
              fontFamily: 'IntegralCF',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary(context),
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 16),

          // ─── Guardian List ───
          if (_isLoading)
            Center(child: Padding(padding: const EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_error != null)
            Center(child: Padding(padding: const EdgeInsets.all(32), child: Tr('Error: $_error', style: TextStyle(color: AppColors.danger))))
          else if (_guardians.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider(context), width: 1.5),
                color: Colors.transparent,
              ),
              child: Center(
                child: Tr(
                  'No guardians linked yet.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            ..._guardians.map((g) => _buildGuardianItem(
              g['guardian_name'] ?? 'Unknown',
              g['guardian_email'] ?? '',
            )),
        ],
      ),
    );
  }

  Widget _buildGuardianItem(String name, String email) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider(context), width: 1.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontFamily: 'IntegralCF',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context)),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary(context)),
                ),
              ],
            ),
          ),
          Icon(Icons.more_horiz, color: AppColors.textSecondary(context), size: 24),
        ],
      ),
    );
  }

  Widget _buildNeoInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.isDark(context) ? Colors.black26 : Colors.white,
        border: Border.all(color: AppColors.divider(context), width: 1.5),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(icon, size: 20, color: AppColors.textSecondary(context)),
          ),
          Container(width: 1.5, height: 48, color: AppColors.divider(context)),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context), fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppColors.textSecondary(context), fontWeight: FontWeight.w400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// TAB 2: PROTECT OTHERS
// ════════════════════════════════════════════════════════════════

class _ProtectOthersTab extends StatefulWidget {
  final void Function(String message, bool isSuccess) onNotify;
  const _ProtectOthersTab({required this.onNotify});

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

  @override
  void dispose() {
    _emailController.dispose();
    _otpController.dispose();
    super.dispose();
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
      widget.onNotify('Please fill all fields', false);
      return;
    }

    setState(() => _isLinking = true);
    try {
      final result = await apiService.verifyGuardianOtp(email, otp);

      // Cache protected user's phone for offline SMS alerts
      final userPhone = result['user_phone'] ?? result['phone'];
      if (userPhone != null && userPhone.toString().isNotEmpty) {
        await offlineCacheService.saveSetting('guardian_phone', userPhone.toString());
      }

      if (mounted) {
        setState(() => _isLinking = false);
        _emailController.clear();
        _otpController.clear();
        widget.onNotify('Successfully linked!', true);
        _loadProtectedUsers();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLinking = false);
        widget.onNotify('Failed: $e', false);
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
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        children: [
          // ─── Protect Someone Form Card ───
          _NeoCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(width: 10, height: 10, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Text(
                      'PROTECT SOMEONE',
                      style: TextStyle(
                        fontFamily: 'IntegralCF',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Tr(
                  'Add a new user to your monitoring network',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context)),
                ),
                const SizedBox(height: 24),

                // Email Field
                Text(
                  'User Email',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _buildNeoInput(controller: _emailController, hint: 'user@example.com', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                const SizedBox(height: 16),

                // OTP Field
                Text(
                  'OTP Code',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(context),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                _buildNeoInput(controller: _otpController, hint: 'Enter 6-digit code', icon: Icons.lock_outline, keyboardType: TextInputType.number),
                const SizedBox(height: 24),

                // Link Button
                _NeoButton(
                  onTap: _isLinking ? () {} : _linkUser,
                  child: _isLinking
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Color(0xFF121417), strokeWidth: 3))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: const [
                            Text(
                              'LINK',
                              style: TextStyle(fontFamily: 'IntegralCF', fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF121417)),
                            ),
                            SizedBox(width: 4),
                            Text('&', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w900, color: Color(0xFF121417))),
                            SizedBox(width: 4),
                            Text(
                              'PROTECT',
                              style: TextStyle(fontFamily: 'IntegralCF', fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF121417)),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // ─── Section Header ───
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'PEOPLE I PROTECT',
                style: TextStyle(
                  fontFamily: 'IntegralCF',
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary(context),
                  letterSpacing: 1,
                ),
              ),
              Text(
                'VIEW ALL',
                style: TextStyle(
                  fontFamily: 'IntegralCF',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // ─── Protected Users List ───
          if (_isLoading)
            Center(child: Padding(padding: const EdgeInsets.all(32), child: CircularProgressIndicator(color: AppColors.primary)))
          else if (_protectedUsers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.divider(context), width: 1.5),
                color: Colors.transparent,
              ),
              child: Center(
                child: Tr(
                  'You are not protecting anyone yet.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          else
            ..._protectedUsers.map((u) => _buildGuardianItem(
              u['user_name'] ?? 'Unknown',
              u['user_email'] ?? '',
            )),
        ],
      ),
    );
  }

  Widget _buildGuardianItem(String name, String email) {
    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider(context), width: 1.5)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.surface(context),
              border: Border.all(color: AppColors.primary, width: 2),
            ),
            child: Center(
              child: Text(
                initial,
                style: const TextStyle(
                  fontFamily: 'IntegralCF',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary(context))),
                const SizedBox(height: 4),
                Text(email, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary(context))),
              ],
            ),
          ),
          Icon(Icons.more_horiz, color: AppColors.textSecondary(context), size: 24),
        ],
      ),
    );
  }

  Widget _buildNeoInput({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.isDark(context) ? Colors.black26 : Colors.white,
        border: Border.all(color: AppColors.divider(context), width: 1.5),
      ),
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Icon(icon, size: 20, color: AppColors.textSecondary(context)),
          ),
          Container(width: 1.5, height: 48, color: AppColors.divider(context)),
          Expanded(
            child: TextField(
              controller: controller,
              keyboardType: keyboardType,
              style: TextStyle(fontSize: 14, color: AppColors.textPrimary(context), fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: hint,
                hintStyle: TextStyle(color: AppColors.textSecondary(context), fontWeight: FontWeight.w400),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════
// SHARED WIDGETS
// ════════════════════════════════════════════════════════════════

/// Neo-Brutalist Card — flat border, sharp corners
class _NeoCard extends StatelessWidget {
  final Widget child;
  const _NeoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border.all(color: AppColors.divider(context), width: 1.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: child,
    );
  }
}

/// Neo-Brutalist Tactile Button — press-down shadow eating animation
class _NeoButton extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  final Color? baseColor;

  const _NeoButton({
    required this.onTap,
    required this.child,
    this.baseColor,
  });

  @override
  State<_NeoButton> createState() => _NeoButtonState();
}

class _NeoButtonState extends State<_NeoButton> {
  bool _isPressed = false;

  void _handleTapDown(TapDownDetails details) => setState(() => _isPressed = true);
  void _handleTapUp(TapUpDetails details) {
    setState(() => _isPressed = false);
    widget.onTap();
  }
  void _handleTapCancel() => setState(() => _isPressed = false);

  @override
  Widget build(BuildContext context) {
    final effectiveColor = widget.baseColor ?? AppColors.primary;
    final HSVColor hsvColor = HSVColor.fromColor(effectiveColor);
    final Color pressedColor = hsvColor.withValue(max(0.0, hsvColor.value - 0.25)).toColor();

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      child: Transform.translate(
        offset: _isPressed ? const Offset(2, 2) : Offset.zero,
        child: Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: _isPressed ? pressedColor : effectiveColor,
            border: Border.all(
              color: AppColors.isDark(context) ? AppColors.primary : AppColors.textPrimary(context),
              width: 1.5,
            ),
            boxShadow: _isPressed
                ? []
                : [BoxShadow(
                    offset: const Offset(4, 4),
                    color: AppColors.isDark(context) ? AppColors.primary.withOpacity(0.5) : AppColors.textPrimary(context),
                  )],
          ),
          child: Center(child: widget.child),
        ),
      ),
    );
  }
}
