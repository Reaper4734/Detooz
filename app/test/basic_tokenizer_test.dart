/// Enhanced BasicTokenizer Unit Tests
///
/// Tests the BasicTokenizer (pre-tokenization step for MobileBERT) with
/// comprehensive edge cases including Unicode, numbers, special characters,
/// and real-world scam message patterns.
///
/// Run with: flutter test test/basic_tokenizer_test.dart
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/ml/basic_tokenizer.dart';

void main() {
  group('BasicTokenizer — Core Behavior', () {
    test('lowercases text', () {
      expect(BasicTokenizer.tokenize('HELLO'), ['hello']);
      expect(BasicTokenizer.tokenize('Hello World'), ['hello', 'world']);
      expect(BasicTokenizer.tokenize('MiXeD CaSe'), ['mixed', 'case']);
    });

    test('splits on whitespace', () {
      expect(BasicTokenizer.tokenize('a b c'), ['a', 'b', 'c']);
    });

    test('splits punctuation into separate tokens', () {
      expect(BasicTokenizer.tokenize('Hello, world!'), ['hello', ',', 'world', '!']);
    });

    test('handles punctuation adjacent to text', () {
      expect(BasicTokenizer.tokenize('Pay Rs.5000'), ['pay', 'rs', '.', '5000']);
    });

    test('handles contractions', () {
      expect(BasicTokenizer.tokenize("don't"), ['don', "'", 't']);
    });

    test('handles multiple punctuation', () {
      expect(BasicTokenizer.tokenize('...!!!'), ['.', '.', '.', '!', '!', '!']);
    });
  });

  group('BasicTokenizer — Whitespace Handling', () {
    test('normalizes leading/trailing whitespace', () {
      expect(BasicTokenizer.tokenize('  hello  '), ['hello']);
    });

    test('normalizes newlines and tabs', () {
      expect(BasicTokenizer.tokenize('hello\nworld'), ['hello', 'world']);
      expect(BasicTokenizer.tokenize('hello\tworld'), ['hello', 'world']);
    });

    test('handles empty string', () {
      expect(BasicTokenizer.tokenize(''), []);
    });

    test('handles whitespace-only string', () {
      expect(BasicTokenizer.tokenize('   '), []);
    });

    test('handles multiple spaces between words', () {
      expect(BasicTokenizer.tokenize('hello    world'), ['hello', 'world']);
    });
  });

  group('BasicTokenizer — Accent Stripping', () {
    test('strips accents (café → cafe)', () {
      expect(BasicTokenizer.tokenize('café'), ['cafe']);
    });

    test('strips accents (naïve → naive)', () {
      expect(BasicTokenizer.tokenize('naïve'), ['naive']);
    });

    test('strips accents (résumé → resume)', () {
      expect(BasicTokenizer.tokenize('résumé'), ['resume']);
    });
  });

  group('BasicTokenizer — Numbers', () {
    test('keeps numbers as tokens', () {
      expect(BasicTokenizer.tokenize('123456'), ['123456']);
    });

    test('separates numbers from text with punctuation', () {
      expect(BasicTokenizer.tokenize('Rs.5000'), ['rs', '.', '5000']);
    });

    test('handles phone numbers', () {
      final result = BasicTokenizer.tokenize('+919876543210');
      expect(result.contains('919876543210'), true);
    });
  });

  group('BasicTokenizer — Real Scam Message Patterns', () {
    test('tokenizes typical lottery scam', () {
      final result = BasicTokenizer.tokenize('You won Rs.50000! Click http://bit.ly/claim');
      expect(result.contains('you'), true);
      expect(result.contains('won'), true);
      expect(result.contains('50000'), true);
      expect(result.contains('click'), true);
    });

    test('tokenizes UPI scam', () {
      final result = BasicTokenizer.tokenize('URGENT: Your UPI account is blocked. Verify now!');
      expect(result.contains('urgent'), true);
      expect(result.contains('upi'), true);
      expect(result.contains('blocked'), true);
      expect(result.contains('verify'), true);
    });

    test('tokenizes OTP message', () {
      final result = BasicTokenizer.tokenize('Your OTP is 432198. Valid for 5 mins.');
      expect(result.contains('otp'), true);
      expect(result.contains('432198'), true);
      expect(result.contains('valid'), true);
    });

    test('tokenizes safe message', () {
      final result = BasicTokenizer.tokenize('Hey, are we meeting for lunch today?');
      expect(result.contains('hey'), true);
      expect(result.contains('meeting'), true);
      expect(result.contains('lunch'), true);
    });
  });

  group('BasicTokenizer — Edge Cases', () {
    test('handles single character', () {
      expect(BasicTokenizer.tokenize('a'), ['a']);
    });

    test('handles single punctuation', () {
      expect(BasicTokenizer.tokenize('!'), ['!']);
    });

    test('handles URLs mostly intact', () {
      final result = BasicTokenizer.tokenize('http://example.com');
      // Should be split by punctuation
      expect(result.isNotEmpty, true);
    });

    test('handles very long text', () {
      final longText = 'word ' * 500;
      final result = BasicTokenizer.tokenize(longText);
      expect(result.length, 500);
      expect(result.every((t) => t == 'word'), true);
    });
  });
}
