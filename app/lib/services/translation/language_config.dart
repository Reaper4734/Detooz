import 'package:google_mlkit_translation/google_mlkit_translation.dart';

/// Supported language configuration for the app
class SupportedLanguage {
  final String code;
  final String englishName;
  final String nativeName;
  final TranslateLanguage? mlKitLang; // null for English (source language)

  const SupportedLanguage({
    required this.code,
    required this.englishName,
    required this.nativeName,
    this.mlKitLang,
  });

  bool get isEnglish => code == 'en';
}

/// All supported languages with ML Kit support
/// ML Kit supports 8 major Indian languages:
/// Hindi, Bengali, Telugu, Marathi, Tamil, Gujarati, Kannada, Urdu
/// Note: Malayalam and Punjabi are NOT supported by ML Kit
const List<SupportedLanguage> supportedLanguages = [
  SupportedLanguage(
    code: 'en',
    englishName: 'English',
    nativeName: 'English',
    mlKitLang: null, // English is source, no model needed
  ),
  SupportedLanguage(
    code: 'hi',
    englishName: 'Hindi',
    nativeName: 'हिन्दी',
    mlKitLang: TranslateLanguage.hindi,
  ),
  SupportedLanguage(
    code: 'bn',
    englishName: 'Bengali',
    nativeName: 'বাংলা',
    mlKitLang: TranslateLanguage.bengali,
  ),
  SupportedLanguage(
    code: 'te',
    englishName: 'Telugu',
    nativeName: 'తెలుగు',
    mlKitLang: TranslateLanguage.telugu,
  ),
  SupportedLanguage(
    code: 'mr',
    englishName: 'Marathi',
    nativeName: 'मराठी',
    mlKitLang: TranslateLanguage.marathi,
  ),
  SupportedLanguage(
    code: 'ta',
    englishName: 'Tamil',
    nativeName: 'தமிழ்',
    mlKitLang: TranslateLanguage.tamil,
  ),
  SupportedLanguage(
    code: 'gu',
    englishName: 'Gujarati',
    nativeName: 'ગુજરાતી',
    mlKitLang: TranslateLanguage.gujarati,
  ),
  SupportedLanguage(
    code: 'kn',
    englishName: 'Kannada',
    nativeName: 'ಕನ್ನಡ',
    mlKitLang: TranslateLanguage.kannada,
  ),
  SupportedLanguage(
    code: 'ur',
    englishName: 'Urdu',
    nativeName: 'اردو',
    mlKitLang: TranslateLanguage.urdu,
  ),
];

/// Get a supported language by code
SupportedLanguage? getLanguageByCode(String code) {
  try {
    return supportedLanguages.firstWhere((l) => l.code == code);
  } catch (_) {
    return null;
  }
}
