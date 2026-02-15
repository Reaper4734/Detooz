
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'ml/sms_translator.dart';
import 'ml/token_encoder.dart';
import 'ml/vocab_loader.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();
  Interpreter? _interpreter;
  bool _isLoaded = false;

  // Proper WordPiece tokenizer (matches model training)
  final TokenEncoder _encoder = TokenEncoder();

  // SMS translator for Regional → English (on-device)
  final SmsTranslator _smsTranslator = SmsTranslator();

  // Configuration
  static const String MODEL_PATH = 'assets/scam_detector.tflite';

  Future<void> loadModel() async {
    if (_isLoaded) return;
    try {
      debugPrint('🤖 Initializing AI Model...');
      // Load vocabulary for WordPiece tokenizer
      await VocabLoader.load();
      debugPrint('✅ AI Vocab Loaded (${VocabLoader.vocabSize} tokens)');

      // Load TFLite model
      _interpreter = await Interpreter.fromAsset(MODEL_PATH);
      debugPrint('✅ AI Model Interpreter Loaded successfully');

      // Initialize SMS translator for multilingual detection
      try {
        await _smsTranslator.initialize();
        debugPrint('✅ SmsTranslator initialized for detection pipeline');
      } catch (e) {
        debugPrint('⚠️ SmsTranslator init failed (detection will use raw text): $e');
      }
      
      _isLoaded = true;
    } catch (e) {
      debugPrint('❌ CRITICAL: Failed to load AI Model ($MODEL_PATH): $e');
      if (e is FlutterError) {
        debugPrint('💡 Tip: Ensure the asset is correctly listed in pubspec.yaml and the file exists in assets/.');
      }
    }
  }

  Future<Map<String, dynamic>> predict(String smsText) async {
    if (!_isLoaded) await loadModel();
    if (_interpreter == null) return {'label': 'ERROR', 'confidence': 0.0};

    // 0. Translate regional SMS → English (if model available)
    String textForModel = smsText;
    String detectedLang = 'en';
    bool wasTranslated = false;
    try {
      final tr = await _smsTranslator.translateForDetection(smsText);
      textForModel = tr.textForModel;
      detectedLang = tr.detectedLanguage;
      wasTranslated = tr.wasTranslated;
      if (wasTranslated) {
        debugPrint('🌐 Detection using translated text: "$textForModel"');
      }
    } catch (e) {
      debugPrint('⚠️ Translation step failed, using original text: $e');
    }

    // 1. Tokenize with proper WordPiece (matches BERT training)
    final encoded = _encoder.encode(textForModel);
    final inputIds = encoded['input_ids']!;
    final attentionMask = encoded['attention_mask']!;
    
    // DEBUG: Log tokenization
    debugPrint('🔤 Tokenizing: "$textForModel"');
    final nonZeroTokens = inputIds.where((t) => t != 0).toList();
    debugPrint('🔤 Token IDs (non-zero): $nonZeroTokens');

    // 2. Prepare input tensors as Int32 [1, 128]
    final inputIdsTensor = Int32List.fromList(inputIds);
    final attentionMaskTensor = Int32List.fromList(attentionMask);

    // 3. Prepare output buffer [1, 3]
    final outputBuffer = List.generate(1, (_) => List.filled(3, 0.0));

    // 4. Run inference with BOTH inputs (input_ids + attention_mask)
    _interpreter!.runForMultipleInputs(
      [inputIdsTensor.reshape([1, 128]), attentionMaskTensor.reshape([1, 128])],
      {0: outputBuffer},
    );

    // 5. Process output (Softmax)
    List<double> logits = outputBuffer[0].map((e) => e.toDouble()).toList();
    List<double> probs = _softmax(logits);
    
    // DEBUG: Log all scores
    debugPrint('📊 Logits: ${logits.map((l) => l.toStringAsFixed(2)).toList()}');
    debugPrint('📊 Probs: HAM=${(probs[0]*100).toStringAsFixed(1)}%, OTP=${(probs[1]*100).toStringAsFixed(1)}%, SCAM=${(probs[2]*100).toStringAsFixed(1)}%');
    
    int maxIdx = 0;
    double maxProb = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > maxProb) {
        maxProb = probs[i];
        maxIdx = i;
      }
    }

    String label = ['HAM', 'OTP', 'SCAM'][maxIdx];
    return {
        'label': label,
        'confidence': maxProb,
        'detectedLanguage': detectedLang,
        'wasTranslated': wasTranslated,
        'scores': {
            'ham': probs[0],
            'otp': probs[1],
            'scam': probs[2]
        }
    };
  }

  // --- Helpers ---

  /// Safe softmax with numerical stability
  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return [];
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expValues = logits.map((x) {
      final v = x - maxLogit;
      if (v > 700) return double.maxFinite;
      if (v < -700) return 0.0;
      return exp(v);
    }).toList();
    final sumExp = expValues.reduce((a, b) => a + b);
    return expValues.map((e) => e / sumExp).toList();
  }
}

final aiService = AIService();
