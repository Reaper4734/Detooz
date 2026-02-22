/// Unit tests for DetectionResult
///
/// Tests the pure logic of the DetectionResult class used by ScamDetectorService.
/// This includes label classification checks, confidence thresholding, and string representation.
///
/// Run with: flutter test test/detection_result_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/ml/scam_detector_service.dart';

void main() {
  group('DetectionResult — Label Checks', () {
    test('isScam returns true for SCAM label', () {
      final result = DetectionResult(
        label: 'SCAM',
        confidence: 0.95,
        logits: [0.1, 0.1, 5.0],
        probabilities: [0.02, 0.03, 0.95],
      );
      expect(result.isScam, true);
      expect(result.isOtp, false);
      expect(result.isHam, false);
    });

    test('isOtp returns true for OTP label', () {
      final result = DetectionResult(
        label: 'OTP',
        confidence: 0.88,
        logits: [0.1, 5.0, 0.1],
        probabilities: [0.05, 0.88, 0.07],
      );
      expect(result.isScam, false);
      expect(result.isOtp, true);
      expect(result.isHam, false);
    });

    test('isHam returns true for HAM label', () {
      final result = DetectionResult(
        label: 'HAM',
        confidence: 0.92,
        logits: [5.0, 0.1, 0.1],
        probabilities: [0.92, 0.04, 0.04],
      );
      expect(result.isScam, false);
      expect(result.isOtp, false);
      expect(result.isHam, true);
    });
  });

  group('DetectionResult — Confidence Thresholding', () {
    test('isConfidentAbove returns true when confidence >= threshold', () {
      final result = DetectionResult(
        label: 'SCAM',
        confidence: 0.95,
        logits: [0.1, 0.1, 5.0],
        probabilities: [0.02, 0.03, 0.95],
      );
      expect(result.isConfidentAbove(0.90), true);
      expect(result.isConfidentAbove(0.95), true);
    });

    test('isConfidentAbove returns false when confidence < threshold', () {
      final result = DetectionResult(
        label: 'SCAM',
        confidence: 0.65,
        logits: [0.1, 0.1, 2.0],
        probabilities: [0.15, 0.20, 0.65],
      );
      expect(result.isConfidentAbove(0.70), false);
      expect(result.isConfidentAbove(0.90), false);
    });

    test('edge case: exactly at threshold returns true', () {
      final result = DetectionResult(
        label: 'HAM',
        confidence: 0.50,
        logits: [1.0, 0.5, 0.5],
        probabilities: [0.50, 0.25, 0.25],
      );
      expect(result.isConfidentAbove(0.50), true);
    });
  });

  group('DetectionResult — Translation Fields', () {
    test('defaults to English, not translated', () {
      final result = DetectionResult(
        label: 'HAM',
        confidence: 0.90,
        logits: [5.0, 0.1, 0.1],
        probabilities: [0.90, 0.05, 0.05],
      );
      expect(result.detectedLanguage, 'en');
      expect(result.wasTranslated, false);
      expect(result.originalText, isNull);
      expect(result.translatedText, isNull);
    });

    test('correctly stores translation info', () {
      final result = DetectionResult(
        label: 'SCAM',
        confidence: 0.88,
        logits: [0.1, 0.1, 4.0],
        probabilities: [0.05, 0.07, 0.88],
        detectedLanguage: 'hi',
        wasTranslated: true,
        originalText: 'आपने लॉटरी जीती है!',
        translatedText: 'You have won the lottery!',
      );
      expect(result.detectedLanguage, 'hi');
      expect(result.wasTranslated, true);
      expect(result.originalText, 'आपने लॉटरी जीती है!');
      expect(result.translatedText, 'You have won the lottery!');
    });
  });

  group('DetectionResult — toString', () {
    test('formats correctly with percentage', () {
      final result = DetectionResult(
        label: 'SCAM',
        confidence: 0.9523,
        logits: [0.1, 0.1, 5.0],
        probabilities: [0.02, 0.03, 0.95],
      );
      expect(result.toString(), 'DetectionResult(SCAM, confidence: 95.2%)');
    });

    test('formats low confidence correctly', () {
      final result = DetectionResult(
        label: 'HAM',
        confidence: 0.333,
        logits: [1.0, 0.5, 0.5],
        probabilities: [0.33, 0.33, 0.34],
      );
      expect(result.toString(), 'DetectionResult(HAM, confidence: 33.3%)');
    });
  });
}
