import pandas as pd

final = pd.read_csv('ml_pipeline/data/en_hinglish/final_training_set.csv')
synthetic = pd.read_csv('ml_pipeline/data/en_hinglish/raw_data/synthetic_augment.csv')

print(f"Final: {len(final)}")
print(f"Synthetic: {len(synthetic)}")

overlap = set(final['text'].dropna()) & set(synthetic['text'].dropna())
print(f"Overlap: {len(overlap)}")
print(f"Unique in final (excluding synthetic): {len(set(final['text'].dropna()) - set(synthetic['text'].dropna()))}")
