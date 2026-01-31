"""
TFLite Converter
Converts the saved HuggingFace model -> TFLite for Android.
Uses TFLiteConverter with FP16 quantization.
"""
import tensorflow as tf
from transformers import TFMobileBertForSequenceClassification
import os
import shutil

# Updated path to match training output
MODEL_DIR = "ml_pipeline/data/en_hinglish/saved_model"
OUTPUT_FILE = "ml_pipeline/scam_detector.tflite"
FLUTTER_ASSET = "../app/assets/scam_detector.tflite"

def convert_model():
    print("🚀 Starting TFLite Conversion...")
    
    if not os.path.exists(MODEL_DIR):
        print(f"❌ Model directory not found: {MODEL_DIR}. Run train.py first.")
        return

    print("   🧠 Loading Model (TF version)...")
    try:
        # Load as TF model (HuggingFace auto-converts weights)
        model = TFMobileBertForSequenceClassification.from_pretrained(MODEL_DIR, from_pt=True)
    except Exception as e:
        print(f"   ❌ Failed to load model: {e}")
        print("   (Ensure you have tensorflow installed)")
        return

    # Create concrete function - ONLY input_ids (Flutter doesn't send attention_mask)
    # The model will internally compute attention based on non-padding tokens
    @tf.function(input_signature=[tf.TensorSpec([1, 128], tf.int32, name="input_ids")])
    def predict(input_ids):
        # Create attention mask from input_ids (1 for non-zero, 0 for padding)
        attention_mask = tf.cast(tf.not_equal(input_ids, 0), tf.int32)
        outputs = model(input_ids=input_ids, attention_mask=attention_mask)
        return outputs.logits

    concrete_func = predict.get_concrete_function()

    print("   ⚖️  Quantizing & Converting...")
    converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_func])
    
    # Optimization: FP16
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    
    tflite_model = converter.convert()

    # Save to ml_pipeline
    with open(OUTPUT_FILE, "wb") as f:
        f.write(tflite_model)
        
    print(f"✅ Conversion Complete! Saved to {OUTPUT_FILE}")
    print(f"   Size: {len(tflite_model) / 1024 / 1024:.2f} MB")
    
    # Copy to Flutter assets
    if os.path.exists(os.path.dirname(FLUTTER_ASSET)):
        shutil.copy(OUTPUT_FILE, FLUTTER_ASSET)
        print(f"✅ Copied to Flutter assets: {FLUTTER_ASSET}")

if __name__ == "__main__":
    convert_model()
