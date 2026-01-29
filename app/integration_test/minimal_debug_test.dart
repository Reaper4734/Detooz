/// Minimal debug test to pinpoint the issue
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:app/services/ml/vocab_loader.dart';
import 'package:app/services/ml/token_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Minimal TFLite Test', () async {
    // Load vocab
    await VocabLoader.load();
    print('Vocab loaded: ${VocabLoader.vocabSize}');
    
    // Load model
    final interpreter = await Interpreter.fromAsset('assets/scam_detector.tflite');
    print('Model loaded');
    
    // Encode text
    final encoder = TokenEncoder();
    const text = 'Your OTP is 123456. Do not share with anyone.';
    final encoded = encoder.encode(text);
    
    final inputIds = encoded['input_ids']!;
    final attentionMask = encoded['attention_mask']!;
    
    print('Input IDs (first 15): ${inputIds.sublist(0, 15)}');
    print('Length: ${inputIds.length}');
    
    // Python reference:
    // [101, 2115, 27178, 2361, 2003, 13138, 19961, 2575, 1012, 2079, 2025, 3745, 2007, 3087, 1012]
    print('Python ref: [101, 2115, 27178, 2361, 2003, 13138, 19961, 2575, 1012, 2079, 2025, 3745, 2007, 3087, 1012]');
    
    // Create tensors
    final inputIdsTensor = Int32List.fromList(inputIds);
    final attentionMaskTensor = Int32List.fromList(attentionMask);
    
    // Create output buffer
    final output = List.generate(1, (_) => List.filled(3, 0.0));
    
    // Run inference
    interpreter.runForMultipleInputs(
      [inputIdsTensor.reshape([1, 128]), attentionMaskTensor.reshape([1, 128])],
      {0: output},
    );
    
    print('Raw output: ${output[0]}');
    // Python reference: [-5.875, 5.960, -6.184]
    print('Python ref: [-5.875, 5.960, -6.184]');
    
    // Softmax
    final logits = output[0];
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expLogits = logits.map((l) => _exp(l - maxLogit)).toList();
    final sumExp = expLogits.reduce((a, b) => a + b);
    final probs = expLogits.map((e) => e / sumExp).toList();
    
    print('Probs: HAM=${probs[0].toStringAsFixed(4)}, OTP=${probs[1].toStringAsFixed(4)}, SCAM=${probs[2].toStringAsFixed(4)}');
    
    interpreter.close();
  });
}

double _exp(double x) {
  double result = 1.0;
  double term = 1.0;
  for (int i = 1; i <= 30; i++) {
    term *= x / i;
    result += term;
    if (term.abs() < 1e-15) break;
  }
  return result;
}
