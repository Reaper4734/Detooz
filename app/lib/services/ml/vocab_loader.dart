/// VocabLoader - Loads and manages the WordPiece vocabulary
///
/// This class loads the vocabulary file (vocab.txt) used by the MobileBERT
/// tokenizer and provides O(1) lookup for token-to-ID mapping.
///
/// Usage:
/// ```dart
/// await VocabLoader.load();
/// int id = VocabLoader.getId('hello'); // Returns token ID
/// bool exists = VocabLoader.contains('##ing'); // Check if token exists
/// ```
///
/// The vocabulary file format is one token per line, where the line index
/// becomes the token ID (0-indexed).
library;

import 'package:flutter/services.dart' show rootBundle;

/// Singleton class for loading and querying the WordPiece vocabulary.
///
/// Must call [load] before using [getId] or [contains].
class VocabLoader {
  // Private vocabulary map: token string -> token ID
  static final Map<String, int> _vocab = {};
  
  // Track if vocabulary has been loaded
  static bool _loaded = false;

  /// Special token IDs (verified from Python tokenizer)
  static const int clsTokenId = 101;  // [CLS] - Start of sequence
  static const int sepTokenId = 102;  // [SEP] - End of sequence
  static const int padTokenId = 0;    // [PAD] - Padding
  static const int unkTokenId = 100;  // [UNK] - Unknown token

  /// Returns true if vocabulary has been loaded
  static bool get isLoaded => _loaded;

  /// Returns the total number of tokens in vocabulary
  static int get vocabSize => _vocab.length;

  /// Loads the vocabulary from assets/vocab.txt
  ///
  /// This method is idempotent - calling it multiple times has no effect
  /// after the first successful load.
  ///
  /// Throws [FlutterError] if the vocabulary file cannot be loaded.
  static Future<void> load() async {
    if (_loaded) return;

    try {
      final content = await rootBundle.loadString('assets/vocab.txt');
      final lines = content.split('\n');
      
      for (int i = 0; i < lines.length; i++) {
        final token = lines[i].trim();
        if (token.isNotEmpty) {
          _vocab[token] = i;
        }
      }
      
      _loaded = true;
      
      // Verify special tokens are present
      assert(_vocab.containsKey('[PAD]'), 'Vocabulary missing [PAD] token');
      assert(_vocab.containsKey('[UNK]'), 'Vocabulary missing [UNK] token');
      assert(_vocab.containsKey('[CLS]'), 'Vocabulary missing [CLS] token');
      assert(_vocab.containsKey('[SEP]'), 'Vocabulary missing [SEP] token');
      
    } catch (e) {
      throw Exception('Failed to load vocabulary: $e');
    }
  }

  /// Returns the token ID for the given token string.
  ///
  /// If the token is not found in the vocabulary, returns [unkTokenId] (100).
  ///
  /// Example:
  /// ```dart
  /// VocabLoader.getId('hello');  // Returns the ID for 'hello'
  /// VocabLoader.getId('xyz123'); // Returns 100 ([UNK])
  /// ```
  static int getId(String token) {
    assert(_loaded, 'VocabLoader.load() must be called before getId()');
    return _vocab[token] ?? unkTokenId;
  }

  /// Returns true if the token exists in the vocabulary.
  ///
  /// This is used by WordPieceTokenizer to check if a substring is a valid token.
  static bool contains(String token) {
    assert(_loaded, 'VocabLoader.load() must be called before contains()');
    return _vocab.containsKey(token);
  }

  /// Clears the loaded vocabulary. Primarily for testing purposes.
  static void reset() {
    _vocab.clear();
    _loaded = false;
  }
}
