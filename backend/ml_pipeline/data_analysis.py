"""
Deep Dataset Analysis for Training Decision
Compares Clean/Base dataset vs Synthetic dataset
"""
import pandas as pd
import os

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # ml_pipeline -> backend
CLEAN_FILE = os.path.join(BASE_DIR, "ml_pipeline", "data", "en_hinglish", "final_training_set.csv")
SYNTHETIC_FILE = os.path.join(BASE_DIR, "ml_pipeline", "data", "en_hinglish", "raw_data", "synthetic_augment.csv")
OUTPUT_FILE = os.path.join(os.path.dirname(BASE_DIR), "data_analysis_report.txt")

def analyze():
    results = []
    
    # Load datasets
    df_clean = pd.read_csv(CLEAN_FILE) if os.path.exists(CLEAN_FILE) else pd.DataFrame()
    df_synth = pd.read_csv(SYNTHETIC_FILE) if os.path.exists(SYNTHETIC_FILE) else pd.DataFrame()
    
    results.append("=" * 60)
    results.append("DEEP DATA ANALYSIS REPORT")
    results.append("=" * 60)
    
    # === CLEAN DATASET ===
    results.append("\n📊 CLEAN/BASE DATASET (final_training_set.csv)")
    results.append("-" * 40)
    if not df_clean.empty:
        results.append(f"Total Samples: {len(df_clean)}")
        results.append(f"\nClass Distribution:")
        for t, c in df_clean['type'].value_counts().items():
            pct = c / len(df_clean) * 100
            results.append(f"  {t}: {c} ({pct:.1f}%)")
        
        results.append(f"\nText Length (chars):")
        stats = df_clean['text'].str.len().describe()
        results.append(f"  Mean: {stats['mean']:.0f}")
        results.append(f"  Min: {stats['min']:.0f}")
        results.append(f"  Max: {stats['max']:.0f}")
        results.append(f"  Std: {stats['std']:.0f}")
        
        # Source distribution
        if 'source' in df_clean.columns:
            results.append(f"\nSource Distribution:")
            for s, c in df_clean['source'].value_counts().head(5).items():
                results.append(f"  {s}: {c}")
    else:
        results.append("  ❌ File not found or empty")
    
    # === SYNTHETIC DATASET ===
    results.append("\n\n🧬 SYNTHETIC DATASET (synthetic_augment.csv)")
    results.append("-" * 40)
    if not df_synth.empty:
        results.append(f"Total Samples: {len(df_synth)}")
        results.append(f"\nClass Distribution:")
        for t, c in df_synth['type'].value_counts().items():
            pct = c / len(df_synth) * 100
            results.append(f"  {t}: {c} ({pct:.1f}%)")
        
        results.append(f"\nText Length (chars):")
        stats = df_synth['text'].str.len().describe()
        results.append(f"  Mean: {stats['mean']:.0f}")
        results.append(f"  Min: {stats['min']:.0f}")
        results.append(f"  Max: {stats['max']:.0f}")
        results.append(f"  Std: {stats['std']:.0f}")
        
        # Category breakdown (from source column)
        if 'source' in df_synth.columns:
            results.append(f"\nCategory Breakdown (Top 10):")
            for s, c in df_synth['source'].value_counts().head(10).items():
                cat = s.replace('synthetic_', '')
                results.append(f"  {cat}: {c}")
            
            # Safe vs Scam
            safe_count = df_synth[df_synth['source'].str.contains('safe', case=False)].shape[0]
            scam_count = len(df_synth) - safe_count
            results.append(f"\nSafe vs Scam:")
            results.append(f"  Safe: {safe_count} ({safe_count/len(df_synth)*100:.1f}%)")
            results.append(f"  Scam: {scam_count} ({scam_count/len(df_synth)*100:.1f}%)")
    else:
        results.append("  ❌ File not found or empty")
    
    # === COMPATIBILITY ANALYSIS ===
    results.append("\n\n⚖️ COMPATIBILITY ANALYSIS")
    results.append("-" * 40)
    
    if not df_clean.empty and not df_synth.empty:
        # Text length compatibility
        clean_mean = df_clean['text'].str.len().mean()
        synth_mean = df_synth['text'].str.len().mean()
        len_diff = abs(clean_mean - synth_mean) / clean_mean * 100
        
        results.append(f"Text Length Comparison:")
        results.append(f"  Clean Mean: {clean_mean:.0f} chars")
        results.append(f"  Synth Mean: {synth_mean:.0f} chars")
        results.append(f"  Difference: {len_diff:.1f}%")
        
        if len_diff < 20:
            results.append(f"  ✅ COMPATIBLE (< 20% difference)")
        elif len_diff < 50:
            results.append(f"  ⚠️ MODERATE DIFFERENCE (20-50%)")
        else:
            results.append(f"  ❌ SIGNIFICANT MISMATCH (> 50%)")
        
        # Class balance comparison
        results.append(f"\nClass Balance Check:")
        clean_scam_pct = (df_clean['type'] == 'scam').sum() / len(df_clean) * 100 if 'scam' in df_clean['type'].values else 0
        synth_scam_pct = (df_synth['type'] == 'scam').sum() / len(df_synth) * 100 if 'scam' in df_synth['type'].values else 0
        
        results.append(f"  Clean Scam%: {clean_scam_pct:.1f}%")
        results.append(f"  Synth Scam%: {synth_scam_pct:.1f}%")
        
        # OTP Check
        clean_otp = (df_clean['type'] == 'otp').sum() if 'otp' in df_clean['type'].values else 0
        synth_otp = (df_synth['type'] == 'otp').sum() if 'otp' in df_synth['type'].values else 0
        results.append(f"\nOTP Samples:")
        results.append(f"  Clean: {clean_otp}")
        results.append(f"  Synth: {synth_otp}")
        if clean_otp == 0 and synth_otp == 0:
            results.append(f"  ⚠️ WARNING: No OTP samples in either dataset!")
    
    # === VERDICT ===
    results.append("\n\n🏁 VERDICT")
    results.append("=" * 60)
    
    if not df_clean.empty and not df_synth.empty:
        # Option A Analysis
        results.append("\n📌 OPTION A (Continue Training):")
        if len_diff < 30:
            results.append("  ✅ Text lengths are compatible")
        else:
            results.append("  ⚠️ Text length mismatch may cause issues")
        
        if synth_scam_pct > 70:
            results.append("  ⚠️ Synthetic is heavily scam-focused (may cause bias)")
        else:
            results.append("  ✅ Good class balance in synthetic data")
        
        # Option B Analysis
        results.append("\n📌 OPTION B (Start Fresh):")
        combined_total = len(df_clean) + len(df_synth)
        synth_ratio = len(df_synth) / combined_total * 100
        results.append(f"  Combined Dataset: {combined_total} samples")
        results.append(f"  Synthetic Ratio: {synth_ratio:.1f}%")
        
        if synth_ratio > 80:
            results.append("  ⚠️ Synthetic data dominates (may lose clean data patterns)")
        else:
            results.append("  ✅ Good balance between clean and synthetic")
    
    # Write to file
    with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
        f.write('\n'.join(results))
    
    print(f"✅ Analysis complete. Report saved to: {OUTPUT_FILE}")

if __name__ == "__main__":
    analyze()
