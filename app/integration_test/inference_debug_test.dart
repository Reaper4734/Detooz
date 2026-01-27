/// Detailed inference debugging test
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/ml/scam_detector_service.dart';
import 'package:app/services/ml/token_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Inference Debug', () {
    late ScamDetectorService detector;

    setUpAll(() async {
      detector = ScamDetectorService();
      await detector.initialize();
      print('Initialized');
    });

    test('debug OTP message', () async {
      const text = 'Your OTP is 123456. Do not share with anyone.';
      
      // Get tokenization
      final encoder = TokenEncoder();
      final encoded = encoder.encode(text);
      final ids = encoded['input_ids']!;
      final mask = encoded['attention_mask']!;
      
      print('Text: $text');
      print('Input IDs (first 15): ${ids.sublist(0, 15)}');
      print('Attention Mask (first 15): ${mask.sublist(0, 15)}');
      
      // Python reference:
      // Input IDs: [101, 2115, 27178, 2361, 2003, 13138, 19961, 2575, 1012, 2079, 2025, 3745, 2007, 3087, 1012]
      print('\nPython reference IDs: [101, 2115, 27178, 2361, 2003, 13138, 19961, 2575, 1012, 2079, 2025, 3745, 2007, 3087, 1012]');
      
      // Run detection
      final result = await detector.detectScam(text);
      
      print('\nRaw logits: ${result.logits}');
      print('Probabilities: ${result.probabilities}');
      print('Prediction: ${result.label} (${(result.confidence * 100).toStringAsFixed(1)}%)');
      
      // Python reference output:
      // Raw output: [-5.8753467  5.9601884 -6.183835 ]
      // Probabilities: HAM=0.0000, OTP=1.0000, SCAM=0.0000
      print('\nPython reference:');
      print('  Logits: [-5.875, 5.960, -6.184]');
      print('  Expected: OTP (100%)');
      
      expect(result.isOtp, isTrue, reason: 'Expected OTP but got ${result.label}');
    });

    test('debug SCAM message', () async {
      const text = 'You won a lottery of Rs 50 lakh! Call 9876543210 to claim';
      
      final result = await detector.detectScam(text);
      
      print('Text: $text');
      print('Raw logits: ${result.logits}');
      print('Probabilities: ${result.probabilities}');
      print('Prediction: ${result.label} (${(result.confidence * 100).toStringAsFixed(1)}%)');
      
      // Python reference:
      // Raw output: [-2.939, -9.114, 12.699]
      // Expected: SCAM (100%)
      print('\nPython reference:');
      print('  Logits: [-2.939, -9.114, 12.699]');
      print('  Expected: SCAM (100%)');
      
      expect(result.isScam, isTrue, reason: 'Expected SCAM but got ${result.label}');
    });

    test('debug HAM message', () async {
      const text = 'Hey, want to grab lunch tomorrow?';
      
      final result = await detector.detectScam(text);
      
      print('Text: $text');
      print('Raw logits: ${result.logits}');
      print('Probabilities: ${result.probabilities}');
      print('Prediction: ${result.label} (${(result.confidence * 100).toStringAsFixed(1)}%)');
      
      // Python reference:
      // Raw output: [ 8.390, -6.193, -3.245]
      // Expected: HAM (100%)
      print('\nPython reference:');
      print('  Logits: [8.390, -6.193, -3.245]');
      print('  Expected: HAM (100%)');
      
      expect(result.isHam, isTrue, reason: 'Expected HAM but got ${result.label}');
    });
  });
}
