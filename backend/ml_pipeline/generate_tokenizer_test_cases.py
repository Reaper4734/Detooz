"""
Generate Python Reference Test Cases for Dart Tokenizer Validation

This script outputs the expected token IDs from the Python MobileBERT tokenizer
for a set of test cases. These values are used to validate the Dart implementation.

Usage:
    python generate_tokenizer_test_cases.py

Output:
    Prints test cases in a format that can be copied to Dart tests.
"""

from transformers import MobileBertTokenizerFast
import json

# Load the trained tokenizer
MODEL_PATH = 'backend/ml_pipeline/data/en_hinglish/saved_model'
tokenizer = MobileBertTokenizerFast.from_pretrained(MODEL_PATH)

# Test cases covering various scenarios
TEST_CASES = [
    # Basic cases
    "hello world",
    "Hello World",  # Should be lowercased
    
    # Punctuation handling
    "Hello, world!",
    "Pay Rs.5000",
    "don't",
    "...!!!",
    
    # Numbers
    "123456",
    "Your OTP is 123456",
    
    # Accents
    "café",
    "naïve",
    "résumé",
    
    # Edge cases
    "",  # Empty string
    "a",  # Single character
    "  hello  ",  # Extra whitespace
    "Hello\nWorld",  # Newline
    
    # Real scam examples
    "You won a lottery of Rs 50 lakh! Call 9876543210 now",
    "Dear customer, your SBI account will be blocked. Update KYC immediately",
    "Mom I'm in hospital please send money to 9123456789",
    
    # Real OTP examples
    "Your OTP is 456789. Do not share with anyone.",
    "123456 is your verification code for Amazon",
    
    # Real HAM examples
    "Hey, want to grab lunch tomorrow?",
    "Meeting rescheduled to 3pm",
]

print("=" * 80)
print("PYTHON TOKENIZER REFERENCE DATA")
print("=" * 80)
print()

# Generate reference data
reference_data = []

for text in TEST_CASES:
    tokens = tokenizer.tokenize(text)
    ids = tokenizer.encode(text, max_length=192, padding='max_length', truncation=True)
    
    # Get non-padded IDs for easier comparison
    non_padded_ids = [id for id in ids if id != 0 or ids.index(id) < ids.index(102) + 1]
    # Actually, let's just get until the first [SEP]
    sep_idx = ids.index(102) + 1 if 102 in ids else len(ids)
    core_ids = ids[:sep_idx]
    
    reference_data.append({
        'text': text,
        'tokens': tokens,
        'core_ids': core_ids,
        'full_ids_head': ids[:20],  # First 20 IDs
    })
    
    print(f"Text: {repr(text)}")
    print(f"  Tokens: {tokens}")
    print(f"  Core IDs: {core_ids}")
    print("-" * 40)

print()
print("=" * 80)
print("DART TEST CASE FORMAT")
print("=" * 80)
print()

# Output in Dart-friendly format
print("final testCases = [")
for data in reference_data:
    print(f"  {{")
    print(f"    'text': {repr(data['text'])},")
    print(f"    'tokens': {data['tokens']},")
    print(f"    'expected_ids': {data['core_ids']},")
    print(f"  }},")
print("];")

print()
print("=" * 80)
print("SUMMARY")
print("=" * 80)
print(f"Total test cases: {len(TEST_CASES)}")
print(f"Vocab size: {tokenizer.vocab_size}")
print(f"Special tokens: [CLS]={tokenizer.cls_token_id}, [SEP]={tokenizer.sep_token_id}, [PAD]={tokenizer.pad_token_id}, [UNK]={tokenizer.unk_token_id}")
