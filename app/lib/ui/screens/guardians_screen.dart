import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../../services/api_service.dart';

/// Unified Guardian Management Screen
/// Tabs:
/// 1. My Guardians (People who protect me)
/// 2. Protect Someone (People I protect)
class GuardiansScreen extends ConsumerStatefulWidget {
  const GuardiansScreen({super.key});

  @override
  ConsumerState<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends ConsumerState<GuardiansScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Guardian Network'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'My Guardians'),
            Tab(text: 'Protect Others'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _MyGuardiansTab(),
          _ProtectOthersTab(),
        ],
      ),
    );
  }
}

// ================== TAB 1: MY GUARDIANS ==================

class _MyGuardiansTab extends StatefulWidget {
  const _MyGuardiansTab();

  @override
  State<_MyGuardiansTab> createState() => _MyGuardiansTabState();
}

class _MyGuardiansTabState extends State<_MyGuardiansTab> {
  List<dynamic> _guardians = [];
  bool _isLoading = true;
  String? _error;
  
  // OTP state
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
        setState(() {
          _guardians = data;
          _isLoading = false;
        });
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
        setState(() {
          _currentOtp = result['otp_code'];
          _isGeneratingOtp = false;
        });
        _showOtpDialog();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isGeneratingOtp = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  void _showOtpDialog() {
    if (_currentOtp == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share This Code'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code with the person you want to be your guardian.'),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.blue.withOpacity(0.1),
              child: SelectableText(
                _currentOtp!,
                style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 4),
              ),
            ),
            const SizedBox(height: 10),
            const Text('Expires in 10 minutes', style: TextStyle(color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Done')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text('Error: $_error'));

    return RefreshIndicator(
      onRefresh: _loadGuardians,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Info Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Colors.blue),
                SizedBox(width: 12),
                Expanded(child: Text('Guardians get alerts when you receive scam messages.')),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          ElevatedButton.icon(
            onPressed: _isGeneratingOtp ? null : _generateOtp,
            icon: _isGeneratingOtp ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add),
            label: const Text('Add New Guardian'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          
          const SizedBox(height: 24),
          const Text('My Guardians', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          
          if (_guardians.isEmpty)
             const Center(
               child: Padding(
                 padding: EdgeInsets.all(32.0),
                 child: Text('No guardians linked yet.'),
               ),
             )
          else
            ..._guardians.map((g) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text((g['guardian_name']?[0] ?? 'G').toUpperCase())),
                title: Text(g['guardian_name'] ?? 'Unknown'),
                subtitle: Text(g['guardian_email'] ?? ''),
                trailing: const Icon(Icons.check_circle, color: Colors.green),
              ),
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
  List<dynamic> _myGuardians = [];
  bool _isLoading = true;
  
  final _emailController = TextEditingController();
  final _otpController = TextEditingController();
  bool _isLinking = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final protected = await apiService.getProtectedUsers();
      final guardians = await apiService.getMyGuardians();
      if (mounted) setState(() { 
        _protectedUsers = protected; 
        _myGuardians = guardians;
        _isLoading = false; 
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter email and OTP')));
      return;
    }

    setState(() => _isLinking = true);
    try {
      await apiService.verifyGuardianOtp(email, otp);
      if (mounted) {
        setState(() => _isLinking = false);
        _emailController.clear();
        _otpController.clear();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Successfully linked!')));
        _loadProtectedUsers(); // Refresh list
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLinking = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Show friendly message if user has guardians, otherwise show link form
        if (_myGuardians.isNotEmpty)
          Card(
            elevation: 0,
            color: Colors.blue.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: Colors.blue.shade100, width: 1.5),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.favorite, size: 48, color: Colors.blue.shade700),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'You\'re Protected!',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your guardians are keeping you safe. To protect others, you\'ll need to remove your current guardians first.',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.blue.shade800,
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue.shade600, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'This ensures your safety remains our top priority',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          // Link Form (when user doesn't have guardians)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Protect Someone', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Enter their email and the OTP code they generated.'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailController,
                    decoration: const InputDecoration(
                      labelText: 'User Email',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _otpController,
                    decoration: const InputDecoration(
                      labelText: 'OTP Code',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isLinking ? null : _linkUser,
                      child: _isLinking 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
                        : const Text('Link & Protect'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        
        // Only show "People I Protect" section if user doesn't have guardians
        if (_myGuardians.isEmpty) ...[
          const SizedBox(height: 24),
          const Text('People I Protect', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),

          if (_isLoading)
            const Center(child: CircularProgressIndicator())
          else if (_protectedUsers.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Text('You are not protecting anyone yet.'),
            ))
          else
            ..._protectedUsers.map((u) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: CircleAvatar(child: Text((u['user_name']?[0] ?? 'U').toUpperCase())),
                title: Text(u['user_name'] ?? 'Unknown User'),
                subtitle: Text(u['user_email'] ?? ''),
                trailing: const Icon(Icons.shield, color: AppColors.primary),
              ),
            )),
        ],
      ],
    );
  }
}

