/// TokenEncoder - Complete tokenization pipeline for MobileBERT
///
/// This class combines all tokenization steps to produce model-ready inputs:
/// 1. BasicTokenizer: Lowercase, accent removal, punctuation splitting
/// 2. WordPieceTokenizer: Subword tokenization
/// 3. Token-to-ID mapping using VocabLoader
/// 4. Special token insertion ([CLS], [SEP])
/// 5. Padding/truncation to fixed length
/// 6. Attention mask generation
///
/// Example:
/// ```dart
/// final encoder = TokenEncoder();
/// await VocabLoader.load(); // Must load vocab first
///
/// final result = encoder.encode("Hello, world!");
/// print(result['input_ids']);      // [101, 7592, 1010, 2088, 999, 102, 0, 0, ...]
/// print(result['attention_mask']); // [1, 1, 1, 1, 1, 1, 0, 0, ...]
/// ```
library;

import 'basic_tokenizer.dart';
import 'wordpiece_tokenizer.dart';
import 'vocab_loader.dart';

/// Encodes text into model-ready token IDs and attention masks.
class TokenEncoder {
  /// Maximum sequence length (must match TFLite model input shape)
  /// TFLite model was exported with max_length=128
  static const int maxSeqLength = 128;

  /// Special token IDs (from VocabLoader)
  static const int clsId = 101;  // [CLS] - Classification token
  static const int sepId = 102;  // [SEP] - Separator token
  static const int padId = 0;    // [PAD] - Padding token

  /// WordPiece tokenizer instance
  final WordPieceTokenizer _wordPiece;

  /// Creates a TokenEncoder with default WordPiece settings.
  TokenEncoder() : _wordPiece = WordPieceTokenizer();

  /// Encodes text into model-ready inputs.
  ///
  /// Returns a map with:
  /// - `input_ids`: List<int> of token IDs, length = [maxSeqLength]
  /// - `attention_mask`: List<int> of 1s (real tokens) and 0s (padding)
  ///
  /// Processing pipeline:
  /// 1. BasicTokenizer: Preprocess text (lowercase, accents, punctuation)
  /// 2. WordPieceTokenizer: Split into subword tokens
  /// 3. Convert tokens to IDs
  /// 4. Truncate if necessary (keeping room for [CLS] and [SEP])
  /// 5. Add [CLS] at start and [SEP] at end
  /// 6. Pad to [maxSeqLength]
  /// 7. Generate attention mask
  ///
  /// Example:
  /// ```dart
  /// encode("Hello!") → {
  ///   'input_ids': [101, 7592, 999, 102, 0, 0, ...], // 192 elements
  ///   'attention_mask': [1, 1, 1, 1, 0, 0, ...]      // 192 elements
  /// }
  /// ```
  Map<String, List<int>> encode(String text) {
    // Step 1: Basic tokenization (lowercase, accent removal, punctuation split)
    final words = BasicTokenizer.tokenize(text);

    // Step 2: WordPiece subword tokenization
    final tokens = _wordPiece.tokenize(words);

    // Step 3: Convert tokens to IDs
    List<int> ids = tokens.map((t) => VocabLoader.getId(t)).toList();

    // Step 4: Truncate if needed (leave room for [CLS] and [SEP])
    final maxTokens = maxSeqLength - 2; // Reserve 2 for special tokens
    if (ids.length > maxTokens) {
      ids = ids.sublist(0, maxTokens);
    }

    // Step 5: Add special tokens
    // Format: [CLS] token1 token2 ... tokenN [SEP] [PAD] [PAD] ...
    ids = [clsId, ...ids, sepId];

    // Track real sequence length before padding
    final realLength = ids.length;

    // Step 6: Pad to maxSeqLength
    while (ids.length < maxSeqLength) {
      ids.add(padId);
    }

    // Step 7: Create attention mask
    // 1 for real tokens, 0 for padding
    final attentionMask = List<int>.generate(
      maxSeqLength,
      (i) => i < realLength ? 1 : 0,
    );

    return {
      'input_ids': ids,
      'attention_mask': attentionMask,
    };
  }

  /// Returns the tokens (strings) for debugging/visualization.
  ///
  /// This is useful for understanding how text is being tokenized.
  List<String> getTokens(String text) {
    final words = BasicTokenizer.tokenize(text);
    final tokens = _wordPiece.tokenize(words);
    return ['[CLS]', ...tokens, '[SEP]'];
  }
}
