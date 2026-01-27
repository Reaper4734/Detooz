/// Direct comparison test
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/ml/scam_detector_service.dart';
import 'package:app/services/ml/vocab_loader.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Direct ScamDetectorService test', () async {
    final detector = ScamDetectorService();
    await detector.initialize();
    print('✅ Initialized, vocab size: ${VocabLoader.vocabSize}');

    // Test 1: OTP message
    var result = await detector.detectScam('Your OTP is 123456. Do not share with anyone.');
    print('\nTest 1: OTP message');
    print('  Logits: ${result.logits}');
    print('  Probs: ${result.probabilities}');
    print('  Result: ${result.label} (${(result.confidence * 100).toStringAsFixed(1)}%)');
    print('  isOTP: ${result.isOtp}');
    
    // Test 2: SCAM message  
    result = await detector.detectScam('You won a lottery! Call now to claim your prize.');
    print('\nTest 2: SCAM message');
    print('  Logits: ${result.logits}');
    print('  Probs: ${result.probabilities}');
    print('  Result: ${result.label} (${(result.confidence * 100).toStringAsFixed(1)}%)');
    print('  isScam: ${result.isScam}');
    
    // Test 3: HAM message
    result = await detector.detectScam('Hey, want to grab lunch?');
    print('\nTest 3: HAM message');
    print('  Logits: ${result.logits}');
    print('  Probs: ${result.probabilities}');
    print('  Result: ${result.label} (${(result.confidence * 100).toStringAsFixed(1)}%)');
    print('  isHam: ${result.isHam}');

    detector.dispose();
  });
}
