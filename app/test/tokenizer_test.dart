/// Tokenizer Validation Tests
///
/// This file contains unit tests that validate the Dart tokenizer implementation
/// against the Python MobileBERT tokenizer reference output.
///
/// Run with: flutter test test/tokenizer_test.dart
library;

import 'package:flutter_test/flutter_test.dart';

// Import the tokenizer components
import 'package:app/services/ml/basic_tokenizer.dart';
import 'package:app/services/ml/wordpiece_tokenizer.dart';
import 'package:app/services/ml/token_encoder.dart';

/// Reference test cases from Python tokenizer
/// Format: {'text': input, 'expected_ids': [CLS, token_ids..., SEP]}
final testCases = [
  {
    'text': 'hello world',
    'expected_ids': [101, 7592, 2088, 102],
  },
  {
    'text': 'Hello, world!',
    'expected_ids': [101, 7592, 1010, 2088, 999, 102],
  },
  {
    'text': 'Pay Rs.5000',
    'expected_ids': [101, 3477, 12667, 1012, 13509, 102],
  },
  {
    'text': '123456',
    'expected_ids': [101, 13138, 19961, 2575, 102],
  },
  {
    'text': 'cafe',
    'expected_ids': [101, 7668, 102],
  },
];

void main() {
  group('BasicTokenizer', () {
    test('lowercases text', () {
      expect(BasicTokenizer.tokenize('HELLO'), ['hello']);
      expect(BasicTokenizer.tokenize('Hello World'), ['hello', 'world']);
    });

    test('splits punctuation', () {
      final result = BasicTokenizer.tokenize('Hello, world!');
      expect(result, ['hello', ',', 'world', '!']);
    });

    test('handles punctuation adjacent to text', () {
      final result = BasicTokenizer.tokenize('Pay Rs.5000');
      expect(result, ['pay', 'rs', '.', '5000']);
    });

    test('handles contractions', () {
      final result = BasicTokenizer.tokenize("don't");
      expect(result, ['don', "'", 't']);
    });

    test('handles multiple punctuation', () {
      final result = BasicTokenizer.tokenize('...!!!');
      expect(result, ['.', '.', '.', '!', '!', '!']);
    });

    test('normalizes whitespace', () {
      expect(BasicTokenizer.tokenize('  hello  '), ['hello']);
      expect(BasicTokenizer.tokenize('hello\nworld'), ['hello', 'world']);
    });

    test('handles empty string', () {
      expect(BasicTokenizer.tokenize(''), []);
    });

    test('strips accents', () {
      // Note: This requires the diacritic package to work correctly
      expect(BasicTokenizer.tokenize('café'), ['cafe']);
      expect(BasicTokenizer.tokenize('naïve'), ['naive']);
    });
  });

  group('WordPieceTokenizer', () {
    // Note: These tests require VocabLoader to be initialized
    // In a real test, you would mock or load the vocabulary

    test('tokenizes simple words', () {
      // This would require loading the vocabulary first
      // Placeholder for when vocab is available
    });

    test('handles unknown words', () {
      // Words not in vocabulary become [UNK]
    });

    test('handles very long words', () {
      final tokenizer = WordPieceTokenizer(maxInputCharsPerWord: 10);
      final result = tokenizer.tokenize(['verylongwordthatexceedslimit']);
      expect(result, ['[UNK]']);
    });
  });

  group('TokenEncoder', () {
    test('produces correct sequence length', () {
      final encoder = TokenEncoder();
      // Note: Requires vocab to be loaded
      // final result = encoder.encode('hello');
      // expect(result['input_ids']!.length, 192);
      // expect(result['attention_mask']!.length, 192);
    });

    test('adds CLS and SEP tokens', () {
      // Verify [CLS]=101 at start and [SEP]=102 at end
    });

    test('pads to max length', () {
      // Verify padding with 0s
    });

    test('creates correct attention mask', () {
      // Verify 1s for real tokens, 0s for padding
    });
  });

  // Integration test that would run with actual vocabulary
  group('Integration Tests (require vocab)', () {
    // These tests run the full pipeline and compare against Python reference
    
    test('matches Python tokenizer output', () {
      // To run this test:
      // 1. Load vocab from assets
      // 2. Run TokenEncoder.encode() 
      // 3. Compare against expected_ids from testCases
      
      for (final testCase in testCases) {
        final text = testCase['text'] as String;
        final expectedIds = testCase['expected_ids'] as List<int>;
        
        // TODO: After loading vocab:
        // final result = encoder.encode(text);
        // final actualCoreIds = result['input_ids']!
        //     .takeWhile((id) => id != 0 || result['input_ids']!.indexOf(102) >= result['input_ids']!.indexOf(id))
        //     .toList();
        // expect(actualCoreIds, expectedIds);
      }
    }, skip: 'Requires vocabulary to be loaded');
  });
}
