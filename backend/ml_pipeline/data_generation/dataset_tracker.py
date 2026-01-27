
"""
Dataset Tracker & Validator 📊
Tracks progress towards the 50k goal defined in scam_taxonomy.py.
Checks:
1. Count per Category vs Target.
2. Duplicates (Exact Match).
3. "AI Artifacts" (e.g., "Here are 10 examples...").
"""
import csv
import os
import re
import argparse
import pandas as pd
from collections import defaultdict
try:
    from .scam_taxonomy import SCAM_TAXONOMY, TOTAL_TARGET
except ImportError:
    import sys
    sys.path.append(os.path.dirname(os.path.abspath(__file__)))
    from scam_taxonomy import SCAM_TAXONOMY, TOTAL_TARGET

BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

def analyze_dataset(target_lang="en_hinglish"):
    # Dynamic Path based on Lang
    data_file = os.path.join(BASE_DIR, "ml_pipeline", "data", target_lang, "raw_data", "synthetic_augment.csv")
    
    print(f"🔍 Analyzing {data_file}...")
    
    if not os.path.exists(data_file):
        print(f"❌ Data file not found: {data_file}")
        return

    stats = defaultdict(int)
    duplicates = 0
    ai_artifacts = 0
    seen_texts = set()
    rows = []

    try:
        with open(data_file, 'r', encoding='utf-8', errors='replace') as f:
            reader = csv.DictReader(f)
            for row in reader:
                text = row.get('text', '').strip()
                cat = row.get('source', '').replace('synthetic_', '')
                
                # Check Garbage
                if not text or len(text) < 5:
                    continue

                # Check Duplicates
                if text in seen_texts:
                    duplicates += 1
                    continue
                seen_texts.add(text)

                # Check AI Artifacts (Common Llama-3 failures)
                if re.search(r"Here is a|Sure,|I cannot|Note:|JSON", text, re.IGNORECASE):
                    ai_artifacts += 1
                    continue

                # Count Valid
                stats[cat] += 1
                rows.append(row)
    except Exception as e:
        print(f"❌ Error reading file: {e}")
        return

    # Report to File
    report_file = os.path.join(BASE_DIR, "dataset_analysis.md")
    with open(report_file, 'w', encoding='utf-8') as f:
        f.write(f"# 📊 Synthetic Dataset Analysis ({target_lang})\n")
        f.write(f"**Target:** {TOTAL_TARGET} samples\n\n")
        
        total_valid = sum(stats.values())
        f.write("## 📝 Summary\n")
        f.write(f"- **Total Valid Samples:** {total_valid}\n")
        f.write(f"- **Duplicates Removed:** {duplicates}\n")
        f.write(f"- **AI Artifacts Detected:** {ai_artifacts}\n\n")
        
        f.write("## 📈 Category Breakdown\n")
        f.write("| Category | Count | Target | Progress | Status |\n")
        f.write("| :--- | :--- | :--- | :--- | :--- |\n")
        
        sorted_cats = sorted(SCAM_TAXONOMY.keys())
        for cat in sorted_cats:
            count = stats.get(cat, 0)
            target = SCAM_TAXONOMY[cat]['target']
            ratio = count / target if target > 0 else 0
            
            # Status Indicator
            if ratio >= 1.0: status = "✅ Done"
            elif ratio >= 0.5: status = "⚠️ In Progress"
            else: status = "❌ Low"
            
            # Bar (Approximate)
            bar_len = int(ratio * 20)
            bar = "█" * min(bar_len, 20)
            
            f.write(f"| `{cat}` | {count} | {target} | {ratio:.1%} | {status} |\n")

    print(f"✅ Analysis saved to: {report_file}")
    print(f"    Valid: {total_valid} | Duplicates: {duplicates}")

if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--lang", default="en_hinglish", help="Target Language (en_hinglish, hi, mr)")
    args = parser.parse_args()
    analyze_dataset(args.lang)
