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
  final String messagePreview;
  final RiskLevel riskLevel;
  final PlatformType platform;
  final String? riskReason;
  final DateTime scannedAt;

  ScanViewModel({
    required this.id,
    required this.senderNumber,
    required this.messagePreview,
    required this.riskLevel,
    required this.platform,
    this.riskReason,
    required this.scannedAt,
  });
}
