import csv
import os
import re

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
DATA_FILE = os.path.join(BASE_DIR, "backend", "ml_pipeline", "data", "en_hinglish", "raw_data", "synthetic_augment.csv")

def is_roman_script(text):
    # Matches ASCII + Common Latin-1 Supplement (Accents) + Punctuation
    # If it contains Devanagari (U+0900-U+097F), Bengali (U+0980-U+09FF), etc., it fails.
    # We'll calculate the ratio of non-latin chars.
    
    # Remove standard punctuation/numbers/spaces AND specific allowed symbols
    # Allowed: ₹ (20B9), Smart Quotes, Dashes, etc.
    allowed_chars = r'[₹’“”–—0-9\s!@#$%^&*()_\-+=.,<>\?/"\':;\[\]\{\}|\\`~]'
    clean_text = re.sub(allowed_chars, '', text)
    
    if not clean_text: return True
    
    # Check if remaining chars are Latin
    # Latin-1 block is u0000-u00FF approx (covering English)
    # We want to detect high-range unicode chars (Devanagari is 09xx)
    non_latin_count = sum(1 for c in clean_text if ord(c) > 0x024F) # Above Latin Extended-B
    
    return non_latin_count == 0

def audit_quality():
    print(f"🔍 Auditing {DATA_FILE}...")
    if not os.path.exists(DATA_FILE):
        print("File not found.")
        return

    stats = {
        "total": 0,
        "clean": 0,
        "dirty_script": 0,
        "dirty_rows": []
    }

    with open(DATA_FILE, 'r', encoding='utf-8', errors='replace') as f:
        reader = csv.DictReader(f)
        for i, row in enumerate(reader):
            text = row.get('text', '')
            stats["total"] += 1
            
            if is_roman_script(text):
                stats["clean"] += 1
            else:
                stats["dirty_script"] += 1
                if len(stats["dirty_rows"]) < 5:
                    stats["dirty_rows"].append(text[:100] + "...")

    with open("quality_report.txt", "w", encoding="utf-8") as out:
        out.write(f"📊 Quality Audit Results\n")
        out.write(f"Total Rows: {stats['total']}\n")
        out.write(f"✅ Clean (Roman/English/Hinglish): {stats['clean']} ({stats['clean']/stats['total']:.1%})\n")
        out.write(f"❌ Dirty (Regional Scripts Detected): {stats['dirty_script']} ({stats['dirty_script']/stats['total']:.1%})\n")
        
        if stats["dirty_rows"]:
            out.write("\n📝 Examples of Dirty Data (to be cleaned):\n")
            for ex in stats["dirty_rows"]:
                out.write(f" - {ex}\n")
    
    print("✅ Audit complete. Check quality_report.txt")

if __name__ == "__main__":
    audit_quality()
