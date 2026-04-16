import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_translation/google_mlkit_translation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'language_config.dart';
import '../ml/sms_translator.dart';

/// Singleton service for handling all translations
/// Implements Single-Model Policy: Only one language model stored at a time
class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  factory TranslationService() => _instance;
  TranslationService._internal();

  final _modelManager = OnDeviceTranslatorModelManager();
  OnDeviceTranslator? _translator;
  String _currentLang = 'en';
  Box<String>? _cache;
  bool _initialized = false;

  /// Current language code
  String get currentLanguage => _currentLang;

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Initialize the translation service
  /// Call this once at app startup
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      // Initialize Hive for caching (may already be initialized)
      if (!Hive.isBoxOpen('translations')) {
        _cache = await Hive.openBox<String>('translations');
      } else {
        _cache = Hive.box<String>('translations');
      }

      // Load saved language preference
      _currentLang = await _loadSavedLanguage();

      // If not English, initialize translator
      if (_currentLang != 'en') {
        try {
          await _initTranslator(_currentLang);
        } catch (e) {
          // Model not downloaded, fall back to English
          debugPrint('⚠️ Language model not found, falling back to English');
          _currentLang = 'en';
          await _saveLanguage('en');
        }
      }

      _initialized = true;
      debugPrint('✅ TranslationService initialized with language: $_currentLang');
    } catch (e) {
      debugPrint('❌ TranslationService initialization failed: $e');
      _initialized = true; // Mark as initialized anyway to prevent blocking
    }
  }

  /// Sets language and implements SINGLE-MODEL POLICY
  /// - Downloads new model if needed
  /// - Deletes previous model to save storage
  /// - Clears old translation cache
  Future<void> setLanguage(String langCode) async {
    if (langCode == _currentLang) return;

    final oldLang = _currentLang;
    _currentLang = langCode;
    await _saveLanguage(langCode);

    if (langCode == 'en') {
      // Switching to English - no model needed
      _translator?.close();
      _translator = null;

      // Delete previous model to free storage (single-model policy)
      if (oldLang != 'en') {
        await _deleteModelAndCache(oldLang);
      }
    } else {
      // Switching to non-English language
      await _initTranslator(langCode);

      // Delete previous model (single-model policy)
      if (oldLang != 'en') {
        await _deleteModelAndCache(oldLang);
      }
    }

    debugPrint('🌐 Language changed: $oldLang → $langCode');
  }

  /// Generate a Hive-safe cache key (max 255 chars)
  /// Hashes long strings to avoid HiveError
  String _cacheKey(String text) {
    final prefix = '${_currentLang}_';
    if (prefix.length + text.length <= 250) {
      return '$prefix$text';
    }
    // Hash long keys using MD5 for speed (not security-critical)
    final hash = md5.convert(utf8.encode(text)).toString();
    return '${prefix}hash_$hash';
  }

  /// Translate a string to the current language
  /// Returns the original string if:
  /// - Current language is English
  /// - Translation fails
  /// - Cache contains the translation (fast path)
  Future<String> translate(String text) async {
    // English = no translation needed
    if (_currentLang == 'en' || _translator == null) return text;

    // Check cache first (instant)
    final key = _cacheKey(text);
    final cached = _cache?.get(key);
    if (cached != null) return cached;

    // Translate and cache
    try {
      final translated = await _translator!.translateText(text);
      await _cache?.put(key, translated);
      return translated;
    } catch (e) {
      debugPrint('⚠️ Translation error: $e');
      return text; // Fallback to English
    }
  }

  /// SYNC translation - returns cached value or original
  /// Use this for String parameters (e.g., BottomNavigationBarItem.label)
  /// that cannot use async FutureBuilder widgets.
  /// 
  /// NOTE: Returns original text if not cached. To ensure translation,
  /// pre-translate text using [preloadTranslations].
  String translateSync(String text) {
    if (_currentLang == 'en') return text;
    
    final key = _cacheKey(text);
    return _cache?.get(key) ?? text;
  }

  /// Pre-load translations into cache for synchronous access
  /// Call this on widget init for nav labels, button text, etc.
  Future<void> preloadTranslations(List<String> texts) async {
    await translateBatch(texts);
  }

  Future<List<String>> translateBatch(List<String> texts) async {
    final results = <String>[];
    for (final text in texts) {
      results.add(await translate(text));
    }
    return results;
  }

  /// Check if a language model is downloaded
  Future<bool> isModelDownloaded(String langCode) async {
    if (langCode == 'en') return true; // English needs no model
    final lang = getLanguageByCode(langCode);
    if (lang?.mlKitLang == null) return false;
    return _modelManager.isModelDownloaded(lang!.mlKitLang!.bcpCode);
  }

  /// Download a language model
  /// onProgress callback provides 0.0 to 1.0 progress (simulated)
  Future<void> downloadModel(String langCode,
      {bool allowCellular = false, Function(double)? onProgress}) async {
    debugPrint('📥 downloadModel called for: $langCode (Cellular: $allowCellular)');

    final lang = getLanguageByCode(langCode);
    if (lang?.mlKitLang == null) {
      debugPrint('❌ Language "$langCode" not supported');
      throw UnsupportedLanguageException(langCode);
    }

    final bcpCode = lang!.mlKitLang!.bcpCode;
    debugPrint('📥 ML Kit BCP code: $bcpCode');

    onProgress?.call(0.0);

    debugPrint('📥 Starting model download for BCP code: $bcpCode');

    // Use the simple, reliable ML Kit download — no timeout, no polling.
    // ML Kit manages its own download lifecycle internally.
    // Passing isWifiRequired: false always to avoid Android connectivity
    // detection issues. The UI already handles WiFi/mobile data confirmation.
    await _modelManager.downloadModel(bcpCode, isWifiRequired: false);
    debugPrint('✅ Model download completed for: $langCode');

    onProgress?.call(1.0);
  }

  /// Get current storage usage info
  Future<String> getStorageInfo() async {
    final downloaded = <String>[];
    for (final lang in supportedLanguages) {
      if (!lang.isEnglish && await isModelDownloaded(lang.code)) {
        downloaded.add(lang.englishName);
      }
    }
    if (downloaded.isEmpty) return 'No language models downloaded';
    return 'Downloaded: ${downloaded.join(", ")} (~30MB each)';
  }

  /// Get list of downloaded languages
  Future<List<String>> getDownloadedLanguages() async {
    final downloaded = <String>[];
    for (final lang in supportedLanguages) {
      if (!lang.isEnglish && await isModelDownloaded(lang.code)) {
        downloaded.add(lang.code);
      }
    }
    return downloaded;
  }

  /// Delete a specific language model and its cached translations.
  /// Exposed for UI screens that allow users to manage downloaded packs.
  Future<void> deleteModel(String langCode) async {
    await _deleteModelAndCache(langCode);
  }

  // Private methods

  Future<void> _initTranslator(String langCode) async {
    _translator?.close();

    final lang = getLanguageByCode(langCode);
    if (lang?.mlKitLang == null) return;

    // Check if model downloaded
    if (!await _modelManager.isModelDownloaded(lang!.mlKitLang!.bcpCode)) {
      throw ModelNotDownloadedException(langCode);
    }

    _translator = OnDeviceTranslator(
      sourceLanguage: TranslateLanguage.english,
      targetLanguage: lang.mlKitLang!,
    );
  }

  /// Deletes a language model and clears its cached translations.
  /// Guards against deleting models still needed by SmsTranslator (detection).
  Future<void> _deleteModelAndCache(String langCode) async {
    try {
      // Guard: don't delete if SMS detection still needs this model.
      // Check both the SmsTranslator instance AND SharedPreferences directly
      // (in case SmsTranslator hasn't been initialized yet).
      final smsLang = SmsTranslator().userLanguageHint;
      String? detectionLang = smsLang;
      
      if (detectionLang == null) {
        // Fallback: read directly from SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        detectionLang = prefs.getString('detection_language');
        debugPrint('🔍 Checked prefs for detection_language: "$detectionLang"');
      } else {
        debugPrint('🔍 SmsTranslator instance has detection_language: "$detectionLang"');
      }

      debugPrint('🤔 Checking deletion guard: Trying to delete "$langCode", needed for detection? "${detectionLang == langCode}"');

      if (detectionLang == langCode) {
        debugPrint(
            '⚠️ GUARD: Skipping $langCode model deletion — SMS detection needs it');
        // Still clear UI translation cache (no longer needed for UI)
        _clearCacheForLanguage(langCode);
        return;
      }

      // Delete the ML model
      final lang = getLanguageByCode(langCode);
      if (lang?.mlKitLang != null) {
        await _modelManager.deleteModel(lang!.mlKitLang!.bcpCode);
        debugPrint('🗑️ Deleted $langCode model to save storage');
      }

      // Clear cached translations for this language
      _clearCacheForLanguage(langCode);
    } catch (e) {
      debugPrint('⚠️ Failed to cleanup $langCode: $e');
    }
  }

  /// Clears cached translations for a specific language.
  void _clearCacheForLanguage(String langCode) {
    if (_cache != null) {
      final keysToDelete = _cache!.keys
          .where((k) => k.toString().startsWith('${langCode}_'))
          .toList();
      for (final key in keysToDelete) {
        _cache!.delete(key);
      }
      debugPrint('🗑️ Cleared ${keysToDelete.length} cached translations for $langCode');
    }
  }

  Future<String> _loadSavedLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('app_language') ?? 'en';
    } catch (e) {
      return 'en';
    }
  }

  Future<void> _saveLanguage(String code) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('app_language', code);
    } catch (e) {
      debugPrint('⚠️ Failed to save language preference: $e');
    }
  }
}

// Custom exceptions

class ModelNotDownloadedException implements Exception {
  final String langCode;
  ModelNotDownloadedException(this.langCode);

  @override
  String toString() => 'Model for $langCode not downloaded';
}

class UnsupportedLanguageException implements Exception {
  final String langCode;
  UnsupportedLanguageException(this.langCode);

  @override
  String toString() => 'Language $langCode is not supported';
}
