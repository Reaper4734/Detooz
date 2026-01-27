# Integration Plan: MobileBERT TFLite for Flutter

## 1. Objective
Deploy the trained `MobileBERT` model (97.15% Accuracy) to the Mobile App for **Offline Scam Detection**.

## 2. Pipeline Overview
1.  **Source**: PyTorch Model (`saved_model`)
2.  **Bridge**: TensorFlow Model (via `from_pt=True`)
3.  **Target**: TFLite Model (`scam_detector.tflite`) with FP16 Quantization.
4.  **Client**: Flutter App (using `tflite_flutter`).

## 3. Conversion & Validation Strategy

### Step 3.1: Conversion
We use the existing script `backend/ml_pipeline/model_training/convert_to_tflite.py`.
*   **Input**: `backend/ml_pipeline/data/en_hinglish/saved_model`
*   **Output**: `backend/ml_pipeline/data/en_hinglish/scam_detector.tflite`
*   **Optimizaton**: FP16 (Reduces size by ~50% with negligible accuracy loss).

### Step 3.2: Desktop Validation (`validate_tflite.py`)
Before moving to the phone, we must verify the TFLite model matches the PyTorch model's predictions.
*   **Method**: Run inference on 100 validation samples using both models.
*   **Metric**: Mean Squared Error (MSE) of logits and Class Agreement %.

## 4. Flutter Integration

### Step 4.1: Assets
*   Copy `scam_detector.tflite` to `frontend/assets/models/`.
*   Copy `vocab.txt` (from tokenizer) to `frontend/assets/models/`.

### Step 4.2: Dependencies
Add to `pubspec.yaml`:
```yaml
dependencies:
  tflite_flutter: ^0.10.4
  # For tokenization (or custom implementation)
  # google_mlkit_text_recognition (optional, but we likely need a custom WordPiece tokenizer)
```

### Step 4.3: Tokenization (The Tricky Part) ⚠️
Python's `MobileBertTokenizer` is not available in Dart. We must replicate the **WordPiece Tokenizer** logic in Dart.
*   **Resources**: We need the `vocab.txt` file from the trained tokenizer.
*   **Logic**:
    1.  Normalize text (Lower case, strip accents).
    2.  Split by whitespace.
    3.  Apply "Max Match" algorithm using `vocab.txt`.
    4.  Map tokens to IDs.
    5.  Pad/Truncate to sequence length (128).

## 5. Rollout Plan

1.  **Run Conversion**: Execute `convert_to_tflite.py`.
2.  **Run Validation**: Execute `validate_tflite.py`.
3.  **Export Vocab**: Extract `vocab.txt` from the saved tokenizer.
4.  **Flutter Impl**: Implement `ScamDetectorService.dart` class.

## 6. Validation Scripts
I will create `validate_tflite.py` to automate Step 3.2.
