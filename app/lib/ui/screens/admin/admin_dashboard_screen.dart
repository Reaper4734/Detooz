import 'package:flutter/material.dart';
import '../../../services/api_service.dart';
import '../../theme/app_colors.dart';
import 'admin_login_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _selectedIndex = 0; 
  bool _isLoading = true;
  
  Map<String, dynamic>? _stats;
  List<dynamic> _users = [];
  List<dynamic> _guardians = [];
  List<dynamic> _alerts = [];

  // Dark Theme Colors
  final Color bgDark = const Color(0xFF0F172A);      // Main Background
  final Color surfaceDark = const Color(0xFF1E293B); // Card/Sidebar Background
  final Color textPrimary = Colors.white;
  final Color textSecondary = Colors.blueGrey[200]!;
  final Color accentColor = Colors.blueAccent;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => _isLoading = true);
    try {
      final results = await Future.wait([
        apiService.getAdminStats(),
        apiService.getAdminUsers(),
        apiService.getAdminGuardians(),
        apiService.getAdminAlerts(),
      ]);
      
      if (mounted) {
        setState(() {
          _stats = results[0] as Map<String, dynamic>;
          _users = results[1] as List<dynamic>;
          _guardians = results[2] as List<dynamic>;
          _alerts = results[3] as List<dynamic>;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _deleteUser(int id, String name) async {
    final confirmed = await _showConfirmDialog('Delete User', 'Delete user "$name"?');
    if (confirmed) {
      try {
        await apiService.deleteUser(id);
        _loadAllData();
        if (mounted) _showSnack('User deleted');
      } catch (e) {
        if (mounted) _showSnack('Failed: $e', isError: true);
      }
    }
  }
  
  Future<void> _deleteGuardian(int id) async {
    final confirmed = await _showConfirmDialog('Delete Guardian', 'Remove this guardian account?');
    if (confirmed) {
      try {
        await apiService.deleteGuardian(id);
        _loadAllData();
        if (mounted) _showSnack('Guardian deleted');
      } catch (e) {
        if (mounted) _showSnack('Failed: $e', isError: true);
      }
    }
  }
  
  Future<void> _deleteAlert(int id) async {
    final confirmed = await _showConfirmDialog('Delete Alert', 'Remove this alert record?');
    if (confirmed) {
      try {
        await apiService.deleteAlert(id);
        _loadAllData();
        if (mounted) _showSnack('Alert deleted');
      } catch (e) {
        if (mounted) _showSnack('Failed: $e', isError: true);
      }
    }
  }

  Future<void> _editUser(dynamic user) async {
    final nameCtrl = TextEditingController(text: user['name']);
    final phoneCtrl = TextEditingController(text: user['phone'] ?? '');
    
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceDark,
        title: Text('Edit User', style: TextStyle(color: textPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDarkTextField('Full Name', nameCtrl),
            const SizedBox(height: 16),
            _buildDarkTextField('Phone', phoneCtrl),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              try {
                await apiService.updateUser(user['id'], nameCtrl.text, phoneCtrl.text);
                Navigator.pop(ctx, true);
              } catch (e) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('Error: $e')));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    
    if (saved == true) {
      _loadAllData();
      _showSnack('User updated successfully');
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: surfaceDark,
        title: Text(title, style: TextStyle(color: textPrimary)),
        content: Text(content, style: TextStyle(color: textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true), 
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? Colors.red : Colors.green,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgDark,
      body: Row(
        children: [
          // SIDEBAR
          _buildSidebar(),
          
          // MAIN CONTENT
          Expanded(
            child: Column(
              children: [
                _buildHeader(),
                Expanded(
                  child: _isLoading 
                      ? Center(child: CircularProgressIndicator(color: accentColor)) 
                      : _buildContent(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar() {
    return Container(
      width: 260,
      color: surfaceDark,
      child: Column(
        children: [
          // Logo Area
          Container(
            height: 90,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Row(
              children: [
                 Container(
                   padding: const EdgeInsets.all(8),
                   decoration: BoxDecoration(color: accentColor.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                   child: Icon(Icons.shield, color: accentColor, size: 28),
                 ),
                 const SizedBox(width: 16),
                 Text('DETOOZ', style: TextStyle(color: textPrimary, fontSize: 22, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
              ],
            ),
          ),
          Divider(color: Colors.white.withOpacity(0.05)),
          
          const SizedBox(height: 24),
          
          _buildNavItem(0, 'Dashboard', Icons.dashboard_rounded),
          _buildNavItem(1, 'Users', Icons.people_rounded),
          _buildNavItem(2, 'Guardians', Icons.security_rounded),
          _buildNavItem(3, 'Alerts', Icons.warning_rounded),
          
          const Spacer(),
          Divider(color: Colors.white.withOpacity(0.05)),
          _buildNavItem(-1, 'Back to Login', Icons.logout_rounded, isLogout: true),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, String title, IconData icon, {bool isLogout = false}) {
    final isSelected = _selectedIndex == index;
    final color = isLogout ? Colors.redAccent : (isSelected ? accentColor : textSecondary);
    final bg = isSelected ? accentColor.withOpacity(0.1) : Colors.transparent;
    
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (isLogout) {
             Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AdminLoginScreen()));
          } else {
            setState(() => _selectedIndex = index);
          }
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 16),
              Text(
                title,
                style: TextStyle(
                  color: isLogout ? Colors.redAccent : (isSelected ? Colors.white : textSecondary),
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      height: 90,
      padding: const EdgeInsets.symmetric(horizontal: 32),
      decoration: BoxDecoration(
        color: surfaceDark,
        border: Border(bottom: BorderSide(color: Colors.black.withOpacity(0.2))),
      ),
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _selectedIndex == 0 ? 'Overview' :
                _selectedIndex == 1 ? 'User Management' :
                _selectedIndex == 2 ? 'Guardian Network' : 'Security Alerts',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: textPrimary),
              ),
              Text('Welcome back, Admin', style: TextStyle(fontSize: 14, color: textSecondary)),
            ],
          ),
          const Spacer(),
          IconButton(onPressed: _loadAllData, icon: const Icon(Icons.refresh, color: Colors.white70), tooltip: 'Refresh'),
          const SizedBox(width: 24),
          CircleAvatar(
            backgroundColor: accentColor,
            child: const Text('A', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedIndex) {
      case 0: return _buildOverviewStats();
      case 1: return _buildUsersList();
      case 2: return _buildGuardiansList();
      case 3: return _buildAlertsList();
      default: return const SizedBox();
    }
  }

  // ============ 1. OVERVIEW DASHBOARD ============
  Widget _buildOverviewStats() {
    if (_stats == null) return const SizedBox();
    
    return SingleChildScrollView(
       padding: const EdgeInsets.all(32),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Row(
             children: [
               _buildStatCard('Total Users', _stats!['total_users'].toString(), Icons.people, const Color(0xFF6366F1)),
               _buildStatCard('Guardians', _stats!['total_guardians'].toString(), Icons.shield_moon, const Color(0xFF10B981)),
               _buildStatCard('Active Alerts', _stats!['total_alerts'].toString(), Icons.notifications_active, const Color(0xFFF59E0B)),
               _buildStatCard('Scams Blocked', _stats!['total_scams_detected'].toString(), Icons.gpp_bad, const Color(0xFFEF4444)),
             ],
           ),
           const SizedBox(height: 48),
           Text('Recent Activity', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textPrimary)),
           const SizedBox(height: 24),
           _buildAlertsRefinedList(limit: 5),
         ],
       ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 8),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: surfaceDark,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: [
             BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary)),
                Text(title, style: TextStyle(fontSize: 13, color: textSecondary, fontWeight: FontWeight.w500)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============ 2. USERS LIST ============
  Widget _buildUsersList() {
    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final u = _users[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              CircleAvatar(backgroundColor: Colors.white10, child: Text(u['name']?[0] ?? 'U', style: const TextStyle(color: Colors.white))),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u['name'] ?? 'Unknown', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: textPrimary)),
                    Text('#${u['id']}', style: TextStyle(color: textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(u['email'] ?? '', style: TextStyle(color: textSecondary)),
              ),
              Expanded(
                flex: 2,
                child: Text(u['phone'] ?? '-', style: TextStyle(color: textSecondary)),
              ),
              Text(u['created_at']?.split('T')[0] ?? '', style: TextStyle(color: textSecondary)),
              const SizedBox(width: 24),
              IconButton(onPressed: () => _editUser(u), icon: const Icon(Icons.edit, color: Colors.blue), tooltip: 'Edit'),
              IconButton(onPressed: () => _deleteUser(u['id'], u['name'] ?? ''), icon: const Icon(Icons.delete, color: Colors.redAccent), tooltip: 'Delete'),
            ],
          ),
        );
      },
    );
  }

  // ============ 3. GUARDIANS LIST ============
  Widget _buildGuardiansList() {
    return ListView.builder(
      padding: const EdgeInsets.all(32),
      itemCount: _guardians.length,
      itemBuilder: (context, index) {
        final g = _guardians[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          decoration: BoxDecoration(
            color: surfaceDark,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Row(
            children: [
              const Icon(Icons.shield, color: Colors.greenAccent),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(g['name'] ?? 'Guardian', style: TextStyle(fontWeight: FontWeight.bold, color: textPrimary)),
                    Text(g['email'] ?? '', style: TextStyle(color: textSecondary, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(onPressed: () => _deleteGuardian(g['id']), icon: const Icon(Icons.delete, color: Colors.redAccent)),
            ],
          ),
        );
      },
    );
  }

  // ============ 4. ALERTS LIST ============
  Widget _buildAlertsList() => Padding(padding: const EdgeInsets.all(32), child: _buildAlertsRefinedList());

  Widget _buildAlertsRefinedList({int? limit}) {
    final list = limit != null ? _alerts.take(limit).toList() : _alerts;
    
    return Column(
      children: list.map<Widget>((a) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceDark,
          borderRadius: BorderRadius.circular(12),
          border: Border(left: BorderSide(color: a['risk_level'] == 'HIGH' ? Colors.red : Colors.orange, width: 4)),
        ),
        child: Row(
          children: [
             Icon(
               a['risk_level'] == 'HIGH' ? Icons.error : Icons.warning,
               color: a['risk_level'] == 'HIGH' ? Colors.red : Colors.orange,
             ),
             const SizedBox(width: 16),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     a['message_preview'] ?? 'No content',
                     maxLines: 1, 
                     overflow: TextOverflow.ellipsis,
                     style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: textPrimary),
                   ),
                   const SizedBox(height: 4),
                   Row(
                     children: [
                       Text('User: ${a['user_name']}', style: TextStyle(fontSize: 12, color: textSecondary)),
                       const SizedBox(width: 12),
                       Text('Time: ${a['created_at']?.substring(11, 16)}', style: TextStyle(fontSize: 12, color: textSecondary)),
                     ],
                   ),
                 ],
               ),
             ),
             IconButton(onPressed: () => _deleteAlert(a['id']), icon: const Icon(Icons.delete, color: Colors.grey)),
          ],
        ),
      )).toList(),
    );
  }
  
  // Custom Dark TextField
  Widget _buildDarkTextField(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: textSecondary, fontSize: 12)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          style: TextStyle(color: textPrimary),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.black12,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white10)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: Colors.white10)),
          ),
        ),
      ],
    );
  }
}
