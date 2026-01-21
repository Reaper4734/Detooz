"""
ML Pipeline Orchestrator
Automates the End-to-End Data Preparation:
1. Fetch Public Data (HF + UCI)
2. Generate Synthetic Data (Groq)
3. Merge & Clean
4. Export Final Dataset
"""
import os
import pandas as pd
from ml_pipeline.data_fetcher import ensure_dir, fetch_primary_dataset, fetch_uci_dataset, normalize_datasets
from ml_pipeline.synthetic_gen import generate_synthetic_data, OUTPUT_FILE as SYNTHETIC_FILE

FINAL_OUTPUT = "ml_pipeline/final_training_set.csv"

def run_pipeline():
    print("🚀 Starting ML Auto-Train Pipeline...")
    ensure_dir()
    
    # Step 1: Fetch Real Data
    print("\n📦 STEP 1: Fetching Real Data...")
    df_hf = fetch_primary_dataset()
    df_uci = fetch_uci_dataset()
    
    if df_hf.empty and df_uci.empty:
        print("❌ Critical Error: No real data fetched. Aborting.")
        return

    df_real = normalize_datasets(df_hf, df_uci)
    
    # Step 2: Generate Synthetic Data
    print("\n🤖 STEP 2: generating Synthetic Data...")
    # Only run if key is present, handled inside the function
    generate_synthetic_data()
    
    # Step 3: Merge All
    print("\n🔗 STEP 3: Merging & Finalizing...")
    dfs_to_merge = [df_real]
    
    if os.path.exists(SYNTHETIC_FILE):
        try:
            df_synth = pd.read_csv(SYNTHETIC_FILE)
            print(f"   ➕ Adding {len(df_synth)} synthetic samples")
            dfs_to_merge.append(df_synth)
        except Exception as e:
            print(f"   ⚠️ Failed to load synthetic data: {e}")
            
    final_df = pd.concat(dfs_to_merge, ignore_index=True)
    
    # Shuffle
    final_df = final_df.sample(frac=1, random_state=42).reset_index(drop=True)
    
    # Step 4: Validate & Save
    print("\n✅ STEP 4: Validation")
    print(f"   Total Samples: {len(final_df)}")
    print(f"   Class Distribution:\n{final_df['type'].value_counts()}")
    
    final_df.to_csv(FINAL_OUTPUT, index=False)
    print(f"\n💾 Pipeline Complete! Final Dataset saved to: {FINAL_OUTPUT}")
    print(f"   Ready for training MobileBERT.")

if __name__ == "__main__":
    run_pipeline()
