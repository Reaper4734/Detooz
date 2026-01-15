class GuardianViewModel {
  final String id;
  final String name;
  final String phone;
  final bool isVerified;
  final String? telegramChatId;
  final DateTime? lastAlertSent;

  GuardianViewModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.isVerified,
    this.telegramChatId,
    this.lastAlertSent,
  });
  
  /// Create from API JSON response
  factory GuardianViewModel.fromJson(Map<String, dynamic> json) {
    return GuardianViewModel(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      phone: json['phone'] ?? '',
      isVerified: json['is_verified'] ?? false,
      telegramChatId: json['telegram_chat_id'],
      lastAlertSent: json['last_alert_sent'] != null 
          ? DateTime.tryParse(json['last_alert_sent'])
          : null,
    );
  }
  
  /// Get status text for display
  String get statusText {
    if (lastAlertSent != null) {
      final diff = DateTime.now().difference(lastAlertSent!);
      if (diff.inMinutes < 60) {
        return 'Alerted ${diff.inMinutes}m ago';
      } else if (diff.inHours < 24) {
        return 'Alerted ${diff.inHours}h ago';
      }
    }
    return isVerified ? 'Active Protection' : 'Request Pending';
  }
}
