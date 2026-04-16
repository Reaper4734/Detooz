/// Maps Indian States / UTs to their primary regional language code.
///
/// Used during onboarding to auto-select the appropriate
/// offline language pack for scam detection.
///
/// Only includes languages supported by Google ML Kit On-Device Translation.
/// Unsupported languages (Malayalam, Punjabi, Odia) fall back to Hindi or English.
library;

/// Map of state/UT names to ML Kit language codes.
///
/// Language codes follow BCP-47: hi, mr, bn, gu, kn, ta, te, ur.
/// 'en' means no translation model needed (English-only detection).
/// 'hi' is used as fallback for unsupported regional languages.
const Map<String, String> stateToLanguage = {
  // Hindi-speaking states
  'Uttar Pradesh': 'hi',
  'Bihar': 'hi',
  'Madhya Pradesh': 'hi',
  'Rajasthan': 'hi',
  'Delhi': 'hi',
  'Haryana': 'hi',
  'Jharkhand': 'hi',
  'Chhattisgarh': 'hi',
  'Himachal Pradesh': 'hi',
  'Uttarakhand': 'hi',

  // Regional language states (ML Kit supported)
  'Maharashtra': 'mr',
  'Gujarat': 'gu',
  'Karnataka': 'kn',
  'Tamil Nadu': 'ta',
  'Andhra Pradesh': 'te',
  'Telangana': 'te',
  'West Bengal': 'bn',
  'Tripura': 'bn',
  'Jammu & Kashmir': 'ur',

  // Unsupported languages → fallback
  'Kerala': 'en', // Malayalam not supported by ML Kit
  'Punjab': 'hi', // Punjabi not supported, Hindi fallback
  'Odisha': 'hi', // Odia not supported, Hindi fallback

  // Remaining states/UTs → English default
  'Goa': 'en',
  'Assam': 'en',
  'Meghalaya': 'en',
  'Manipur': 'en',
  'Mizoram': 'en',
  'Nagaland': 'en',
  'Sikkim': 'en',
  'Arunachal Pradesh': 'en',

  // Union Territories
  'Chandigarh': 'hi',
  'Puducherry': 'ta',
  'Dadra & Nagar Haveli and Daman & Diu': 'gu',
  'Lakshadweep': 'en',  // Malayalam not supported
  'Andaman & Nicobar Islands': 'hi',
  'Ladakh': 'en',
};

/// Sorted list of all state names for dropdown UI.
List<String> get sortedStateNames {
  final names = stateToLanguage.keys.toList();
  names.sort();
  return names;
}

/// Get language code for a state. Returns 'en' if not found.
String languageForState(String state) {
  return stateToLanguage[state] ?? 'en';
}

/// Native script symbol for language badge display.
String languageNativeSymbol(String code) {
  return switch (code) {
    'hi' => 'हि',
    'mr' => 'म',
    'bn' => 'বা',
    'gu' => 'ગુ',
    'kn' => 'ಕ',
    'ta' => 'த',
    'te' => 'తె',
    'ur' => 'ا',
    'en' => 'E',
    _ => '?',
  };
}

/// Human-readable language name for display.
String languageDisplayName(String code) {
  return switch (code) {
    'hi' => 'Hindi',
    'mr' => 'Marathi',
    'bn' => 'Bengali',
    'gu' => 'Gujarati',
    'kn' => 'Kannada',
    'ta' => 'Tamil',
    'te' => 'Telugu',
    'ur' => 'Urdu',
    'en' => 'English',
    _ => 'Unknown',
  };
}
