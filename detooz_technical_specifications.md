# Detooz Technical Specifications
## AI-Powered Scam Detection Platform for India

*Last Updated: February 2026*
*Document generated from source code analysis*

---

## 1. Executive Summary

### Problem Statement
- India has 1.2+ billion mobile users receiving billions of SMS messages daily
- Scammers exploit urgency tactics, multilingual messages, and impersonation
- Victims often lack technical knowledge to identify sophisticated scams
- Existing solutions don't adequately support Indian regional languages

### Solution: Hybrid Shield Architecture
Three-tier detection system combining speed, accuracy, and offline capability:
1. **Tier 1 - Pattern Matching**: Instant regex-based detection (<10ms)
2. **Tier 2 - On-Device ML**: MobileBERT TFLite model (~100-200ms)
3. **Tier 3 - Cloud AI**: Groq Llama 3.3 70B for complex cases (~500-1500ms)

---

## 2. System Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        MOBILE APP (Flutter)                      │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ Notification │  │  On-Device   │  │      UI Layer        │  │
│  │  Listener    │  │  TFLite ML   │  │  (9 Languages)       │  │
│  │(SMS/WA/TG)   │  │  (49MB)      │  │                      │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────────────────┘  │
│         │                  │                                     │
│         └──────────┬───────┴────────────────────────────────────┤
│                    ▼                                             │
│         ┌────────────────────────┐                              │
│         │     Scam Analysis      │                              │
│         │   (Hybrid Detection)   │                              │
│         └──────────┬─────────────┘                              │
└────────────────────┼────────────────────────────────────────────┘
                     │ HTTPS
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                     BACKEND (FastAPI)                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   Pattern    │  │  Local ML    │  │   External APIs      │  │
│  │  Matching    │  │ (MobileBERT) │  │  (Groq, OpenRouter)  │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
│                                                                  │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │   SQLite/    │  │    Redis     │  │   Guardian Alerts    │  │
│  │  PostgreSQL  │  │    Cache     │  │   (FCM + Email)      │  │
│  └──────────────┘  └──────────────┘  └──────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. Technology Stack

### Mobile Application (Flutter)
| Component | Technology | Version |
|-----------|------------|---------|
| SDK | Flutter | ^3.6.0 |
| Language | Dart | ^3.6.0 |
| State Management | Riverpod | 2.6.1 |
| Local Storage | Hive | 2.2.3 |
| Secure Storage | flutter_secure_storage | 9.0.0 |
| HTTP Client | http | 1.2.0 |
| On-Device ML | tflite_flutter | 0.11.0 |
| UI Translation | google_mlkit_translation | 0.13.0 |
| Push Notifications | firebase_messaging | 15.1.6 |
| Auth | firebase_auth: 5.3.3, google_sign_in: 6.2.2 |

### Backend (Python)
| Component | Technology | Version |
|-----------|------------|---------|
| Framework | FastAPI | 1.3.0 |
| Database | SQLite (dev) / PostgreSQL (prod) | - |
| ORM | SQLAlchemy | async |
| Cache | Redis | - |
| Authentication | JWT (HS256) | - |
| ML Runtime | PyTorch, Transformers | - |
| Config | Pydantic Settings | - |

### External Services
| Service | Provider | Usage |
|---------|----------|-------|
| Cloud AI | Groq (Llama 3.3 70B) | Text analysis |
| Image AI | OpenRouter (Gemini/Llama Vision) | Screenshot analysis |
| Push Notifications | Firebase FCM | Guardian alerts |
| SMS OTP | Fast2SMS | Phone verification |
| Email | SMTP | Email OTP |

---

## 4. AI/ML System

### 4.1 Training Dataset

**Source Files:**
- `final_training_set.csv`: 93,267 samples
- `clean_training_set.csv`: 93,152 samples (used for training)

**Data Sources:**
1. **HuggingFace Dataset**: `gandharvbakshi/SMS-dataset-OTP-OTP_INTENT_Phishing`
2. **UCI Spam Collection**: Standard SMS spam corpus

**Data Distribution (3 classes):**
| Class | Description | Label |
|-------|-------------|-------|
| HAM | Safe messages | 0 |
| OTP | Legitimate OTPs | 1 |
| SCAM | Malicious messages | 2 |

**Languages in Dataset:**
- English
- Hindi (Devanagari)
- Bengali (বাংলা)
- Kannada (ಕನ್ನಡ)
- Malayalam (മലയാളം)
- Tamil (தமிழ்)
- Telugu (తెలుగు)
- Mixed code (Hinglish, Tanglish, etc.)

### 4.2 On-Device Model (TFLite)

| Property | Value |
|----------|-------|
| Base Model | `google/mobilebert-uncased` |
| Model Size | 49.2 MB |
| Task | 3-class sequence classification |
| Max Sequence Length | 128 tokens |
| Training Epochs | 2 |
| Batch Size | 16 (train), 64 (eval) |

