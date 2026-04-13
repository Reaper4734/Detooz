# Detooz SLM Model Analysis Report

## 1. Model Selection: MobileBERT
The core detection engine uses **MobileBERT (`google/mobilebert-uncased`)**, a compressed version of the original BERT model optimized for mobile devices. It balances high accuracy with low resource consumption, making it ideal for on-device inference in Flutter.

- **Type**: 3-Class sequence classification.
- **Input**: Sequence of 128 tokens.
- **Output**: Softmax probabilities for **HAM**, **OTP**, and **SCAM**.
- **Model Size**: ~49.2 MB (TFLite format).

## 2. Training Data & Pipeline
The model is trained on a comprehensive dataset of **93,267 samples**, specifically curated for the Indian context:

- **Data Sources**:
    - **Clean Data**: Human-labeled SMS datasets from HuggingFace and UCI.
    - **Synthetic Data**: AI-augmented samples created to simulate modern scam tactics (Job scams, KYC updates, etc.) that may be under-represented in older datasets.
- **Class Labels**:
    - `0 (HAM)`: Legitimate, safe messages.
    - `1 (OTP)`: Critical OTP messages (ensures 100% recall to avoid blocking banking tasks).
    - `2 (SCAM)`: Malicious or phishing messages.

## 3. Performance Metrics (Feb 2026 Refresh)
The model underwent a complete refresh in early 2026, achieving state-of-the-art performance for its size:

| Metric | Value |
|--------|-------|
| **Accuracy** | **99.06%** |
| **HAM F1-Score** | 0.98 |
| **OTP Recall** | **1.00** |
| **SCAM Precision** | 0.99 |

### Confusion Matrix Insights:
Out of 34,068 test samples, there were only **311 misclassifications**. Notably, the model has a perfect recall for OTPs, ensuring that users never miss critical login codes due to false positives.

## 4. On-Device Optimization
- **Quantization**: The TFLite model is optimized for mobile CPUs/NPUs, ensuring latency stays between **100ms and 200ms**.
- **Tokenizer**: Uses a custom **WordPiece** tokenizer implemented in Dart to match the backend's PyTorch/Transformers implementation perfectly.
- **Offline Capability**: Once the ~50MB model is downloaded via the app's Permission Wizard, the detection layer is **100% offline**, protecting user privacy without sending SMS content to the cloud for every scan.

## 5. Hybrid Fallback (Cloud AI)
While the MobileBERT model handles 95%+ of cases, the system includes a "Hybrid Shield" logic:
- If MobileBERT's confidence score is below a certain threshold (e.g., <0.8), the message is flagged for **Cloud Analysis** (via Groq Llama 3.3).
- This ensures that complex, new scam tactics not present in the training data are still caught by a larger, more powerful model.
