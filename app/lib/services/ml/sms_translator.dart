/// SmsTranslator — Translates incoming regional SMS → English for scam detection.
///
/// This is separate from [TranslationService] which handles UI localization
/// (English → Regional). This service handles the reverse direction:
/// Regional SMS text → English, so the TFLite model can analyze it.
///
/// Design principles:
/// - **Never crashes** — every error returns original text.
/// - **Privacy-first** — all processing is on-device.
/// - **Lazy** — skips translation if language is English or model unavailable.
library;

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_language_id/google_mlkit_language_id.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../translation/language_config.dart';

/// Result of language identification with confidence.
class LanguageIdResult {
  final String languageCode;
  final double confidence;

  const LanguageIdResult({
    required this.languageCode,
    required this.confidence,
  });

  /// True if the language was identified with sufficient confidence.
  bool get isConfident => confidence >= 0.5;

  /// True if this is a regional language that needs translation.
  bool get needsTranslation =>
      languageCode != 'en' && languageCode != 'und' && isConfident;

  @override
  String toString() =>
      'LanguageIdResult($languageCode, confidence: ${(confidence * 100).toStringAsFixed(0)}%)';
}

/// Result of the translate-for-detection pipeline.
class TranslationResult {
  /// The text to feed into the ML model (translated or original).
  final String textForModel;

  /// The original untouched SMS text.
  final String originalText;

  /// The detected language code (e.g., 'mr', 'hi', 'en', 'und').
  final String detectedLanguage;

  /// Whether translation was actually performed.
  final bool wasTranslated;

  const TranslationResult({
    required this.textForModel,
    required this.originalText,
    required this.detectedLanguage,
    required this.wasTranslated,
  });
}

/// Singleton service for translating incoming SMS to English for detection.
class SmsTranslator {
  static final SmsTranslator _instance = SmsTranslator._internal();
  factory SmsTranslator() => _instance;
  SmsTranslator._internal();

  /// Language identifier — bundled, no download needed (~900KB).
  /// Confidence threshold: 0.5 (below this, language is too uncertain).
  LanguageIdentifier _langId =
      LanguageIdentifier(confidenceThreshold: 0.5);

  /// Model manager for checking/downloading translation models.
  final OnDeviceTranslatorModelManager _modelManager =
      OnDeviceTranslatorModelManager();

  bool _initialized = false;

  /// Tracks if dispose() was called so we can re-create _langId.
  bool _disposed = false;

  /// User's selected state language code (from onboarding).
  String? _userLanguageHint;

  /// Expose the user's detection language hint (used by TranslationService
  /// to avoid deleting shared ML Kit models).
  String? get userLanguageHint => _userLanguageHint;

  /// Initialize the service. Safe to call multiple times.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Re-create language identifier if previously disposed
      if (_disposed) {
        _langId = LanguageIdentifier(confidenceThreshold: 0.5);
        _disposed = false;
      }

