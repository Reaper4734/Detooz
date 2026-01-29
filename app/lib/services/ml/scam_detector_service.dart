/// ScamDetectorService - On-device SMS scam detection using TFLite
///
/// This service provides offline scam detection capabilities using a
/// MobileBERT model converted to TensorFlow Lite format.
///
/// Features:
/// - Fully offline inference (no network required)
/// - Three-class classification: HAM (safe), OTP (sensitive), SCAM (danger)
/// - Confidence scores for each prediction
/// - Lazy model loading with caching
///
/// Usage:
/// ```dart
/// final detector = ScamDetectorService();
/// await detector.initialize();
///
/// final result = await detector.detectScam("You won a lottery! Claim now!");
/// print(result.label);      // "SCAM"
/// print(result.confidence); // 0.98
/// print(result.isScam);     // true
/// ```
library;

import 'dart:math' as math;
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'vocab_loader.dart';
import 'token_encoder.dart';
import '../ui/components/tr.dart';

/// Result of scam detection inference
class DetectionResult {
  /// Raw label: tr("HAM"), "OTP", or "SCAM"
  final String label;
  
  /// Confidence score (0.0 to 1.0)
  final double confidence;
  
  /// Raw logits from the model (for debugging)
  final List<double> logits;
  
  /// Probabilities for each class after softmax
  final List<double> probabilities;

  DetectionResult({
    required this.label,
    required this.confidence,
    required this.logits,
    required this.probabilities,
  });

  /// Returns true if the message is classified as SCAM
  bool get isScam => label == 'SCAM';

  /// Returns true if the message is classified as OTP
  bool get isOtp => label == 'OTP';

  /// Returns true if the message is classified as HAM (safe)
  bool get isHam => label == 'HAM';

  /// Returns true if confidence is above the given threshold
  bool isConfidentAbove(double threshold) => confidence >= threshold;

  @override
  String toString() => 'DetectionResult($label, confidence: ${(confidence * 100).toStringAsFixed(1)}%)';
}

/// Service for detecting scam messages using on-device TFLite inference.
class ScamDetectorService {
  // Model file path in assets
  static const String _modelPath = 'assets/scam_detector.tflite';

  // Class labels (must match training order: 0=HAM, 1=OTP, 2=SCAM)
  static const List<String> _labels = ['HAM', 'OTP', 'SCAM'];

  // TFLite interpreter instance
  Interpreter? _interpreter;

  // Token encoder for text preprocessing
  final TokenEncoder _encoder = TokenEncoder();

  // Initialization state
  bool _isInitialized = false;

  /// Returns true if the service has been initialized
  bool get isInitialized => _isInitialized;

  /// Initializes the service by loading vocabulary and model.
  ///
  /// Must be called before [detectScam]. Safe to call multiple times.
  ///
  /// Throws [Exception] if model or vocabulary fails to load.
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Step 1: Load vocabulary
      await VocabLoader.load();

      // Step 2: Load TFLite model
      _interpreter = await Interpreter.fromAsset(_modelPath);

      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      throw Exception('Failed to initialize ScamDetectorService: $e');
    }
  }

  /// Detects if the given text is a scam.
  ///
  /// Returns a [DetectionResult] with:
  /// - [label]: "HAM", "OTP", or "SCAM"
  /// - [confidence]: Probability of the predicted class (0.0 to 1.0)
  /// - [logits]: Raw model outputs
  /// - [probabilities]: Softmax probabilities for all classes
  ///
  /// Throws [StateError] if service not initialized.
  /// Throws [Exception] if inference fails.
  Future<DetectionResult> detectScam(String text) async {
    if (!_isInitialized || _interpreter == null) {
      throw StateError('ScamDetectorService not initialized. Call initialize() first.');
    }

    try {
      // Step 1: Encode text to token IDs and attention mask
      final encoded = _encoder.encode(text);
      final inputIds = encoded['input_ids']!;
      final attentionMask = encoded['attention_mask']!;

      // Step 2: Prepare input tensors as Int32 (model expects int32)
      // Shape: [1, 128] for batch size 1, sequence length 128
      final inputIdsTensor = Int32List.fromList(inputIds);
      final attentionMaskTensor = Int32List.fromList(attentionMask);

      // Step 3: Prepare output buffer
      // Shape: [1, 3] for batch size 1, 3 classes
      final outputBuffer = List.generate(1, (_) => List.filled(3, 0.0));

      // Step 4: Run inference with reshaped inputs [1, 128]
      _interpreter!.runForMultipleInputs(
        [inputIdsTensor.reshape([1, 128]), attentionMaskTensor.reshape([1, 128])],
        {0: outputBuffer},
      );

      // Step 5: Extract logits
      final logits = outputBuffer[0].map((e) => e.toDouble()).toList();

      // Step 6: Apply softmax to get probabilities
      final probabilities = _softmax(logits);

      // Step 7: Find predicted class
      int predictedIdx = 0;
      double maxProb = probabilities[0];
      for (int i = 1; i < probabilities.length; i++) {
        if (probabilities[i] > maxProb) {
          maxProb = probabilities[i];
          predictedIdx = i;
        }
      }

      return DetectionResult(
        label: _labels[predictedIdx],
        confidence: maxProb,
        logits: logits,
        probabilities: probabilities,
      );
    } catch (e) {
      throw Exception('Inference failed: $e');
    }
  }

  /// Applies softmax to convert logits to probabilities.
  List<double> _softmax(List<double> logits) {
    // Subtract max for numerical stability
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);
    final expLogits = logits.map((l) => _safeExp(l - maxLogit)).toList();
    final sumExp = expLogits.reduce((a, b) => a + b);
    return expLogits.map((e) => e / sumExp).toList();
  }

  /// Safe exponential function to avoid overflow
  double _safeExp(double x) {
    if (x > 700) return double.maxFinite;
    if (x < -700) return 0.0;
    return math.exp(x);
  }

  /// Releases resources. Call when done using the service.
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
    _isInitialized = false;
  }
}
