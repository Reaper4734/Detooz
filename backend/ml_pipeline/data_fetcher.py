import os
import pandas as pd
import requests
import zipfile
import io
import traceback
from datasets import load_dataset

# Constants
HF_DATASET_ID = "gandharvbakshi/SMS-dataset-OTP-OTP_INTENT_Phishing"
UCI_URL = "https://archive.ics.uci.edu/static/public/228/sms+spam+collection.zip"

RAW_DIR = "ml_pipeline/raw_data"

def ensure_dir():
    os.makedirs(RAW_DIR, exist_ok=True)

from huggingface_hub import list_repo_files, hf_hub_download

def fetch_primary_dataset() -> pd.DataFrame:
    """Download OTP/Phishing dataset via 'datasets' or direct file download"""
    print("⬇️ Fetching Primary Dataset (HuggingFace Gated)...")
    
    # 1. Try Standard Way
    try:
        ds = load_dataset(HF_DATASET_ID, split="train")
        df = ds.to_pandas()
        print(f"   ✅ Loaded {len(df)} rows (Standard).")
        return df
    except Exception as e:
        print(f"   ⚠️ 'load_dataset' failed: {e}")
        print("   🔄 Attempting direct download via huggingface_hub...")
    
    # 2. Key Fallback: Download raw file
    try:
        # Find CSV or Parquet
        files = list_repo_files(repo_id=HF_DATASET_ID, repo_type="dataset")
        target_file = next((f for f in files if f.endswith('.csv')), None)
        if not target_file:
            target_file = next((f for f in files if f.endswith('.parquet')), None)
            
        if not target_file:
            print("   ❌ No CSV/Parquet found in repo.")
            return pd.DataFrame()
            
        print(f"   📄 Found file: {target_file}")
        downloaded_path = hf_hub_download(repo_id=HF_DATASET_ID, filename=target_file, repo_type="dataset")
        
        if target_file.endswith('.csv'):
            df = pd.read_csv(downloaded_path)
        else:
            df = pd.read_parquet(downloaded_path)
            
        print(f"   ✅ Loaded {len(df)} rows (Direct).")
        return df
        
    except Exception as e2:
        print(f"   ❌ Direct download failed: {e2}")
        print(traceback.format_exc())
        return pd.DataFrame()

def fetch_uci_dataset() -> pd.DataFrame:
    """Download UCI Spam Collection (Zip -> TSV)"""
    print("⬇️ Fetching Supplementary Dataset (UCI)...")
    try:
        # Add User-Agent to avoid 403
        headers = {'User-Agent': 'Mozilla/5.0'}
        r = requests.get(UCI_URL, headers=headers)
        
        if r.status_code != 200:
             print(f"   ❌ UCI fetch failed with status: {r.status_code}")
             return pd.DataFrame()
             
        z = zipfile.ZipFile(io.BytesIO(r.content))
        
        # Files in zip: SMSSpamCollection
        with z.open("SMSSpamCollection") as f:
            df = pd.read_csv(f, sep='\t', header=None, names=["label", "sms_text"])
        
        print(f"   ✅ Loaded {len(df)} rows.")
        return df
    except Exception as e:
        print(f"   ❌ Failed to load UCI dataset: {e}")
        return pd.DataFrame()

def normalize_datasets(df_primary: pd.DataFrame, df_uci: pd.DataFrame) -> pd.DataFrame:
    """Merge and Normalize into [text, label, source, type]"""
    print("🔄 Normalizing & Merging...")
    
    # 1. Process Primary (GandharvBakshi)
    # Columns: sms_text, predicted_is_otp, is_phishing_original
    def categorize_primary(row):
        if row.get('is_phishing_original') == True:
            return "scam"
        if row.get('predicted_is_otp') == True:
            return "otp"
        return "ham"

    df1 = df_primary.copy()
    if not df1.empty:
        df1['type'] = df1.apply(categorize_primary, axis=1)
        df1['source'] = 'hf_gandharvbakshi'
        # Rename sms_text -> text if needed
        if 'sms_text' in df1.columns:
            df1 = df1.rename(columns={'sms_text': 'text'})
        df1 = df1[['text', 'type', 'source']]

    # 2. Process UCI
    df2 = df_uci.copy()
    if not df2.empty:
        df2['type'] = df2['label'].apply(lambda x: 'scam' if str(x).lower() == 'spam' else 'ham')
        df2['source'] = 'uci_spam'
        df2 = df2[['sms_text', 'type', 'source']].rename(columns={'sms_text': 'text'})

    # 3. Merge
    final_df = pd.concat([df1, df2], ignore_index=True)
    print(f"   ✅ Final Merged Size: {len(final_df)} rows")
    print(f"   📊 Breakdown: \n{final_df['type'].value_counts()}")
    
    return final_df

if __name__ == "__main__":
    ensure_dir()
    d1 = fetch_primary_dataset()
    d2 = fetch_uci_dataset()
    
    if not d1.empty and not d2.empty:
        merged = normalize_datasets(d1, d2)
        outfile = f"{RAW_DIR}/merged_base_dataset.csv"
        merged.to_csv(outfile, index=False)
        print(f"💾 Saved to {outfile}")
