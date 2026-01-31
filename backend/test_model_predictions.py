"""Test the local AI model with various message patterns"""
from transformers import AutoModelForSequenceClassification, AutoTokenizer
import torch

model_path = 'ml_pipeline/data/en_hinglish/saved_model'
tokenizer = AutoTokenizer.from_pretrained(model_path)
model = AutoModelForSequenceClassification.from_pretrained(model_path)
model.eval()

labels = ['ham', 'otp', 'scam']

test_messages = [
    # Original problematic message
    'Hi mom how are you',
    
    # Variations of casual greetings
    'Hello mom, how are you doing today?',
    'Hey dad, I am fine',
    'Good morning, hope you are well',
    'How are you doing?',
    'I am fine, thank you',
    
    # "Hi Mom" scam patterns
    'Hi mom, I lost my phone',
    'Hey dad, I need money urgently',
    'Hi this is your son, send money to this number',
    'Mom I am in trouble please help',
    
    # Clear scams
    'Please send me 5000 rupees urgent',
    'Congratulations! You won lottery click here',
    'Your KYC is expiring, update now',
    
    # Clear HAM
    'Meeting at 5pm tomorrow',
    'Did you buy groceries?',
    'What time is dinner?',
    
    # OTP type
    'Your OTP is 123456',
    'Verification code: 5678',
]

print('=' * 70)
print(f"{'Message':<45} | {'Pred':<4} | {'Confidence'}")
print('=' * 70)

for msg in test_messages:
    inputs = tokenizer(msg, return_tensors='pt', truncation=True, max_length=128)
    with torch.no_grad():
        outputs = model(**inputs)
        probs = torch.softmax(outputs.logits, dim=1)[0]
        pred_idx = probs.argmax().item()
        conf = probs[pred_idx].item()
        
        # Show all class probabilities for borderline cases
        if conf < 0.90:
            all_probs = ' | '.join([f'{labels[i]}:{probs[i].item()*100:.0f}%' for i in range(3)])
            print(f'{msg[:45]:<45} | {labels[pred_idx]:<4} | {conf*100:.1f}% ({all_probs})')
        else:
            print(f'{msg[:45]:<45} | {labels[pred_idx]:<4} | {conf*100:.1f}%')

print('=' * 70)
