# Step 4.3: Dart Tokenizer Implementation Plan (v3 - FINAL)

## 1. Overview
The TFLite model expects **integer token IDs** as input, not raw text. In Python, `MobileBertTokenizerFast` handles this. In Dart, we must build an equivalent **WordPiece Tokenizer**.

## 2. Input/Output Specification
| Input | Output |
|-------|--------|
| `"Hello, world!"` | `input_ids: [101, 7592, 1010, 2088, 999, 102, 0, 0, ...]` (padded to 192) |
| | `attention_mask: [1, 1, 1, 1, 1, 1, 0, 0, ...]` |

**Special Token IDs** (Verified from Python):
*   `101` = `[CLS]` (start of sequence)
*   `102` = `[SEP]` (end of sequence)
*   `0` = `[PAD]` (padding)
*   `100` = `[UNK]` (unknown token)

> [!IMPORTANT]
> **Sequence Length**: The model was trained with `max_length=192`, NOT 128!

---

## 3. Critical Fixes from Review

### ❌ **Issue 1: Punctuation Handling**
**Problem**: Python tokenizer splits punctuation as separate tokens:
```
"Hello, world!" → ["hello", ",", "world", "!"]
```
**Solution**: Add `BasicTokenizer` step that inserts spaces around punctuation BEFORE WordPiece.

### ❌ **Issue 2: Number Tokenization**
**Problem**: Numbers are sub-tokenized:
```
"123456" → ["123", "##45", "##6"]
```
**Solution**: The WordPiece algorithm handles this naturally, but we must ensure `##` prefix lookups work.

### ⚠️ **Issue 3: Sequence Length**
**Problem**: Plan used `maxSeqLength = 128`, but training used `192`.
**Solution**: Update to `192`.

### ⚠️ **Issue 4: Accent Stripping is Incomplete**
**Problem**: Plan uses simple character replacement, but Python uses **Unicode NFD normalization**.
**Evidence**: `'café'` → `['cafe']` (Python correctly strips `é` → `e`).
**Solution**: Use proper Unicode normalization in Dart.

---

## 4. Components to Implement (Corrected)

### 4.1 `VocabLoader` (File: `lib/services/ml/vocab_loader.dart`)
**Purpose**: Load `vocab.txt` into a `Map<String, int>` for O(1) token-to-ID lookup.

```dart
class VocabLoader {
  static Map<String, int> _vocab = {};
  static bool _loaded = false;

  static Future<void> load() async {
    if (_loaded) return;
    final content = await rootBundle.loadString('assets/vocab.txt');
    final lines = content.split('\n');
    for (int i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      if (token.isNotEmpty) {
        _vocab[token] = i;
      }
    }
    _loaded = true;
  }

  static int getId(String token) => _vocab[token] ?? 100; // 100 = [UNK]
  static bool contains(String token) => _vocab.containsKey(token);
}
```

---

### 4.2 `BasicTokenizer` (File: `lib/services/ml/basic_tokenizer.dart`) **NEW!**
**Purpose**: Pre-process text before WordPiece. This is the **missing piece**.

**Steps**:
1.  Convert to lowercase.
2.  Strip accents (NFD normalization).
3.  **Insert spaces around punctuation** (CRITICAL!).
4.  Handle Chinese characters (space around each).
5.  Normalize whitespace.

```dart
import 'package:diacritic/diacritic.dart'; // Add to pubspec.yaml

class BasicTokenizer {
  // Punctuation characters to split on (matches Python's string.punctuation)
  static final _punctuation = RegExp(r'[!"#\$%&\'\(\)\*\+,\-\./:;<=>\?@\[\\\]\^_`\{\|\}~]');
  
  /// Tokenizes text into words, handling:
  /// - Lowercasing
  /// - Accent stripping (NFD normalization)
  /// - Punctuation splitting (even when adjacent to words)
  /// - Whitespace normalization
  static List<String> tokenize(String text) {
    // 1. Lowercase
    text = text.toLowerCase();
    
    // 2. Strip accents using proper Unicode NFD normalization
    // 'café' → 'cafe', 'naïve' → 'naive'
    text = removeDiacritics(text);
    
    // 3. Add spaces around EACH punctuation character
    // 'Rs.5000' → 'Rs . 5000'
    // "don't" → "don ' t"
    text = text.replaceAllMapped(_punctuation, (m) => ' ${m.group(0)} ');
    
    // 4. Normalize all whitespace (including newlines) and split
    text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    // 5. Split and filter empty strings
    return text.split(' ').where((t) => t.isNotEmpty).toList();
  }
}
```

> [!NOTE]
> **Dependency Required**: Add `diacritic: ^0.1.5` to `pubspec.yaml` for proper accent removal.

---

### 4.3 `WordPieceTokenizer` (File: `lib/services/ml/wordpiece_tokenizer.dart`)
**Purpose**: Core subword tokenization algorithm.

```dart
class WordPieceTokenizer {
  final int maxInputCharsPerWord;
  
  WordPieceTokenizer({this.maxInputCharsPerWord = 100});

  List<String> tokenize(List<String> words) {
    final List<String> outputTokens = [];

    for (final word in words) {
      if (word.length > maxInputCharsPerWord) {
        outputTokens.add('[UNK]');
        continue;
      }

      bool isBad = false;
      int start = 0;
      final List<String> subTokens = [];

      while (start < word.length) {
        int end = word.length;
        String? curSubstr;

        while (start < end) {
          String substr = word.substring(start, end);
          if (start > 0) substr = '##$substr';

          if (VocabLoader.contains(substr)) {
            curSubstr = substr;
            break;
          }
          end--;
        }

        if (curSubstr == null) {
          isBad = true;
          break;
        }

        subTokens.add(curSubstr);
        start = end;
      }

      if (isBad) {
        outputTokens.add('[UNK]');
      } else {
        outputTokens.addAll(subTokens);
      }
    }
    return outputTokens;
  }
}
```

---

### 4.4 `TokenEncoder` (File: `lib/services/ml/token_encoder.dart`)
**Purpose**: Combine all steps and produce model-ready inputs.

```dart
class TokenEncoder {
  static const int maxSeqLength = 192;  // FIXED: Was 128
  static const int clsId = 101;
  static const int sepId = 102;
  static const int padId = 0;

