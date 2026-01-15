import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../contracts/scan_view_model.dart';
import '../../contracts/risk_level.dart';

// Mock Data
final List<ScanViewModel> _mockScans = [
  ScanViewModel(
    id: '1',
    senderNumber: '+91-98765-43210',
    messagePreview: 'Congratulations! You have won Rs. 50,00,000 in the India Lottery...',
    riskLevel: RiskLevel.high,
    platform: PlatformType.sms,
    scannedAt: DateTime.now().subtract(const Duration(minutes: 2)),
  ),
  ScanViewModel(
    id: '2',
    senderNumber: 'HDFC Bank',
    messagePreview: 'Your OTP is 456789. Do not share this with anyone.',
    riskLevel: RiskLevel.low,
    platform: PlatformType.sms,
    scannedAt: DateTime.now().subtract(const Duration(hours: 1)),
  ),
  ScanViewModel(
    id: '3',
    senderNumber: 'Unknown',
    messagePreview: 'Hello dear friend, I have a business proposal for you.',
    riskLevel: RiskLevel.medium,
    platform: PlatformType.whatsapp,
    scannedAt: DateTime.now().subtract(const Duration(days: 1)),
  ),
];

// Providers
final recentScansProvider = Provider<List<ScanViewModel>>((ref) {
  return _mockScans;
});

final scanHistoryProvider = Provider<List<ScanViewModel>>((ref) {
  return _mockScans; // For now return same list
});
