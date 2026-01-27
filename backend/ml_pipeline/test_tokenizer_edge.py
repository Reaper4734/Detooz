from transformers import MobileBertTokenizerFast
t = MobileBertTokenizerFast.from_pretrained('backend/ml_pipeline/data/en_hinglish/saved_model')

# Test various edge cases
tests = [
    'hello world',
    'Hello World',  # Case sensitivity
    'Pay Rs.5000',  # No space around punctuation
    '123456',       # Pure numbers
    'OTP',          # Uppercase acronym
    "don't",        # Apostrophe in word
    'café',         # Accented character
    '',             # Empty string
    'a',            # Single char
    '...!!!',       # Multiple punctuation
    'Hello\nWorld', # Newline
    '  hello  ',    # Extra spaces
    'Rs10000 transferred',  # No space after currency
]

print("="*80)
for text in tests:
    tokens = t.tokenize(text)
    ids = t.encode(text)
    print(f'Input: {repr(text)}')
    print(f'  Tokens: {tokens}')
    print(f'  IDs: {ids}')
    print("-"*40)

