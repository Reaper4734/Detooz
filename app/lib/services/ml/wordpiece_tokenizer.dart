/// WordPieceTokenizer - Subword tokenization using WordPiece algorithm
///
/// This class implements the WordPiece tokenization algorithm used by BERT
/// and MobileBERT models. It splits words into subword tokens based on a
/// learned vocabulary.
///
/// Algorithm (Greedy Longest-Match-First):
/// 1. For each word, try to find the longest prefix that exists in vocab
/// 2. If found, add it to tokens, remove from word
/// 3. For remaining characters, prepend "##" and repeat
/// 4. If no match found at any point, the entire word becomes [UNK]
///
/// Example:
/// ```dart
/// tokenizer.tokenize(['playing'])
/// // Vocab has: 'play', '##ing'
/// // Returns: ['play', '##ing']
///
/// tokenizer.tokenize(['123456'])
/// // Vocab has: '123', '##45', '##6'
/// // Returns: ['123', '##45', '##6']
///
/// tokenizer.tokenize(['xyz'])
/// // 'xyz' not in vocab
/// // Returns: ['[UNK]']
/// ```
library;

import 'vocab_loader.dart';

/// Tokenizes words into subword tokens using the WordPiece algorithm.
class WordPieceTokenizer {
  /// Maximum number of characters per word before treating as [UNK]
  final int maxInputCharsPerWord;

  /// Creates a WordPieceTokenizer.
  ///
  /// [maxInputCharsPerWord] limits word length to prevent excessive processing.
  /// Words longer than this are replaced with [UNK].
  WordPieceTokenizer({this.maxInputCharsPerWord = 100});

  /// Tokenizes a list of words into subword tokens.
  ///
  /// Each word is split into subword tokens using the WordPiece algorithm.
  /// Words that cannot be tokenized (not in vocab) become [UNK].
  ///
  /// [words] should come from [BasicTokenizer.tokenize].
  ///
  /// Returns a list of token strings (including ## prefixes for continuations).
  List<String> tokenize(List<String> words) {
    final List<String> outputTokens = [];

    for (final word in words) {
      // Skip empty words
      if (word.isEmpty) continue;

      // Words that are too long become [UNK]
      if (word.length > maxInputCharsPerWord) {
        outputTokens.add('[UNK]');
        continue;
      }

      // Try to tokenize the word using greedy longest-match
      final subTokens = _tokenizeWord(word);
      
      if (subTokens == null) {
        // Word could not be tokenized - use [UNK]
        outputTokens.add('[UNK]');
      } else {
        outputTokens.addAll(subTokens);
      }
    }

    return outputTokens;
  }

  /// Tokenizes a single word into subword tokens.
  ///
  /// Returns null if the word cannot be tokenized (contains OOV characters).
  List<String>? _tokenizeWord(String word) {
    final List<String> subTokens = [];
    int start = 0;

    while (start < word.length) {
      int end = word.length;
      String? foundToken;

      // Greedy search: try longest substring first, then shorter
      while (start < end) {
        String substr = word.substring(start, end);
        
        // Add ## prefix for continuation tokens (not first token)
        if (start > 0) {
          substr = '##$substr';
        }

        if (VocabLoader.contains(substr)) {
          foundToken = substr;
          break;
        }
        
        // Try shorter substring
        end--;
      }

      // If no token found, the word is un-tokenizable
      if (foundToken == null) {
        return null;
      }

      subTokens.add(foundToken);
      start = end;
    }

    return subTokens;
  }
}
