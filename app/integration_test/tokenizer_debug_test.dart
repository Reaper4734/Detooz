/// Tokenizer Debug Test
/// 
/// This test compares Dart tokenizer output to Python reference values
/// to identify discrepancies.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:app/services/ml/vocab_loader.dart';
import 'package:app/services/ml/basic_tokenizer.dart';
import 'package:app/services/ml/wordpiece_tokenizer.dart';
import 'package:app/services/ml/token_encoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tokenizer Debug', () {
    setUpAll(() async {
      await VocabLoader.load();
      print('Vocab loaded: ${VocabLoader.vocabSize} tokens');
    });

    test('compare to Python reference', () {
      final encoder = TokenEncoder();
      
      // Test case from Python: "Your OTP is 123456. Do not share with anyone."
      // Python output: [101, 2115, 27178, 2361, 2003, 13138, 19961, 2575, 1012, 2079, ...]
      const testText = 'Your OTP is 123456. Do not share with anyone.';
      
      // Step 1: Basic tokenization
      final basicTokens = BasicTokenizer.tokenize(testText);
      print('Basic tokens: $basicTokens');
      // Expected (from Python): ['your', 'ot', '##p', 'is', '123', '##45', '##6', '.', 'do', 'not', 'share', 'with', 'anyone', '.']
      
      // Step 2: WordPiece tokenization
      final wordPiece = WordPieceTokenizer();
      final wpTokens = wordPiece.tokenize(basicTokens);
      print('WordPiece tokens: $wpTokens');
      
      // Step 3: Full encoding
      final encoded = encoder.encode(testText);
      final ids = encoded['input_ids']!;
      print('IDs (first 15): ${ids.sublist(0, 15)}');
      
      // Python reference (first 15):
      // [101, 2115, 27178, 2361, 2003, 13138, 19961, 2575, 1012, 2079, 2025, 3745, 2007, 3087, 1012]
      final pythonRef = [101, 2115, 27178, 2361, 2003, 13138, 19961, 2575, 1012, 2079, 2025, 3745, 2007, 3087, 1012];
      print('Python ref:      $pythonRef');
      
      // Check specific token lookups
      print('\nToken lookups:');
      print('  "your" -> ${VocabLoader.getId("your")} (expected: 2115)');
      print('  "otp" -> ${VocabLoader.getId("otp")} (expected: ?)');
      print('  "ot" -> ${VocabLoader.getId("ot")} (expected: 27178)');
      print('  "##p" -> ${VocabLoader.getId("##p")} (expected: 2361)');
      print('  "123" -> ${VocabLoader.getId("123")} (expected: 13138)');
      print('  "##45" -> ${VocabLoader.getId("##45")} (expected: 19961)');
      print('  "##6" -> ${VocabLoader.getId("##6")} (expected: 2575)');
      
      // Compare
      bool match = true;
      for (int i = 0; i < pythonRef.length && i < ids.length; i++) {
        if (ids[i] != pythonRef[i]) {
          print('MISMATCH at position $i: Dart=${ids[i]}, Python=${pythonRef[i]}');
          match = false;
        }
      }
      
      if (match) {
        print('\n✅ All tokens match Python reference!');
      } else {
        print('\n❌ Token mismatch detected');
      }
    });
  });
}
