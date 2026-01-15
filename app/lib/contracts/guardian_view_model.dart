class GuardianViewModel {
  final String id;
  final String name;
  final String phone;
  final bool isVerified;
  final DateTime? lastAlertSent;

  GuardianViewModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.isVerified,
    this.lastAlertSent,
  });
}
