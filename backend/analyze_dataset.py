# -*- coding: utf-8 -*-
import pandas as pd

final = pd.read_csv('ml_pipeline/data/en_hinglish/final_training_set.csv')

with open('dataset_report.txt', 'w', encoding='utf-8') as f:
    f.write('=== DATASET QUALITY ANALYSIS ===\n')
    f.write(f'Total samples: {len(final)}\n\n')
    
    f.write('--- Class Distribution ---\n')
    dist = final['type'].value_counts()
    for k, v in dist.items():
        f.write(f'{k}: {v}\n')
    f.write(f'Balance Ratio: {dist.min()/dist.max():.1%}\n\n')
    
    f.write('--- Quality Issues ---\n')
    final['tlen'] = final['text'].astype(str).str.len()
    f.write(f'Short texts (<10 chars): {len(final[final["tlen"]<10])}\n')
    f.write(f'Duplicates: {final["text"].duplicated().sum()}\n')
    f.write(f'Nulls: {final["text"].isnull().sum()}\n\n')
    
    f.write('--- Source Distribution ---\n')
    src = final['source'].value_counts()
    for k, v in src.items():
        f.write(f'{k}: {v}\n')
    
    f.write('\n--- Emotional Keywords (HAM vs SCAM count) ---\n')
    keywords = ['help','urgent','emergency','hospital','money','mom','dad','mummy','papa','police','accident','trouble']
    for kw in keywords:
        h = len(final[(final['type']=='ham') & (final['text'].astype(str).str.lower().str.contains(kw, na=False))])
        s = len(final[(final['type']=='scam') & (final['text'].astype(str).str.lower().str.contains(kw, na=False))])
        if h>0 or s>0: 
            f.write(f'{kw}: HAM={h}, SCAM={s}\n')
    
    # Check for Indian language content
    f.write('\n--- Language Analysis ---\n')
    hindi_pattern = r'[\u0900-\u097F]'  # Devanagari script
    hindi_count = final['text'].astype(str).str.contains(hindi_pattern, regex=True, na=False).sum()
    f.write(f'Contains Hindi (Devanagari): {hindi_count}\n')
    
    # Hinglish patterns
    hinglish_words = ['kya', 'hai', 'nahi', 'karo', 'bhai', 'yaar', 'aap', 'tum', 'mujhe', 'paisa']
    hinglish_count = 0
    for w in hinglish_words:
        hinglish_count += final['text'].astype(str).str.lower().str.contains(w, na=False).sum()
    f.write(f'Contains Hinglish words: {hinglish_count}\n')

print('Report saved to dataset_report.txt')
