/// Unit tests for ScanViewModel, RiskLevel, and PlatformType
///
/// Tests the JSON deserialization, risk level parsing, and platform
/// type parsing logic that is critical for correctly displaying scan
/// results across the app.
///
/// Run with: flutter test test/scan_view_model_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:app/contracts/scan_view_model.dart';
import 'package:app/contracts/risk_level.dart';

void main() {
  group('ScanViewModel.fromJson', () {
    test('parses complete JSON correctly', () {
      final json = {
        'id': 42,
        'sender': '+919876543210',
        'message': 'You won a lottery! Claim now!',
        'message_preview': 'You won a lottery...',
        'risk_level': 'HIGH',
        'platform': 'SMS',
        'risk_reason': 'Lottery scam pattern detected',
        'confidence': 0.95,
        'source': 'local',
        'created_at': '2026-02-20T10:30:00Z',
      };

      final scan = ScanViewModel.fromJson(json);

      expect(scan.id, '42');
      expect(scan.senderNumber, '+919876543210');
      expect(scan.sender, '+919876543210');
      expect(scan.message, 'You won a lottery! Claim now!');
      expect(scan.messagePreview, 'You won a lottery...');
      expect(scan.riskLevel, RiskLevel.high);
      expect(scan.platform, PlatformType.sms);
      expect(scan.riskReason, 'Lottery scam pattern detected');
      expect(scan.confidence, 0.95);
      expect(scan.source, 'local');
      expect(scan.scannedAt.year, 2026);
    });

    test('handles missing optional fields with defaults', () {
      final json = {
        'id': 1,
        'message': 'Hello',
      };

      final scan = ScanViewModel.fromJson(json);

      expect(scan.id, '1');
      expect(scan.senderNumber, 'Unknown');
      expect(scan.messagePreview, 'Hello'); // Falls back to message
      expect(scan.riskLevel, RiskLevel.low); // Default
      expect(scan.platform, PlatformType.sms); // Default
      expect(scan.riskReason, isNull);
      expect(scan.confidence, isNull);
      expect(scan.source, 'cloud'); // Default
    });

    test('handles null id gracefully', () {
      final json = {
        'id': null,
        'message': 'Test',
      };

      final scan = ScanViewModel.fromJson(json);
      expect(scan.id, '');
    });

    test('handles string id', () {
      final json = {
        'id': 'abc-123',
        'message': 'Test',
      };

      final scan = ScanViewModel.fromJson(json);
      expect(scan.id, 'abc-123');
    });

    test('handles invalid date gracefully', () {
      final json = {
        'id': 1,
        'message': 'Test',
        'created_at': 'not-a-date',
      };

      final scan = ScanViewModel.fromJson(json);
      // Should fallback to DateTime.now() — just verify it doesn't crash
      expect(scan.scannedAt, isA<DateTime>());
    });

    test('handles integer confidence correctly', () {
      final json = {
        'id': 1,
        'message': 'Test',
        'confidence': 1, // int, not double
      };

      final scan = ScanViewModel.fromJson(json);
      expect(scan.confidence, 1.0);
    });
  });

  group('RiskLevel parsing', () {
    test('parses HIGH correctly', () {
      final scan = ScanViewModel.fromJson({
        'id': 1,
        'message': 'Test',
        'risk_level': 'HIGH',
      });
      expect(scan.riskLevel, RiskLevel.high);
    });

    test('parses MEDIUM correctly', () {
      final scan = ScanViewModel.fromJson({
        'id': 1,
        'message': 'Test',
        'risk_level': 'MEDIUM',
      });
      expect(scan.riskLevel, RiskLevel.medium);
    });

    test('parses LOW correctly', () {
      final scan = ScanViewModel.fromJson({
        'id': 1,
        'message': 'Test',
        'risk_level': 'LOW',
      });
      expect(scan.riskLevel, RiskLevel.low);
    });

    test('is case-insensitive', () {
      final scan = ScanViewModel.fromJson({
        'id': 1,
        'message': 'Test',
        'risk_level': 'high',
      });
      expect(scan.riskLevel, RiskLevel.high);
    });

    test('defaults to LOW for unknown values', () {
      final scan = ScanViewModel.fromJson({
        'id': 1,
        'message': 'Test',
        'risk_level': 'CRITICAL',
      });
      expect(scan.riskLevel, RiskLevel.low);
    });

    test('defaults to LOW for null', () {
      final scan = ScanViewModel.fromJson({
        'id': 1,
        'message': 'Test',
        'risk_level': null,
      });
      expect(scan.riskLevel, RiskLevel.low);
    });
  });

  group('PlatformType parsing', () {
    test('parses SMS correctly', () {
      final scan = ScanViewModel.fromJson({
        'id': 1,
        'message': 'Test',
        'platform': 'SMS',
      });
      expect(scan.platform, PlatformType.sms);
    });

    test('parses WHATSAPP correctly', () {
      final scan = ScanViewModel.fromJson({
        'id': 1,
        'message': 'Test',
        'platform': 'WHATSAPP',
      });
      expect(scan.platform, PlatformType.whatsapp);
    });

    test('parses TELEGRAM correctly', () {
      final scan = ScanViewModel.fromJson({
        'id': 1,
        'message': 'Test',
        'platform': 'TELEGRAM',
      });
      expect(scan.platform, PlatformType.telegram);
    });

    test('is case-insensitive', () {
      final scan = ScanViewModel.fromJson({
        'id': 1,
        'message': 'Test',
        'platform': 'whatsapp',
      });
      expect(scan.platform, PlatformType.whatsapp);
    });

    test('defaults to SMS for unknown values', () {
      final scan = ScanViewModel.fromJson({
        'id': 1,
        'message': 'Test',
        'platform': 'SIGNAL',
      });
      expect(scan.platform, PlatformType.sms);
    });

    test('defaults to SMS for null', () {
      final scan = ScanViewModel.fromJson({
        'id': 1,
        'message': 'Test',
        'platform': null,
      });
      expect(scan.platform, PlatformType.sms);
    });
  });
}
