"""
TFLite Converter
Converts the saved HuggingFace model -> TFLite for Android.
Uses TFLiteConverter with FP16 quantization.
"""
import tensorflow as tf
from transformers import TFMobileBertForSequenceClassification
import os

MODEL_DIR = "ml_pipeline/saved_model"
OUTPUT_FILE = "ml_pipeline/scam_detector.tflite"

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

    # Create concrete function
    callable = tf.function(lambda input_ids, attention_mask: model(
        input_ids=input_ids, attention_mask=attention_mask
    ).logits)
    
    # Define input specs (Sequence Length 128)
    concrete_func = callable.get_concrete_function(
        tf.TensorSpec([1, 128], tf.int32, name="input_ids"),
        tf.TensorSpec([1, 128], tf.int32, name="attention_mask")
    )

    print("   ⚖️  Quantizing & Converting...")
    converter = tf.lite.TFLiteConverter.from_concrete_functions([concrete_func])
    
    # Optimization: FP16
    converter.optimizations = [tf.lite.Optimize.DEFAULT]
    converter.target_spec.supported_types = [tf.float16]
    
    tflite_model = converter.convert()

    # Save
    with open(OUTPUT_FILE, "wb") as f:
        f.write(tflite_model)
        
    print(f"✅ Conversion Complete! Saved to {OUTPUT_FILE}")
    print(f"   Size: {len(tflite_model) / 1024 / 1024:.2f} MB")

if __name__ == "__main__":
    convert_model()
