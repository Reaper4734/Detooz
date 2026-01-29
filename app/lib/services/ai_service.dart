
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class AIService {
  static final AIService _instance = AIService._internal();
  factory AIService() => _instance;
  AIService._internal();
  Interpreter? _interpreter;
  List<String> _vocab = [];
  bool _isLoaded = false;

  // Configuration
  static const int MAX_LEN = 128;
  static const String MODEL_PATH = 'assets/scam_detector.tflite';
  static const String VOCAB_PATH = 'assets/vocab.txt';

  Future<void> loadModel() async {
    if (_isLoaded) return;
    try {
      debugPrint('🤖 Initializing AI Model...');
      // Load Model
      _interpreter = await Interpreter.fromAsset(MODEL_PATH);
      debugPrint('✅ AI Model Interpreter Loaded successfully');

      // Load Vocab
      final vocabStr = await rootBundle.loadString(VOCAB_PATH);
      // Support both LF (\n) and CRLF (\r\n) line endings
      _vocab = vocabStr.split(RegExp(r'\r?\n'));
      
      // Filter out empty tokens that might result from trailing newlines
      _vocab = _vocab.where((t) => t.isNotEmpty).toList();
      
      debugPrint('✅ AI Vocab Loaded (${_vocab.length} tokens)');
      
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

    // 1. Tokenize 
    List<int> inputIds = _tokenize(smsText);

    // 2. Prepare Inputs/Outputs
    // Input: [1, 128] int32
    var input = [inputIds]; 
    
    // Output: [1, 3] float32
    var output = List.filled(1 * 3, 0.0).reshape([1, 3]);

    // 3. Run Inference
    _interpreter!.run(input, output);

    // 4. Process Output (Softmax)
    List<double> logits = List<double>.from(output[0]);
    List<double> probs = _softmax(logits);
    
    int maxIdx = 0;
    double maxConf = 0.0;
    
    for (int i = 0; i < probs.length; i++) {
        if (probs[i] > maxConf) {
            maxConf = probs[i];
            maxIdx = i;
        }
    }

    String label = ['HAM', 'OTP', 'SCAM'][maxIdx];
    return {
        'label': label,
        'confidence': maxConf,
        'scores': {
            'ham': probs[0],
            'otp': probs[1],
            'scam': probs[2]
        }
    };
  }

  // --- Helpers ---

  List<int> _tokenize(String text) {
    List<int> ids = List.filled(MAX_LEN, 0);
    ids[0] = 101; // [CLS]
    
    // Simple whitespace + punctuation split
    // Ideally use a proper WordPiece tokenizer package
    var words = text.toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ') // Replace punct with space
        .split(RegExp(r'\s+'));
        
    int idx = 1;
    
    for (var word in words) {
        if (idx >= MAX_LEN - 1) break;
        if (word.isEmpty) continue;
        
        // Try direct match
        int tokenId = _vocab.indexOf(word);
        if (tokenId == -1) {
             tokenId = 100; // [UNK]
        }
        
        ids[idx] = tokenId;
        idx++;
    }
    
    ids[idx] = 102; // [SEP]
    return ids;
  }

  List<double> _softmax(List<double> logits) {
    if (logits.isEmpty) return [];
    double maxLogit = logits.reduce(max);
    List<double> expValues = logits.map((x) => exp(x - maxLogit)).toList();
    double sumExp = expValues.reduce((a, b) => a + b);
    return expValues.map((e) => e / sumExp).toList();
  }
}

final aiService = AIService();
