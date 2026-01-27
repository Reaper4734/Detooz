"""
Large-Scale Synthetic Data Generator (Indian Context 🇮🇳)
Target: 50,000 Samples with High Variance.
Uses: scam_taxonomy.py for definitions and targets.
"""
import os
import csv
import time
import json
import random
import warnings
from collections import defaultdict
from dotenv import load_dotenv

# Suppress Deprecation Warnings for google.generativeai
warnings.simplefilter(action='ignore', category=FutureWarning)

# Optional Imports
try:
    from groq import Groq
except ImportError:
    Groq = None

try:
    import google.generativeai as genai
except ImportError:
    genai = None

# Import Taxonomy
try:
    from scam_taxonomy import SCAM_TAXONOMY, TOTAL_TARGET
except ImportError:
    import sys
    sys.path.append(os.path.dirname(os.path.abspath(__file__)))
    from scam_taxonomy import SCAM_TAXONOMY, TOTAL_TARGET

# Load .env
# Go up 4 levels: data_gen -> ml_pipe -> backend -> Detooz
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
ENV_PATH = os.path.join(BASE_DIR, ".env")
load_dotenv(ENV_PATH)

# Ensure correct output path
OUTPUT_FILE = os.path.join(BASE_DIR, "backend", "ml_pipeline", "data", "en_hinglish", "raw_data", "synthetic_augment.csv")
os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)

# ==========================================
# CONFIGURATION
# ==========================================
CALLS_PER_BATCH = 10     
SAMPLES_PER_PROMPT = 20  # High Throughput
DEFAULT_PROVIDER = "gemini" 

# Region Classifiers (Refined for En/Hinglish Context)
REGIONS = [
    "North India - Hinglish (Hindi words in English script) / Urgent",
    "South India - Formal English / Official Tone",
    "West India - Business/Trade Tone / Hinglish",
    "East India - Urgent / Panic Tone",
    "Metro Cities - Corporate / Fluent English",
    "Rural India - Broken English / Grammatical Errors"
]

# Expanded Tier 1, 2, 3 Cities (Retained from user edit)
LOCATIONS = [
    "Mumbai", "Delhi", "Bangalore", "Hyderabad", "Chennai", "Kolkata", "Pune", "Ahmedabad",
    "Jaipur", "Surat", "Lucknow", "Kanpur", "Nagpur", "Indore", "Thane", "Bhopal", 
    "Visakhapatnam", "Patna", "Vadodara", "Ghaziabad", "Ludhiana", "Agra", "Nashik", 
    "Faridabad", "Meerut", "Rajkot", "Varanasi", "Srinagar", "Aurangabad", "Dhanbad", 
    "Amritsar", "Allahabad", "Ranchi", "Coimbatore", "Jabalpur", "Gwalior", "Vijayawada", 
    "Jodhpur", "Madurai", "Raipur", "Kota", "Guwahati", "Chandigarh", "Solapur", 
    "Hubballi-Dharwad", "Mysore", "Tiruchirappalli", "Bareilly", "Aligarh", "Tiruppur",
    "Gurgaon", "Noida", "Jamshedpur", "Bhilai", "Cuttack", "Firozabad", "Kochi", 
    "Thiruvananthapuram", "Bhubaneswar", "Dehradun"
]

NAMES = [
    "Aarav", "Vivaan", "Aditya", "Vihaan", "Arjun", "Sai", "Reyansh", "Ayaan", "Krishna", "Ishaan",
    "Shaurya", "Atharv", "Neel", "Siddharth", "Shiv", "Rudra", "Om", "Veer", "Dhruv", "Rishabh",
    "Anaya", "Myra", "Aadhya", "Saanvi", "Kiara", "Diya", "Pari", "Mira", "Riya", "Ananya",
    "Priya", "Sneha", "Nisha", "Pooja", "Neha", "Kavita", "Roshni", "Simran", "Tanvi", "Megha",
    "Rahul", "Rohit", "Sameer", "Amit", "Suresh", "Ramesh", "Mukesh", "Anil", "Sunil", "Vikram",
    "Preeti", "Sonia", "Kajal", "Swati", "Rashmi", "Divya", "Anita", "Sunita", "Reena", "Suman",
    "Karan", "Manish", "Deepak", "Sanjay", "Raj", "Vikas", "Ashish", "Mohit", "Nitin", "Varun"
]

