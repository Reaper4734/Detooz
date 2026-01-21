
import pandas as pd
import numpy as np

DATA_FILE = "ml_pipeline/final_training_set.csv"
CLEAN_FILE = "ml_pipeline/clean_training_set.csv"

def clean_data():
    print(f"🔍 Inspecting {DATA_FILE}...")
    try:
        df = pd.read_csv(DATA_FILE)
        print(f"   Original Count: {len(df)}")
        
        # Check for NaNs
        nans = df['text'].isna().sum()
        print(f"   ⚠️ Found {nans} Null text rows.")
        
        # Check for Non-Strings
        non_strings = df[~df['text'].apply(lambda x: isinstance(x, str))]
        print(f"   ⚠️ Found {len(non_strings)} Non-String text rows.")
        if len(non_strings) > 0:
            print("   Samples:", non_strings.head())

        # Cleaning
        print("🧹 Cleaning Data...")
        # Drop NaNs
        df = df.dropna(subset=['text', 'type'])
        
        # Ensure String
        df['text'] = df['text'].astype(str)
        
        # Remove empty strings
        df = df[df['text'].str.strip().astype(bool)]
        
        # Verify Labels
        print(f"   Labels: {df['type'].unique()}")
        
        # Save
        df.to_csv(CLEAN_FILE, index=False)
        print(f"✅ Cleaned Count: {len(df)}")
        print(f"💾 Saved to {CLEAN_FILE}")
        
    except Exception as e:
        print(f"❌ Failed to read CSV: {e}")

if __name__ == "__main__":
    clean_data()
