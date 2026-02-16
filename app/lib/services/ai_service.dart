
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

      // Log actual tensor shapes for debugging
      final inputTensors = _interpreter!.getInputTensors();
      final outputTensors = _interpreter!.getOutputTensors();
      for (int i = 0; i < inputTensors.length; i++) {
        debugPrint('📐 Input[$i]: shape=${inputTensors[i].shape}, type=${inputTensors[i].type}');
      }
      for (int i = 0; i < outputTensors.length; i++) {
        debugPrint('📐 Output[$i]: shape=${outputTensors[i].shape}, type=${outputTensors[i].type}');
      }

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

    // 2. Prepare input tensors as Int32 [1, SEQ_LEN]
    final inputIdsTensor = Int32List.fromList(inputIds);
    final attentionMaskTensor = Int32List.fromList(attentionMask);
    final seqLen = inputIds.length;

    // 3. Determine actual output shape from model
    final outputTensors = _interpreter!.getOutputTensors();
    final outputShape = outputTensors[0].shape; // e.g. [1, 3] or [1, 1]
    final numClasses = outputShape.last;
    debugPrint('📐 Model output shape: $outputShape (numClasses=$numClasses)');

    // 4. Prepare output buffer matching actual model shape
    final outputBuffer = List.generate(
      outputShape[0], 
      (_) => List.filled(numClasses, 0.0),
    );

    // 5. Run inference — adapt to model's actual input count
    final numInputs = _interpreter!.getInputTensors().length;
    debugPrint('📐 Model expects $numInputs input(s), seqLen=$seqLen');

    if (numInputs >= 2) {
      // Model expects both input_ids and attention_mask
      _interpreter!.runForMultipleInputs(
        [inputIdsTensor.reshape([1, seqLen]), attentionMaskTensor.reshape([1, seqLen])],
        {0: outputBuffer},
      );
    } else {
      // Model expects only input_ids (single input)
      _interpreter!.run(
        inputIdsTensor.reshape([1, seqLen]),
        outputBuffer,
      );
    }

    // 6. Process output (Softmax)
    List<double> logits = outputBuffer[0].map((e) => e.toDouble()).toList();
    List<double> probs = _softmax(logits);
    
    // DEBUG: Log all scores
    debugPrint('📊 Logits: ${logits.map((l) => l.toStringAsFixed(2)).toList()}');

    // Map labels based on actual number of output classes
    final List<String> classLabels;
    if (numClasses == 3) {
      classLabels = ['HAM', 'OTP', 'SCAM'];
      debugPrint('📊 Probs: HAM=${(probs[0]*100).toStringAsFixed(1)}%, OTP=${(probs[1]*100).toStringAsFixed(1)}%, SCAM=${(probs[2]*100).toStringAsFixed(1)}%');
    } else if (numClasses == 2) {
      classLabels = ['HAM', 'SCAM'];
      debugPrint('📊 Probs: HAM=${(probs[0]*100).toStringAsFixed(1)}%, SCAM=${(probs[1]*100).toStringAsFixed(1)}%');
    } else if (numClasses == 1) {
      // Binary sigmoid output: single value = scam probability
      final scamProb = probs[0].clamp(0.0, 1.0);
      debugPrint('📊 Sigmoid output: SCAM=${(scamProb*100).toStringAsFixed(1)}%');
      final label = scamProb > 0.5 ? 'SCAM' : 'HAM';
      final confidence = scamProb > 0.5 ? scamProb : (1.0 - scamProb);
      return {
        'label': label,
        'confidence': confidence,
        'detectedLanguage': detectedLang,
        'wasTranslated': wasTranslated,
        'scores': {'ham': 1.0 - scamProb, 'scam': scamProb},
      };
    } else {
      debugPrint('⚠️ Unexpected numClasses=$numClasses, defaulting to HAM');
      return {'label': 'HAM', 'confidence': 0.0};
    }
    
    int maxIdx = 0;
    double maxProb = probs[0];
    for (int i = 1; i < probs.length; i++) {
      if (probs[i] > maxProb) {
        maxProb = probs[i];
        maxIdx = i;
      }
    }

    String label = classLabels[maxIdx];
    
    // Build scores map dynamically
    final Map<String, double> scores = {};
    for (int i = 0; i < classLabels.length; i++) {
      scores[classLabels[i].toLowerCase()] = probs[i];
    }
    
    return {
        'label': label,
        'confidence': maxProb,
        'detectedLanguage': detectedLang,
        'wasTranslated': wasTranslated,
        'scores': scores,
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