AMOUNTS = [
    "500", "1500", "2000", "2500", "3500", "5000", "8500", "10,000", "15,000",
    "20,000", "25,000", "30,000", "45,000", "50,000", "75,000", "1 Lakh", "1.5 Lakhs", "2.5 Lakhs", "5 Lakhs",
    "8 Lakhs", "10 Lakhs", "25 Lakhs", "50 Lakhs", "1 Crore", "7 Crore", "15000"
]

BANKS = ["SBI", "HDFC", "ICICI", "Axis", "Paytm Payments Bank", "PhonePe", "Google Pay", "Kotak Mahindra", "Punjab National Bank", "Bank of Baroda", "Canara Bank", "Union Bank", "IDFC First", "IndusInd"]

def get_dynamic_prompt(category_key):
    defn = SCAM_TAXONOMY.get(category_key)
    if not defn: return None
    
    # 1. Select Region for Context/Tone
    region_context = random.choice(REGIONS)
    
    # 2. Select Entity POOLS (Diversity!)
    # We pass a MENU of options so the LLM can pick different ones for each sample
    locs = random.sample(LOCATIONS, min(3, len(LOCATIONS))) 
    names = random.sample(NAMES, min(5, len(NAMES)))
    amts = random.sample(AMOUNTS, min(3, len(AMOUNTS)))
    banks = random.sample(BANKS, min(3, len(BANKS)))
    
    desc = defn['description']
    kw = ", ".join(random.sample(defn['keywords'], min(3, len(defn['keywords']))))
    
    prompt = (
        f"Generate {SAMPLES_PER_PROMPT} DISTINCT text messages for Indian context. "
        f"Category: '{category_key}' ({desc}). "
        f"Region/Persona Context: {region_context}. "
        f"CRITICAL INSTRUCTIONS for 'en_hinglish' Dataset:"
        f"1. LANGUAGE: Use English or Hinglish (Hindi words in Roman script). "
        f"   - ❌ DO NOT use Devanagari or other local scripts. "
        f"   - if 'Rural', simulate broken English. "
        f"2. VARIANCE IN ENTITIES (Mix these randomly across the {SAMPLES_PER_PROMPT} samples): "
        f"   - Names to use: {names} "
        f"   - Cities to use: {locs} "
        f"   - Amounts to use: {amts} "
        f"   - Banks to use: {banks} "
        f"   (IMPORTANT: Do NOT use the same name/city for every message. Shuffle them.)"
        f"3. KEYWORDS: Naturally include: {kw}. "
        f"4. TONE: Match the region context ({region_context}). "
        f"5. FORMAT: Return ONLY a valid JSON array of strings ['msg1', 'msg2', ...]. Do not include markdown code blocks or 'json' label."
    )
    return prompt

def generate_with_groq(client, prompt):
    completion = client.chat.completions.create(
        messages=[{"role": "user", "content": prompt}],
        model="llama-3.3-70b-versatile",
        temperature=0.95,
    )
    return completion.choices[0].message.content

def generate_with_gemini(model, prompt):
    response = model.generate_content(prompt)
    return response.text