**Model Evaluation (on 34,068 test samples) — Updated: Feb 2026:**

| Class | Precision | Recall | F1-Score | Support |
|-------|-----------|--------|----------|---------|
| HAM | 0.99 | 0.98 | 0.98 | 10,229 |
| OTP | 0.98 | 1.00 | 0.99 | 399 |
| SCAM | 0.99 | 0.99 | 0.99 | 23,440 |
| **Accuracy** | | | **99.06%** | 34,068 |

**Confusion Matrix:**
| True/Pred | HAM | OTP | SCAM |
|-----------|-----|-----|------|
| HAM | 10,046 | 7 | 176 |
| OTP | 0 | 399 | 0 |
| SCAM | 135 | 1 | 23,304 |

> **Note:** Excellent across all classes. OTP detection is perfect (100% recall). Only 176+135=311 misclassifications out of 34,068 samples.

### 4.3 Cloud AI (Groq)

| Property | Value |
|----------|-------|
| Model | `llama-3.3-70b-versatile` |
| Temperature | 0.1 (low for consistency) |
| Max Tokens | 200 |
| Response Format | JSON |

**Multilingual Support:**
The cloud AI prompt explicitly supports all 22 scheduled Indian languages:

1. Hindi (हिन्दी)
2. Bengali (বাংলা)
3. Telugu (తెలుగు)
4. Marathi (मराठी)
5. Tamil (தமிழ்)
6. Urdu (اردو)
7. Gujarati (ગુજરાતી)
8. Kannada (ಕನ್ನಡ)
9. Odia (ଓଡ଼ିଆ)
10. Malayalam (മലയാളം)
11. Punjabi (ਪੰਜਾਬੀ)
12. Assamese (অসমীয়া)
13. Maithili (मैथिली)
14. Sanskrit (संस्कृतम्)
15. Santali (ᱥᱟᱱᱛᱟᱲᱤ)
16. Nepali (नेपाली)
17. Sindhi (سنڌي)
18. Konkani (कोंकणी)
19. Dogri (डोगरी)
20. Kashmiri (कॉशुर)
21. Manipuri/Meitei (মৈতৈলোন্)
22. Bodo (बड़ो)

### 4.4 Image Analysis

| Property | Value |
|----------|-------|
| Provider | OpenRouter |
| Model | Meta Llama 3.2 11B Vision |
| Use Case | WhatsApp screenshot analysis |
| Input | Base64 encoded image |

---

## 5. Pattern Matching System

### High-Risk Scam Categories (8 types)

| Category | Key Patterns |
|----------|-------------|
| **KYC Scam** | `kyc update/expire/suspend`, `pan/aadhaar link urgent`, `account block` |
| **Prize Scam** | `won lottery/prize`, `claim reward`, `lucky winner` |
| **OTP Theft** | `send me otp`, `share your otp`, `tell me otp` |
| **Job Scam** | `part time job + payment`, `work from home + earn`, `registration fee` |
| **Loan Scam** | `loan approved instantly`, `pre-approved loan`, `processing fee` |
| **Investment Scam** | `guaranteed return`, `double your money`, `100% profit` |
| **Govt Impersonation** | `income tax refund`, `PM Kisan verify`, `govt scheme fee` |
| **Delivery Scam** | `package held + pay fee`, `customs duty`, `parcel held` |

### Medium-Risk Indicators (4 types)

| Category | Patterns |
|----------|----------|
| Suspicious Links | `bit.ly`, `tinyurl`, `short.link` |
| Urgency Tactics | `urgent`, `immediately`, `within 24 hours` |
| Money Keywords | `transfer`, `payment`, `₹ amounts` |
| Verification Requests | `verify now`, `confirm identity` |

---

## 6. App Language Support (UI)

The mobile app UI supports **9 languages** via Google ML Kit Translation:

| Code | Language | Native Name |
|------|----------|-------------|
| en | English | English |
| hi | Hindi | हिन्दी |
| bn | Bengali | বাংলা |
| te | Telugu | తెలుగు |
| mr | Marathi | मराठी |
| ta | Tamil | தமிழ் |
| gu | Gujarati | ગુજરાતી |
| kn | Kannada | ಕನ್ನಡ |
| ur | Urdu | اردو |

> **Note:** Malayalam and Punjabi are NOT supported by ML Kit, hence not available for UI translation.

---

## 7. Notification Listener (Android)

### Monitored Platforms

| Package | Platform |
|---------|----------|
| `com.google.android.apps.messaging` | SMS |
| `com.samsung.android.messaging` | SMS |
| `com.android.mms` | SMS |
| `com.oneplus.mms` | SMS (OnePlus) |
| `com.miui.mms` | SMS (Xiaomi) |
| `com.whatsapp` | WhatsApp |
| `com.whatsapp.w4b` | WhatsApp Business |
| `org.telegram.messenger` | Telegram |

