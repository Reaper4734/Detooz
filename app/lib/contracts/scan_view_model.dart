import 'risk_level.dart';

enum PlatformType {
  sms,
  whatsapp,
  telegram,
}

class ScanViewModel {
  final String id;
  final String senderNumber;
  String get sender => senderNumber;
  final String message;
  final String messagePreview;
  final RiskLevel riskLevel;
  final PlatformType platform;
  final String? riskReason;
  final double? confidence;
  final String source;  // 'local' or 'cloud'
  final DateTime scannedAt;

  ScanViewModel({
    required this.id,
    required this.senderNumber,
    required this.message,
    required this.messagePreview,
    required this.riskLevel,
    required this.platform,
    this.riskReason,
    this.confidence,
    this.source = 'cloud',
    required this.scannedAt,
  });
  
  /// Create from API JSON response
  factory ScanViewModel.fromJson(Map<String, dynamic> json) {
    return ScanViewModel(
      id: json['id']?.toString() ?? '',
      senderNumber: json['sender'] ?? 'Unknown',
      message: json['message'] ?? '',
      messagePreview: json['message_preview'] ?? json['message'] ?? '',
      riskLevel: _parseRiskLevel(json['risk_level']),
      platform: _parsePlatform(json['platform']),
      riskReason: json['risk_reason'],
      confidence: (json['confidence'] as num?)?.toDouble(),
      source: json['source'] ?? 'cloud',
      scannedAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
    );
  }
  
  static RiskLevel _parseRiskLevel(String? level) {
    switch (level?.toUpperCase()) {
      case 'HIGH':
        return RiskLevel.high;
      case 'MEDIUM':
        return RiskLevel.medium;
      default:
        return RiskLevel.low;
    }
  }
  
  static PlatformType _parsePlatform(String? platform) {
    switch (platform?.toUpperCase()) {
      case 'WHATSAPP':
        return PlatformType.whatsapp;
      case 'TELEGRAM':
        return PlatformType.telegram;
      default:
        return PlatformType.sms;
    }
  }
}