def generate_large_scale():
    # 1. Provider Selection
    print(f"\n⚙️ Default Provider: {DEFAULT_PROVIDER.upper()}")
    provider_input = input("Press [Enter] for Default, or type 'groq' > ").strip().lower()
    provider = provider_input if provider_input in ['groq', 'gemini'] else DEFAULT_PROVIDER
    
    print(f"🚀 Initializing {provider.upper()}...")

    groq_client = None
    gemini_model = None

    if provider == 'groq':
        api_key = os.getenv("GROQ_API_KEY") or os.getenv("GROQ_TRAINING_KEY")
        if not api_key:
            print("❌ GROQ_API_KEY not found.")
            return
        groq_client = Groq(api_key=api_key)
        
    elif provider == 'gemini':
        api_key = os.getenv("GOOG_API_KEY") or os.getenv("GOOGLE_API_KEY")
        if not api_key:
            print("❌ GOOGLE_API_KEY not found.")
            return
        genai.configure(api_key=api_key)
        # Model Priority: Gemma 3 (High Quality) > Flash (Speed/Quota) > Pro
        priorities = ['gemma-3-27b-it', 'gemini-1.5-flash', 'gemini-pro']
        chosen_model_name = None

        print("🔍 Searching for available models...")
        try:
             # List available models that support generateContent
             available = [m.name for m in genai.list_models() if 'generateContent' in m.supported_generation_methods]
             
             for p in priorities:
                 match = next((m for m in available if p in m), None)
                 if match:
                     chosen_model_name = match
                     break
             
             if not chosen_model_name and available:
                 chosen_model_name = available[0]
                 
        except Exception as e:
             print(f"⚠️ Model list failed ({e}). Defaulting to Flash.")
             chosen_model_name = 'models/gemini-1.5-flash'

        if not chosen_model_name:
            chosen_model_name = 'models/gemini-1.5-flash'

        print(f"✅ Selected Model: {chosen_model_name}")
        gemini_model = genai.GenerativeModel(chosen_model_name)

    # 2. Mode Selection
    print("\nSelect Execution Mode:")
    print("  [N] = Run N batches automatically")
    print("  [i] = Infinite Loop")
    print("  [s] = Step-by-Step")
    
    mode_input = input("Enter Mode > ").strip().lower()
    
    target_batches = 0
    infinite_mode = False
    step_mode = False
    
    if mode_input == 's': 
        step_mode = True
        print("⚡ Mode: Step-by-Step")
    elif mode_input == 'i': 
        infinite_mode = True
        print("⚡ Mode: Infinite Loop (Ctrl+C to stop)")
    elif mode_input == 'n':
        try:
             nb = input("  Enter number of batches > ").strip()
             target_batches = int(nb)
             print(f"⚡ Mode: Auto-Run {target_batches} Batches")
        except ValueError:
             print("⚠️ Invalid Number. Defaulting to 1 batch.")
             target_batches = 1
    else:
        try:
            target_batches = int(mode_input)
            print(f"⚡ Mode: Auto-Run {target_batches} Batches")
        except:
             print("⚠️ Invalid Input. Defaulting to Step-by-Step.")
             step_mode = True

    # Init Stats
    stats = defaultdict(int)
    total_generated = 0
    
    # Read existing
    if os.path.exists(OUTPUT_FILE):
        with open(OUTPUT_FILE, 'r', encoding='utf-8') as f:
            reader = csv.DictReader(f)
            for row in reader:
                cat = row.get('source', 'unknown').replace('synthetic_', '')
                stats[cat] += 1
        print("📊 Loaded existing stats.")
    else:
        os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
        with open(OUTPUT_FILE, 'w', newline='', encoding='utf-8') as f:
            csv.DictWriter(f, fieldnames=["text", "type", "source"]).writeheader()

    batch_count = 1
    
    while True:
        # Check Stop
        if not infinite_mode and not step_mode:
            if batch_count > target_batches:
                print("✅ Target Reached.")
                break

        # Selection
        active_cats = []
        for cat, defn in SCAM_TAXONOMY.items():
            if stats[cat] < defn['target']:
                active_cats.append(cat)
        
        if not active_cats:
            print("✅ All Categories Saturated.")
            break

        active_cats.sort(key=lambda c: stats[c] / SCAM_TAXONOMY[c]['target'])
        batch_candidates = active_cats[:CALLS_PER_BATCH]
        if len(batch_candidates) < CALLS_PER_BATCH:
             while len(batch_candidates) < CALLS_PER_BATCH:
                 batch_candidates.append(random.choice(active_cats))
        random.shuffle(batch_candidates)

        print(f"\n🚀 Batch {batch_count} | Provider: {provider}")
        start_time = time.time()
        
        for i, category in enumerate(batch_candidates):
            prompt = get_dynamic_prompt(category)
            print(f"   [{i+1}/{CALLS_PER_BATCH}] {category}...")
            
            try:
                content = ""
                if provider == 'groq':
                    content = generate_with_groq(groq_client, prompt)
                else:
                    content = generate_with_gemini(gemini_model, prompt + " Return JSON array.")

                content = content.replace("```json", "").replace("```", "").strip()
                if content.startswith("JSON"): content = content[4:].strip()
                
                messages = json.loads(content)
                
                with open(OUTPUT_FILE, 'a', newline='', encoding='utf-8') as f:
                    writer = csv.DictWriter(f, fieldnames=["text", "type", "source"])
                    label = "ham" if "safe" in category else "scam"
                    for msg in messages:
                        writer.writerow({"text": msg, "type": label, "source": f"synthetic_{category}"})
                
                count = len(messages)
                stats[category] += count
                total_generated += count
                
                
            except Exception as e:
                print(f"      ⚠️ Error: {e}")
                if "quota" in str(e).lower() or "429" in str(e):
                    time.sleep(60)

        elapsed = time.time() - start_time
        print(f"✅ Batch {batch_count} Done. New: {total_generated}. Total: {sum(stats.values())}")
        
        if elapsed < 65 and provider == 'groq':
            time.sleep(65 - elapsed)
            
        if step_mode:
            if input("Continue? [Enter]/[q] > ").lower() == 'q': break
        
        batch_count += 1

if __name__ == "__main__":
    generate_large_scale()