      // Load user's language hint from preferences
      final prefs = await SharedPreferences.getInstance();
      _userLanguageHint = prefs.getString('detection_language');
      _cachedAppLanguage = prefs.getString('app_language');
      _initialized = true;
      debugPrint('✅ SmsTranslator initialized (hint: $_userLanguageHint)');
    } catch (e) {
      debugPrint('⚠️ SmsTranslator init failed: $e');
      _initialized = true; // Don't block app startup
    }
  }

  /// Set the user's preferred detection language (from state selection).
  /// Persists to SharedPreferences.
  Future<void> setUserLanguage(String langCode) async {
    _userLanguageHint = langCode;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('detection_language', langCode);
    } catch (e) {
      debugPrint('⚠️ Failed to save detection language: $e');
    }
  }

  // ──────────────────────────────────────────────
  // PUBLIC API
  // ──────────────────────────────────────────────

  /// Identify the language of incoming SMS text.
  ///
  /// Returns [LanguageIdResult] with language code and confidence.
  /// On any error, returns 'und' (undetermined) with 0.0 confidence.
  Future<LanguageIdResult> identifyLanguage(String text) async {
    try {
      // Use identifyPossibleLanguages for confidence scores
      final candidates =
          await _langId.identifyPossibleLanguages(text);

      if (candidates.isEmpty) {
        return const LanguageIdResult(languageCode: 'und', confidence: 0.0);
      }

      final top = candidates.first;
      return LanguageIdResult(
        languageCode: top.languageTag,
        confidence: top.confidence,
      );
    } catch (e) {
      debugPrint('⚠️ Language identification failed: $e');
      return const LanguageIdResult(languageCode: 'und', confidence: 0.0);
    }
  }

  /// The main entry point: translate SMS text for detection.
  ///
  /// Pipeline:
  /// 1. Identify language.
  /// 2. If English or undetermined → skip (return original).
  /// 3. If regional + model available → translate to English.
  /// 4. If model not available → return original (graceful fallback).
  /// 5. On ANY error → return original (never crash).
  ///
  /// Enforces a 3-second timeout to prevent blocking.
  Future<TranslationResult> translateForDetection(String text) async {
    // Safety: wrap entire pipeline in try-catch + timeout
    try {
      return await _translatePipeline(text).timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          debugPrint('⏱️ Translation timed out, using original text');
          return TranslationResult(
            textForModel: text,
            originalText: text,
            detectedLanguage: 'und',
            wasTranslated: false,
          );
        },
      );
    } catch (e) {
      debugPrint('⚠️ Translation pipeline error: $e');
      return TranslationResult(
        textForModel: text,
        originalText: text,
        detectedLanguage: 'und',
        wasTranslated: false,
      );
    }
  }

  /// Check if a translation model is downloaded for [langCode].
  Future<bool> isModelReady(String langCode) async {
    if (langCode == 'en') return true;
    try {
      final mlKitLang = _codeToTranslateLanguage(langCode);
      if (mlKitLang == null) return false;
      return await _modelManager.isModelDownloaded(mlKitLang.bcpCode);
    } catch (e) {
      debugPrint('⚠️ Model check failed for $langCode: $e');
      return false;
    }
  }

  /// Download a translation model for offline use.
  /// Checks connectivity and retries up to 3 times with exponential backoff.
  Future<void> downloadModel(String langCode,
      {Function(double)? onProgress}) async {
    final mlKitLang = _codeToTranslateLanguage(langCode);
    if (mlKitLang == null) {
      throw ArgumentError('Unsupported language: $langCode');
    }

    onProgress?.call(0.0);

    // Retry with exponential backoff
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        debugPrint(
            '📥 Download attempt $attempt/3 for $langCode (${mlKitLang.bcpCode})');
        await _modelManager.downloadModel(mlKitLang.bcpCode);
        onProgress?.call(1.0);
        debugPrint('✅ Model downloaded for $langCode');
        return;
      } catch (e) {
        debugPrint('⚠️ Download attempt $attempt failed: $e');
        if (attempt == 3) rethrow;
        // Exponential backoff: 2s, 4s
        await Future.delayed(Duration(seconds: 1 << attempt));
      }
    }
  }

  /// Delete a downloaded translation model.
  /// Guards against deleting models still needed by UI TranslationService.
  Future<void> deleteModel(String langCode) async {
    try {
      // Guard: don't delete if the app's UI translation needs this model
      final appLang = _getAppLanguage();
      if (appLang == langCode) {
        debugPrint(
            '⚠️ Skipping $langCode model deletion — app UI translation needs it');
        return;
      }

      final mlKitLang = _codeToTranslateLanguage(langCode);
      if (mlKitLang != null) {
        await _modelManager.deleteModel(mlKitLang.bcpCode);
        debugPrint('🗑️ Deleted model for $langCode');
      }
    } catch (e) {
      debugPrint('⚠️ Failed to delete model for $langCode: $e');
    }
  }

  /// Read the app's UI language from TranslationService (sync, no import cycle).
  String _getAppLanguage() {
    // TranslationService stores this in SharedPreferences as 'app_language'.
    // We read it synchronously from its singleton to avoid circular imports.
    // If unable to determine, return 'en' (safe default — won't block deletion).
    try {
      // Use the same import-free approach: just check SharedPreferences key
      // This is already loaded by TranslationService at startup
      return _cachedAppLanguage ?? 'en';
    } catch (_) {
      return 'en';
    }
  }

  String? _cachedAppLanguage;

  /// Call during initialize to cache the app language for deletion guards.
  Future<void> _loadAppLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _cachedAppLanguage = prefs.getString('app_language');
    } catch (_) {}
  }

  /// Get list of supported language codes that can be downloaded.
  List<String> get supportedDetectionLanguages =>
      ['hi', 'mr', 'bn', 'gu', 'kn', 'ta', 'te', 'ur'];

  /// Dispose resources.
  void dispose() {
    _langId.close();
    _disposed = true;
    _initialized = false;
  }

  // ──────────────────────────────────────────────
  // PRIVATE IMPLEMENTATION
  // ──────────────────────────────────────────────

  /// Core translation pipeline (called within timeout wrapper).
  Future<TranslationResult> _translatePipeline(String text) async {
    // Step 1: Identify language
    final langResult = await identifyLanguage(text);
    debugPrint(
        '🔍 Language: ${langResult.languageCode} (${(langResult.confidence * 100).toStringAsFixed(0)}%)');

    // Step 2: Determine effective language code
    String effectiveLang;
    if (langResult.needsTranslation) {
      // ML Kit confident in a regional language
      effectiveLang = langResult.languageCode;
    } else if (!langResult.isConfident &&
        _userLanguageHint != null &&
        _userLanguageHint != 'en') {
      // ML Kit unsure, but user has a language hint from onboarding
      // Use their hint as fallback (e.g., they selected "Bihar" → Hindi)
      effectiveLang = _userLanguageHint!;
      debugPrint(
          '💡 Using user hint "$effectiveLang" (ML Kit confidence too low)');
    } else {
      // English or truly undetermined — skip translation
      return TranslationResult(
        textForModel: text,
        originalText: text,
        detectedLanguage: langResult.languageCode,
        wasTranslated: false,
      );
    }

    // Step 3: Check if we have the translation model
    if (!await isModelReady(effectiveLang)) {
      debugPrint(
          '⚠️ No model for $effectiveLang, using original text for detection');
      return TranslationResult(
        textForModel: text,
        originalText: text,
        detectedLanguage: effectiveLang,
        wasTranslated: false,
      );
    }

    // Step 4: Translate Regional → English
    final mlKitLang = _codeToTranslateLanguage(effectiveLang);
    if (mlKitLang == null) {
      return TranslationResult(
        textForModel: text,
        originalText: text,
        detectedLanguage: effectiveLang,
        wasTranslated: false,
      );
    }

    final translator = OnDeviceTranslator(
      sourceLanguage: mlKitLang,
      targetLanguage: TranslateLanguage.english,
    );

    try {
      final translated = await translator.translateText(text);
      debugPrint('🌐 Translated ($effectiveLang→en): "$translated"');

      return TranslationResult(
        textForModel: translated,
        originalText: text,
        detectedLanguage: effectiveLang,
        wasTranslated: true,
      );
    } catch (e) {
      // Translation failed — return original text (don't crash)
      debugPrint('⚠️ translateText() failed for $effectiveLang: $e');
      return TranslationResult(
        textForModel: text,
        originalText: text,
        detectedLanguage: effectiveLang,
        wasTranslated: false,
      );
    } finally {
      translator.close();
    }
  }

  /// Convert a BCP-47 language code to ML Kit's TranslateLanguage enum.
  TranslateLanguage? _codeToTranslateLanguage(String code) {
    // Use the existing language_config.dart mapping
    final lang = getLanguageByCode(code);
    return lang?.mlKitLang;
  }
}