### Privacy Features
- **Contact Filtering**: Messages from saved contacts are automatically skipped
- **Duplicate Prevention**: Recent message cache (200 entries) prevents reprocessing
- **Foreground Service**: Persistent notification ensures reliable background operation

---

## 8. Database Schema

### Core Models (11 tables)

| Model | Purpose |
|-------|---------|
| `User` | User accounts, auth, consent flags |
| `Scan` | Detection results history |
| `TrustedSender` | User-verified safe senders |
| `Feedback` | User corrections for ML improvement |
| `Blacklist` | Crowdsourced scam URLs/numbers |
| `UserSettings` | App preferences, notification config |
| `GuardianLink` | Guardian-user relationships |
| `GuardianAlert` | Alerts sent to guardians |
| `ConsentLog` | GDPR-compliant consent audit trail |
| `FeedArticle` | RSS feed articles |
| `CuratedArticle` | Admin-curated educational content |

### Key User Fields (Privacy-Focused)
```python
# Consent Management
consent_training_data: bool  # Allow data for ML training
consent_analytics: bool      # Allow usage analytics
data_retention_days: int     # User-controlled retention (default: 365)
```

---

## 9. API Endpoints Summary

### Authentication (4 endpoints)
- `POST /api/auth/register` - Email registration
- `POST /api/auth/login` - Email login
- `POST /api/auth/google` - Google OAuth
- `POST /api/auth/otp/*` - Phone OTP flow

### Scam Detection (4 endpoints)
- `POST /api/manual-scan` - Analyze text message
- `POST /api/manual-scan/image` - Analyze screenshot
- `POST /api/sms/analyze` - Automatic SMS analysis
- `POST /api/sms/batch` - Bulk analysis

### Guardian System (6 endpoints)
- `POST /api/guardian/request` - Request to link guardian
- `POST /api/guardian/verify` - Verify link OTP
- `GET /api/guardian/list` - List linked guardians
- `DELETE /api/guardian/{id}` - Remove guardian
- `GET /api/guardian/alerts` - Get alerts received
- `POST /api/guardian/alert` - Send scam alert

### History & Reputation (6 endpoints)
- `GET /api/sms/history` - Scan history
- `POST /api/feedback` - Submit correction
- `GET /api/reputation/check` - Check URL/phone
- `POST /api/reputation/report` - Report scam

---

## 10. Android Permissions

| Permission | Purpose |
|------------|---------|
| `RECEIVE_SMS` | Receive incoming SMS |
| `READ_SMS` | Read SMS content |
| `BIND_NOTIFICATION_LISTENER_SERVICE` | Monitor notifications |
| `READ_CONTACTS` | Skip known contacts |
| `INTERNET` | API communication |
| `FOREGROUND_SERVICE` | Background protection |
| `POST_NOTIFICATIONS` | Scam alerts |
| `SYSTEM_ALERT_WINDOW` | Overlay warnings |

---

## 11. Security Features

| Feature | Implementation |
|---------|----------------|
| Authentication | JWT (HS256), 7-day expiry |
| Token Storage | Flutter Secure Storage (Keychain/Keystore) |
| API Communication | HTTPS only |
| Password Hashing | bcrypt |
| Consent Management | GDPR-compliant, user-controlled |
| Data Anonymization | Anonymous scan option available |

---

## 12. Performance Characteristics

| Operation | Latency | Notes |
|-----------|---------|-------|
| Pattern Matching | <10ms | Instant, offline |
| On-Device TFLite | 100-200ms | Offline capable |
| Groq Cloud AI | 500-1500ms | Network dependent |
| Image Analysis | 2-5s | Network dependent |
| Contact Lookup | ~50ms | Local database |

---

## 13. Key Files Reference

| Path | Description |
|------|-------------|
| `app/lib/services/ml/scam_detector_service.dart` | TFLite inference service |
| `app/lib/services/translation/language_config.dart` | UI language definitions |
| `backend/app/services/scam_detector.py` | Hybrid detection logic |
| `backend/app/services/sms_patterns.py` | Regex pattern database |
| `backend/ml_pipeline/train.py` | Model training script |
| `backend/ml_pipeline/clean_training_set.csv` | Training dataset |
| `app/android/.../SmsNotificationListener.kt` | Android notification service |

---

## 14. Future Improvements (Identified from Code)

1. **Model Performance**: Current 99.06% accuracy is excellent
   - Consider active learning for edge cases
   - Monitor for new scam patterns not in training data
   
2. **Language Coverage**: UI supports 9 of 22 Indian languages
   - Malayalam and Punjabi pending (ML Kit limitation)

3. **iOS Support**: Current notification listener is Android-only
   - iOS requires different approach (CallKit/extensions)

4. **Edge Cases**: 311 misclassifications identified
   - 176 HAM → SCAM (false positives)
   - 135 SCAM → HAM (false negatives to investigate)

---

*Document generated from source code analysis. No external documentation referenced.*
