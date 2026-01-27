/// BasicTokenizer - Pre-processes text before WordPiece tokenization
///
/// This class replicates the behavior of HuggingFace's BasicTokenizer,
/// specifically the preprocessing done by MobileBertTokenizerFast.
///
/// Key responsibilities:
/// 1. Convert text to lowercase
/// 2. Strip accents (Unicode NFD normalization)
/// 3. Split punctuation as separate tokens
/// 4. Normalize whitespace
///
/// Example:
/// ```dart
/// BasicTokenizer.tokenize("Hello, World!")
/// // Returns: ['hello', ',', 'world', '!']
///
/// BasicTokenizer.tokenize("Pay Rs.5000")
/// // Returns: ['pay', 'rs', '.', '5000']
///
/// BasicTokenizer.tokenize("café")
/// // Returns: ['cafe']
/// ```
library;

import 'package:diacritic/diacritic.dart';

/// Tokenizes text into words with proper handling of punctuation and accents.
///
/// This matches the behavior of Python's MobileBertTokenizerFast preprocessing.
class BasicTokenizer {
  // Punctuation characters to split on (matches Python's string.punctuation)
  // !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~
  static final RegExp _punctuation = RegExp(
    r'[!"#\$%&' "'" r'\(\)\*\+,\-\./:;<=>\?@\[\\\]\^_`\{\|\}~]',
  );

  /// Tokenizes text into a list of words/tokens.
  ///
  /// Processing steps:
  /// 1. Lowercase the text
  /// 2. Strip accents using Unicode NFD normalization
  /// 3. Add spaces around each punctuation character
  /// 4. Normalize all whitespace to single spaces
  /// 5. Split on whitespace and filter empty strings
  ///
  /// Returns an empty list for empty input.
  static List<String> tokenize(String text) {
    if (text.isEmpty) return [];

    // Step 1: Lowercase
    text = text.toLowerCase();

    // Step 2: Strip accents using proper Unicode NFD normalization
    // 'café' → 'cafe', 'naïve' → 'naive', 'résumé' → 'resume'
    text = removeDiacritics(text);

    // Step 3: Add spaces around EACH punctuation character
    // This ensures punctuation becomes separate tokens
    // 'Rs.5000' → 'Rs . 5000'
    // "don't" → "don ' t"
    text = text.replaceAllMapped(_punctuation, (match) => ' ${match.group(0)} ');

    // Step 4: Normalize all whitespace (including newlines, tabs) to single spaces
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Step 5: Split on whitespace and filter empty strings
    if (text.isEmpty) return [];
    return text.split(' ').where((t) => t.isNotEmpty).toList();
  }
}
