
import pandas as pd
import os

DATA_FILE = r"C:\CP\plans\Detooz\backend\ml_pipeline\final_training_set.csv"

def analyze_data():
    if not os.path.exists(DATA_FILE):
        print("❌ Dataset not found.")
        return

    print("📊 Loading dataset...")
    df = pd.read_csv(DATA_FILE)
    
    print(f"✅ Total Samples: {len(df)}")
    print(f"Columns: {df.columns.tolist()}")
    
    label_col = 'label' if 'label' in df.columns else 'type'
    if label_col in df.columns:
        print(f"\n--- Class Distribution ({label_col}) ---")
        print(df[label_col].value_counts())
    else:
        print("⚠️ Label column not found (checked 'label', 'type').")
    
    # Check if 'source' or similar column exists for "type of data"
    if 'source' in df.columns:
        print("\n--- Data Sources ---")
        print(df['source'].value_counts())
    else:
        print("\nℹ️ 'source' column not found.")

if __name__ == "__main__":
    analyze_data()