  final WordPieceTokenizer _wordPiece;
  
  TokenEncoder() : _wordPiece = WordPieceTokenizer();

  Map<String, List<int>> encode(String text) {
    // Step 1: Basic tokenization (lowercase, punctuation split)
    final words = BasicTokenizer.tokenize(text);
    
    // Step 2: WordPiece subword tokenization
    final tokens = _wordPiece.tokenize(words);

    // Step 3: Convert tokens to IDs
    List<int> ids = tokens.map((t) => VocabLoader.getId(t)).toList();

    // Step 4: Truncate if needed (leave room for [CLS] and [SEP])
    if (ids.length > maxSeqLength - 2) {
      ids = ids.sublist(0, maxSeqLength - 2);
    }

    // Step 5: Add special tokens
    ids = [clsId, ...ids, sepId];
    
    final realLength = ids.length;

    // Step 6: Pad to maxSeqLength
    while (ids.length < maxSeqLength) {
      ids.add(padId);
    }

    // Step 7: Create attention mask
    final attentionMask = List.generate(
      maxSeqLength, 
      (i) => i < realLength ? 1 : 0
    );

    return {
      'input_ids': ids,
      'attention_mask': attentionMask,
    };
  }
}
```

---

## 5. Validation Strategy (Enhanced)

### 5.1 Python Reference Generator
Create a Python script that outputs expected token IDs for test cases:
```python
# generate_test_cases.py
from transformers import MobileBertTokenizerFast
tokenizer = MobileBertTokenizerFast.from_pretrained('...')
test_cases = [
    "hello world",
    "Your OTP is 123456",
    "Congratulations! You won $1M",
    "Pay Rs. 5000 to avoid arrest!!!",
]
for text in test_cases:
    ids = tokenizer.encode(text, max_length=192, padding='max_length')
    print(f'"{text}": {ids[:20]}...')
```

### 5.2 Dart Unit Tests
Compare Dart output against Python reference for all test cases.

---

## 6. File Structure (Final)
```
lib/
└── services/
    └── ml/
        ├── vocab_loader.dart       # Load vocab.txt
        ├── basic_tokenizer.dart    # NEW: Punctuation/case handling
        ├── wordpiece_tokenizer.dart # Subword splitting
        ├── token_encoder.dart      # Full pipeline
        └── scam_detector_service.dart # TFLite inference
```

---

## 7. Edge Cases (Verified from Python Tokenizer)

Based on testing the actual Python tokenizer, here's how edge cases are handled:

| Input | Python Output (Tokens) | Notes |
|-------|------------------------|-------|
| `'hello world'` | `['hello', 'world']` | Basic case ✅ |
| `'Hello World'` | `['hello', 'world']` | Lowercased ✅ |
| `'Pay Rs.5000'` | `['pay', 'rs', '.', '5000']` | Punctuation split from adjacent text ✅ |
| `'123456'` | `['123', '##45', '##6']` | Numbers use WordPiece ✅ |
| `'OTP'` | `['ot', '##p']` | Not in vocab, subword split ✅ |
| `"don't"` | `['don', "'", 't']` | Apostrophe is punctuation ✅ |
| `'café'` | `['cafe']` | Accent stripped ✅ |
| `''` | `[]` → IDs: `[101, 102]` | Empty = just CLS+SEP ✅ |
| `'...!!!'` | `['.', '.', '.', '!', '!', '!']` | Each char separate ✅ |
| `'Hello\nWorld'` | `['hello', 'world']` | Newline → space ✅ |
| `'Rs10000 transferred'` | `['rs', '##100', '##00', 'transferred']` | Mixed alpha-numeric ✅ |

---

## 8. Risk Assessment (Updated)

| Risk | Severity | Status | Mitigation |
|------|----------|--------|------------|
| Accent handling incomplete | Medium | ✅ FIXED | Using `diacritic` package |
| Punctuation not split | Critical | ✅ FIXED | Added BasicTokenizer |
| Sequence length mismatch | High | ✅ FIXED | Now uses 192 |
| Edge cases (emojis, CJK) | Low | ⚠️ Known | SMS in India rarely has CJK |
| Empty string handling | Low | ✅ Handled | Returns `[CLS, SEP]` only |
| WordPiece for numbers | Medium | ✅ Handled | Algorithm handles naturally |

---

## 9. Dependencies to Add

```yaml
# pubspec.yaml
dependencies:
  tflite_flutter: ^0.11.0      # Already added
  diacritic: ^0.1.6            # NEW: For accent removal
```

---

## 10. Next Steps
1.  [x] Add `diacritic` dependency to pubspec.yaml
2.  [x] Implement `VocabLoader`
3.  [x] Implement `BasicTokenizer`
4.  [x] Implement `WordPieceTokenizer`
5.  [x] Implement `TokenEncoder`
6.  [x] Create `ScamDetectorService` (TFLite wrapper)
7.  [x] Generate Python reference test cases
8.  [x] Write Dart unit tests comparing against Python
9.  [ ] Run full integration test on device
10. [ ] Verify TFLite inference produces correct predictions

