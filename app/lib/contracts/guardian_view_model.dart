class GuardianViewModel {
  final String id;
  final String name;
  final String email;
  final bool isVerified;
  final String status;
  final DateTime? createdAt;

  GuardianViewModel({
    required this.id,
    required this.name,
    required this.email,
    required this.isVerified,
    required this.status,
    this.createdAt,
  });
  
  /// Create from API JSON response
  factory GuardianViewModel.fromJson(Map<String, dynamic> json) {
    return GuardianViewModel(
      id: json['guardian_id']?.toString() ?? '',
      name: json['guardian_name'] ?? 'Unknown',
      email: json['guardian_email'] ?? '',
      isVerified: json['status'] == 'active',
      status: json['status'] ?? 'pending',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }
  
  /// Get status text for display
  String get statusText {
    if (status == 'active') return 'Active Protection';
    if (status == 'pending') return 'Request Pending';
    return status.toUpperCase();
  }
}
