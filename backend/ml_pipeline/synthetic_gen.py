"""
Synthetic Data Generator
Uses Groq (Llama-3) to generate novel scam examples (Emotional, Lottery, Impersonation)
to augment the training dataset.
"""
import os
import csv
import time
import json
from groq import Groq

# Output File
OUTPUT_FILE = "ml_pipeline/raw_data/synthetic_augment.csv"

# Prompts for Data Augmentation
SCAM_SCENARIOS = [
    {
        "type": "scam",
        "category": "emotional",
        "prompt": "Generate 10 different SMS messages where a scammer pretends to be a family member (son/daughter) in trouble (lost phone, jail, hospital) asking for money. Make them sound urgent and realistic. Return only a JSON array of strings."
    },
    {
        "type": "scam",
        "category": "lottery",
        "prompt": "Generate 10 different 'Lottery Winner' SMS messages claiming the user won a prize (iPhone, Car, Cash) and needs to click a link or pay a fee. Return only a JSON array of strings."
    },
    {
        "type": "scam",
        "category": "impersonation",
        "prompt": "Generate 10 different SMS messages where a scammer impersonates a bank or government official (IRS, Tax, Police) threatening action if not paid. Return only a JSON array of strings."
    },
    {
        "type": "ham",
        "category": "safe_emotional",
        "prompt": "Generate 10 normal, safe SMS messages from a family member checking in, saying happy birthday, or asking about dinner. No requests for money. Return only a JSON array of strings."
    }
]

def generate_synthetic_data():
    api_key = os.getenv("GROQ_TRAINING_KEY")
    if not api_key:
        print("⚠️ GROQ_TRAINING_KEY not found. Skipping synthetic augmentation.")
        return

    print("🤖 Starting Synthetic Data Generation (Groq)...")
    client = Groq(api_key=api_key)
    
    all_rows = []
    
    for scenario in SCAM_SCENARIOS:
        print(f"   generating {scenario['category']}...")
        try:
            completion = client.chat.completions.create(
                messages=[
                    {
                        "role": "user",
                        "content": scenario["prompt"] + " IMPORTANT: Respond ONLY with the valid JSON array. No code blocks."
                    }
                ],
                model="llama-3.3-70b-versatile",
                temperature=0.8,
            )
            
            content = completion.choices[0].message.content.strip()
            # Clean potential markdown code blocks
            if content.startswith("```"):
                content = content.replace("```json", "").replace("```", "")
            
            messages = json.loads(content)
            
            for msg in messages:
                all_rows.append({
                    "text": msg,
                    "type": scenario["type"],
                    "source": f"synthetic_{scenario['category']}"
                })
                
            time.sleep(1) # Rate limit politeness
            
        except Exception as e:
            print(f"   ❌ Failed to generate {scenario['category']}: {e}")

    # Save to CSV
    if all_rows:
        with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=["text", "type", "source"])
            writer.writeheader()
            writer.writerows(all_rows)
        print(f"✅ Generated {len(all_rows)} synthetic samples. Saved to {OUTPUT_FILE}")
    else:
        print("⚠️ No synthetic data generated.")

if __name__ == "__main__":
    generate_synthetic_data()
