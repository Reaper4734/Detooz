# Detooz — Complete Project Raw Information Extraction
**Extracted:** March 3, 2026  
**Purpose:** Source material for video transcript / presentation

---

## 1. PROJECT IDENTITY

| Property | Value |
|----------|-------|
| **Name** | Detooz |
| **Tagline** | AI-Powered Scam Detection Platform for India |
| **Version** | 1.3.0 (Backend API) / 1.0.0+1 (Flutter App) |
| **Target Market** | India — 1.2+ billion mobile users |
| **Problem** | Scammers exploit urgency tactics, multilingual messages, impersonation; victims lack tools for Indian regional languages |
| **Repository** | Private GitHub (with `.github/workflows` CI/CD) |
| **Last Updated** | February 2026 |

---

## 2. HIGH-LEVEL ARCHITECTURE — "HYBRID SHIELD"

Three-tier detection system combining speed, accuracy, and offline capability:

| Tier | Method | Latency | Connectivity |
|------|--------|---------|--------------|
| **Tier 1** | Regex Pattern Matching | <10ms | Offline ✅ |
| **Tier 2** | On-Device ML (MobileBERT TFLite) | 100–200ms | Offline ✅ |
| **Tier 3** | Cloud AI (Groq Llama 3.3 70B) | 500–1500ms | Online only |

**Image Analysis:** OpenRouter (Meta Llama 3.2 11B Vision) — for WhatsApp screenshot analysis (2–5s, online).

---

## 3. COMPLETE DIRECTORY TREE

```
Detooz/
├── app/                          # Flutter Mobile App (183 children)
│   ├── lib/
│   │   ├── main.dart             # App entry point (88 lines)
│   │   ├── contracts/            # Data models
│   │   │   ├── article.dart
│   │   │   ├── guardian_view_model.dart
│   │   │   ├── risk_level.dart
│   │   │   └── scan_view_model.dart
│   │   ├── services/             # Backend services (13 files + 2 subdirs)
│   │   │   ├── ai_service.dart               # Hybrid AI orchestration
│   │   │   ├── api_service.dart              # HTTP API client (31KB — largest service)
│   │   │   ├── connectivity_service.dart     # Online/offline detection
│   │   │   ├── education_service.dart        # Scam awareness content
│   │   │   ├── firebase_messaging_service.dart  # Push notifications (FCM)
│   │   │   ├── google_auth_service.dart      # Google OAuth sign-in
│   │   │   ├── notification_service.dart     # Local push notifications
│   │   │   ├── offline_cache_service.dart    # Hive-based offline cache
│   │   │   ├── phone_auth_service.dart       # Phone OTP authentication
│   │   │   ├── sms_receiver_service.dart     # SMS interception (14KB)
│   │   │   ├── sms_sender_service.dart       # Guardian SMS alerts
│   │   │   ├── ml/                           # On-device ML pipeline
│   │   │   │   ├── scam_detector_service.dart   # TFLite inference (main)
│   │   │   │   ├── basic_tokenizer.dart         # Text preprocessing
│   │   │   │   ├── wordpiece_tokenizer.dart     # WordPiece tokenization
│   │   │   │   ├── token_encoder.dart           # Token to ID encoding
│   │   │   │   ├── vocab_loader.dart            # BERT vocabulary loader
│   │   │   │   ├── sms_translator.dart          # Multi-language SMS translation
│   │   │   │   ├── state_language_map.dart       # Indian state ↔ language mapping
│   │   │   │   └── TOKENIZER_PLAN.md            # Tokenizer implementation plan
│   │   │   └── translation/
│   │   │       ├── language_config.dart       # Supported UI languages (9)
│   │   │       └── translation_service.dart   # ML Kit translation engine
│   │   ├── ui/
│   │   │   ├── providers.dart                # Riverpod state management (28KB)
│   │   │   ├── providers/
│   │   │   │   └── education_provider.dart
│   │   │   ├── components/                   # 8 reusable widgets
│   │   │   │   ├── bottom_nav_bar.dart
│   │   │   │   ├── offline_aware_widget.dart
│   │   │   │   ├── platform_icon.dart
│   │   │   │   ├── risk_badge.dart
│   │   │   │   ├── scam_alert_overlay.dart
│   │   │   │   ├── scan_card.dart
│   │   │   │   ├── tr.dart                   # Translation widget (Tr, tr, TrBuilder)
│   │   │   │   └── verification_info_card.dart
│   │   │   ├── screens/                      # 22 screens + 1 admin folder
│   │   │   │   ├── login_screen.dart             # 38KB (largest screen)
│   │   │   │   ├── dashboard_screen.dart         # 34KB — main dashboard
│   │   │   │   ├── education_screen.dart         # 25KB
│   │   │   │   ├── guardians_screen.dart         # 24KB
│   │   │   │   ├── edit_profile_screen.dart       # 22KB
│   │   │   │   ├── privacy_security_screen.dart   # 21KB
│   │   │   │   ├── settings_screen.dart           # 21KB
│   │   │   │   ├── scan_detail_screen.dart        # 20KB
│   │   │   │   ├── model_download_screen.dart     # 19KB
│   │   │   │   ├── language_selector_screen.dart   # 16KB
│   │   │   │   ├── manual_result_screen.dart       # 16KB
│   │   │   │   ├── history_screen.dart             # 14KB
│   │   │   │   ├── feed_screen.dart                # 12KB
│   │   │   │   ├── setup_offline_protection_screen.dart # 12KB
│   │   │   │   ├── otp_verification_screen.dart    # 11KB
│   │   │   │   ├── forgot_password_screen.dart     # 10KB
│   │   │   │   ├── language_manager_screen.dart     # 9.5KB
│   │   │   │   ├── permission_wizard_screen.dart    # 8.5KB
│   │   │   │   ├── bookmarks_screen.dart            # 7KB
│   │   │   │   ├── article_webview.dart             # 5KB
│   │   │   │   ├── main_screen.dart                 # 1.8KB (nav container)
│   │   │   │   └── admin/
│   │   │   │       ├── admin_dashboard_screen.dart  # 19KB
│   │   │   │       └── admin_login_screen.dart      # 7KB
│   │   │   └── theme/                        # 5 theme files
│   │   │       ├── app_theme.dart
│   │   │       ├── app_colors.dart
│   │   │       ├── app_typography.dart
│   │   │       ├── app_spacing.dart
│   │   │       └── theme_provider.dart
│   │   └── utils/                            # 1 utility file
│   ├── test/                                 # 7 unit tests
│   │   ├── basic_tokenizer_test.dart
│   │   ├── connectivity_service_test.dart
│   │   ├── detection_result_test.dart
│   │   ├── offline_cache_service_test.dart
│   │   ├── scan_view_model_test.dart
│   │   ├── tokenizer_test.dart
│   │   └── widget_test.dart
│   ├── integration_test/                     # 5 integration tests
│   │   ├── direct_test.dart
│   │   ├── inference_debug_test.dart
│   │   ├── minimal_debug_test.dart
│   │   ├── offline_model_test.dart
│   │   └── tokenizer_debug_test.dart
│   ├── android/                              # Android platform config
│   ├── ios/                                  # iOS platform config
│   ├── assets/
│   │   ├── scam_detector.tflite              # On-device ML model
│   │   └── vocab.txt                         # BERT vocabulary
│   ├── pubspec.yaml                          # 30+ dependencies
│   └── analysis_options.yaml
│
├── backend/                      # Python FastAPI Backend (133 children)
│   ├── app/
│   │   ├── main.py               # FastAPI app entry (141 lines)
│   │   ├── config.py             # Pydantic settings (68 lines)
│   │   ├── core/                 # 1 file (auth middleware)
│   │   ├── db/
│   │   │   ├── database.py       # Async SQLAlchemy engine
│   │   │   └── migrations.py     # Schema migrations
│   │   ├── models/
│   │   │   └── models.py         # 11 SQLAlchemy ORM models (14KB)
│   │   ├── schemas/
│   │   │   └── schemas.py        # Pydantic request/response schemas
│   │   ├── routers/              # 15 API route modules
│   │   │   ├── auth.py               # Email registration & login
│   │   │   ├── auth_otp.py           # Phone OTP flow
│   │   │   ├── auth_google.py        # Google OAuth
│   │   │   ├── scan.py               # Auto scam detection
│   │   │   ├── sms.py                # SMS analysis (14KB)
│   │   │   ├── manual_scan.py        # Manual text/image scan (11KB)
│   │   │   ├── user.py               # User profile CRUD (19KB — largest)
│   │   │   ├── feedback.py           # ML feedback loop
│   │   │   ├── reputation.py         # URL/phone reputation DB
│   │   │   ├── trusted_sender.py     # Trusted sender management
│   │   │   ├── guardian_link.py      # Guardian linking system
│   │   │   ├── guardian_alerts.py    # Guardian alert dispatch
│   │   │   ├── admin.py              # Admin dashboard APIs
│   │   │   ├── privacy.py            # GDPR privacy/consent
│   │   │   └── education.py          # Scam awareness content
│   │   ├── services/             # 14 backend services
│   │   │   ├── scam_detector.py       # Hybrid detection engine (21KB — core!)
│   │   │   ├── sms_patterns.py        # Regex pattern database (10KB)
│   │   │   ├── explanation_engine.py  # Human-readable scam explanations
│   │   │   ├── feed_aggregator.py     # RSS feed syncing
│   │   │   ├── fcm_service.py         # Firebase Cloud Messaging
│   │   │   ├── otp_service.py         # OTP generation & delivery
│   │   │   ├── confidence_scorer.py   # Scam confidence calculation
│   │   │   ├── blacklist_manager.py   # Crowdsourced scam database
│   │   │   ├── content_curator.py     # Content curation engine
│   │   │   ├── url_scraper.py         # URL safety checking
│   │   │   ├── guardian_alert_service.py  # Alert dispatch logic
│   │   │   ├── firebase_service.py    # Firebase admin SDK
│   │   │   ├── cache_service.py       # Redis caching layer
│   │   │   └── archiver.py            # Data archival
│   │   └── static/uploads/       # User-uploaded images
│   ├── ml_pipeline/              # ML Training Pipeline (41 children)
│   │   ├── train.py              # Model training script
│   │   ├── pipeline.py           # Pipeline orchestrator
│   │   ├── data_fetcher.py       # Dataset downloading
│   │   ├── data_analysis.py      # Dataset statistics
│   │   ├── synthetic_gen.py      # Synthetic data generation
│   │   ├── convert_to_tflite.py  # PyTorch → TFLite conversion
│   │   ├── validate_tflite.py    # TFLite model validation
│   │   ├── evaluate_metrics.py   # Precision/recall/F1 evaluation
│   │   ├── clean_training_set.csv   # 93,152 training samples (13.5MB)
│   │   ├── final_training_set.csv   # 93,267 total samples (13.5MB)
│   │   ├── scam_detector.tflite     # Trained model file (49.2MB)
│   │   ├── saved_model/             # PyTorch saved model
│   │   ├── model_training/          # Training configs
│   │   ├── data_generation/         # Synthetic data scripts
│   │   └── data_sourcing/           # Data source configs
│   ├── tests/                    # 10 backend test modules
│   │   ├── conftest.py
│   │   ├── test_auth.py
│   │   ├── test_feedback.py
│   │   ├── test_guardian.py
│   │   ├── test_manual_scan.py
│   │   ├── test_reputation.py
│   │   ├── test_scan.py
│   │   ├── test_services.py
│   │   ├── test_sms.py
│   │   ├── test_trusted_sender.py
│   │   └── test_user.py
│   ├── scripts/                  # 5 utility scripts
│   │   ├── check_db.py
│   │   ├── check_guardians.py
│   │   ├── check_guardians_sync.py
│   │   ├── list_gemini_models.py
│   │   └── migrate_db.py
│   ├── storage/archives/         # Data archival storage
│   ├── Dockerfile                # Python 3.11-slim, non-root, healthcheck
│   ├── docker-compose.yml        # Single-service with SQLite volume
│   ├── requirements.txt          # 20 Python dependencies
│   ├── .env / .env.example       # Environment configuration
│   ├── detooz.db                 # SQLite database (217KB)
│   └── firebase-service-account.json  # Firebase admin credentials
│
├── docs/                         # Documentation (16 children)
│   ├── INSTALLATION_GUIDE.md
│   ├── cloud_cicd_plan.md
│   ├── otp_auth_plan.md
│   ├── database_diagram.html     # Interactive DB diagram (46KB)
│   ├── model_perfection_plan/    # 8 files — ML improvement plans
│   ├── doc-gen/                  # Documentation generation
│   ├── dataset_analysis.txt
│   ├── dataset_report.txt
│   ├── model_test_results.txt
│   └── *.log                     # Backend log files
│
├── monitoring/
│   └── monitor.py                # Backend health monitoring (13KB)
│
├── deploy.ps1                    # PowerShell deployment script
├── pull.ps1                      # PowerShell pull/update script
├── detooz-key.pem                # EC2 SSH key
├── detooz_technical_specifications.md  # Full tech specs (404 lines)
└── .gitignore
```

---

## 4. TECHNOLOGY STACK (DETAILED)

### 4.1 Flutter Mobile App

| Category | Package | Version | Purpose |
|----------|---------|---------|---------|
| **Framework** | Flutter SDK | ^3.6.0 | Cross-platform mobile |
| **Language** | Dart SDK | ^3.6.0 | |
| **State Mgmt** | flutter_riverpod | ^2.6.1 | Reactive state management |
| **HTTP** | http | ^1.2.0 | REST API client |
| **Auth** | firebase_auth | ^6.1.4 | Phone OTP auth |
| **Auth** | google_sign_in | ^7.2.0 | Google OAuth |
| **Auth** | firebase_core | ^4.4.0 | Firebase SDK base |
| **Push** | firebase_messaging | ^16.1.1 | FCM push notifications |
| **Notifications** | flutter_local_notifications | ^20.1.0 | Local push alerts |
| **Storage** | hive / hive_flutter | ^2.2.3 / ^1.1.0 | Offline NoSQL cache |
| **Secure Storage** | flutter_secure_storage | ^10.0.0 | Encrypted token storage |
| **ML** | tflite_flutter | ^0.12.1 | On-device inference |
| **Translation** | google_mlkit_translation | ^0.13.0 | Dynamic UI translation |
| **Language ID** | google_mlkit_language_id | ^0.13.1 | Message language detection |
| **Connectivity** | connectivity_plus | ^7.0.0 | Online/offline awareness |
| **UI** | google_fonts | ^8.0.2 | Typography |
| **UI** | cupertino_icons | ^1.0.8 | iOS-style icons |
| **OTP UI** | pin_code_fields | ^9.0.0 | OTP input widget |
| **Phone** | country_code_picker | ^3.0.0 | International dialing codes |
| **SMS** | flutter_sms | ^3.0.0 | Direct SMS sending |
| **Permissions** | permission_handler | ^12.0.1 | Runtime permissions |
| **Biometric** | local_auth | ^3.0.0 | Fingerprint/face auth |
| **Sharing** | share_plus | ^10.1.4 | Share scam reports |
| **Web** | webview_flutter | ^4.7.0 | In-app article viewing |
| **URLs** | url_launcher | ^6.3.2 | External link opening |
| **Images** | image_picker / image_cropper | ^1.0.7 / ^11.0.0 | Profile photo |
| **Crypto** | crypto | ^3.0.7 | Hashing utilities |
| **i18n** | intl | ^0.20.2 | Internationalization |
| **Files** | path_provider | ^2.1.2 | File system access |
| **Prefs** | shared_preferences | ^2.5.4 | Simple key-value storage |
| **Text** | diacritic | any | Diacritics handling |

**Dev Dependencies:** flutter_test, flutter_lints (^6.0.0), mockito (^5.6.3), build_runner (^2.11.1)

### 4.2 Python Backend

| Category | Package | Version | Purpose |
|----------|---------|---------|---------|
| **Framework** | FastAPI | ≥0.129.0 | Async REST API |
| **Server** | Uvicorn | ≥0.41.0 | ASGI server |
| **ORM** | SQLAlchemy | ≥2.0.46 | Async ORM |
| **DB Driver** | aiosqlite | ≥0.22.0 | Async SQLite |
| **Validation** | Pydantic | ≥2.12.0 | Data validation |
| **Settings** | pydantic-settings | ≥2.13.0 | Environment config |
| **Auth** | python-jose[cryptography] | ≥3.5.0 | JWT tokens |
| **Auth** | bcrypt | ≥5.0.0 | Password hashing |
| **Firebase** | firebase-admin | ≥7.1.0 | FCM, auth verification |
| **AI** | groq | ≥1.0.0 | Groq API client |
| **AI** | openai | ≥2.21.0 | OpenRouter client |
| **HTTP** | httpx | ≥0.28.0 | Async HTTP client |
| **HTTP** | aiohttp | ≥3.13.0 | Async HTTP |
| **HTTP** | requests | ≥2.32.0 | Sync HTTP |
| **Scraping** | beautifulsoup4 | ≥4.14.0 | HTML parsing |
| **RSS** | feedparser | ≥6.0.12 | RSS feed parsing |
| **Cache** | redis | ≥7.2.0 | Redis client |
| **Email** | email-validator | ≥2.0.0 | Email validation |
| **Config** | python-dotenv | ≥1.0.0 | .env file loading |
| **Forms** | python-multipart | ≥0.0.6 | File upload parsing |

### 4.3 External Services

| Service | Provider | Model/API | Usage |
|---------|----------|-----------|-------|
| **Cloud AI (Text)** | Groq | Llama 3.3 70B Versatile | Complex scam text analysis |
| **Cloud AI (Image)** | OpenRouter | Meta Llama 3.2 11B Vision | Screenshot analysis |
| **Push Notifications** | Firebase | FCM | Guardian alerts, scam warnings |
| **Phone Auth** | Firebase | Phone Auth | OTP via Firebase |
| **SMS OTP** | Fast2SMS | REST API | Phone verification (10 free/day) |
| **Email OTP** | SMTP | Gmail SMTP | Email verification |
| **WhatsApp Alerts** | CallMeBot | Free API | Guardian WhatsApp alerts |
| **Telegram Alerts** | Telegram Bot API | BotFather | Guardian Telegram alerts |
| **Translation** | Google ML Kit | On-device | UI translation (9 languages) |

---

## 5. AI / ML SYSTEM (RAW DETAILS)

### 5.1 Training Dataset

- **Source 1:** HuggingFace `gandharvbakshi/SMS-dataset-OTP-OTP_INTENT_Phishing`
- **Source 2:** UCI Spam Collection (standard SMS spam corpus)
- **Total samples:** 93,267 (raw) → 93,152 (cleaned)
- **File:** `final_training_set.csv` (13.5 MB)
- **3-Class Distribution:**
  - Class 0 = HAM (safe messages)
  - Class 1 = OTP (legitimate one-time passwords)
  - Class 2 = SCAM (malicious messages)
- **Languages in data:** English, Hindi, Bengali, Kannada, Malayalam, Tamil, Telugu, mixed code (Hinglish, Tanglish, etc.)

### 5.2 On-Device Model (TFLite)

| Property | Value |
|----------|-------|
| Base Model | `google/mobilebert-uncased` |
| File Size | 49.2 MB |
| Task | 3-class sequence classification (HAM/OTP/SCAM) |
| Max Sequence Length | 128 tokens |
| Training Epochs | 2 |
| Batch Size | 16 (train), 64 (eval) |
| Test Set Size | 34,068 samples |
| **Overall Accuracy** | **99.06%** |
| HAM Precision/Recall/F1 | 0.99 / 0.98 / 0.98 |
| OTP Precision/Recall/F1 | 0.98 / 1.00 / 0.99 |
| SCAM Precision/Recall/F1 | 0.99 / 0.99 / 0.99 |
| Total Misclassifications | 311 out of 34,068 (0.91%) |
| OTP Detection | **Perfect** — 100% recall, 0 missed |

**Confusion Matrix:**
| True \ Predicted | HAM | OTP | SCAM |
|------------------|-----|-----|------|
| HAM | 10,046 | 7 | 176 |
| OTP | 0 | 399 | 0 |
| SCAM | 135 | 1 | 23,304 |

### 5.3 Cloud AI (Groq)

| Property | Value |
|----------|-------|
| Model | `llama-3.3-70b-versatile` |
| Temperature | 0.1 (low variance) |
| Max Tokens | 200 |
| Response Format | JSON |
| Language Support | All 22 official Indian scheduled languages |

### 5.4 On-Device Tokenizer Pipeline (Dart)

Custom MobileBERT-compatible tokenizer implemented in Dart:
1. `vocab_loader.dart` — Loads BERT vocabulary file (30,522 tokens)
2. `basic_tokenizer.dart` — Lowercasing, punctuation splitting, whitespace tokenization
3. `wordpiece_tokenizer.dart` — WordPiece subword tokenization
4. `token_encoder.dart` — Converts tokens to input IDs, attention masks, token type IDs
5. `scam_detector_service.dart` — Runs TFLite inference with softmax output

### 5.5 Pattern Matching System (Regex)

**8 High-Risk Scam Categories:**
1. KYC Scam — `kyc update/expire/suspend`, `pan/aadhaar link urgent`, `account block`
2. Prize Scam — `won lottery/prize`, `claim reward`, `lucky winner`
3. OTP Theft — `send me otp`, `share your otp`, `tell me otp`
4. Job Scam — `part time job + payment`, `work from home + earn`, `registration fee`
5. Loan Scam — `loan approved instantly`, `pre-approved loan`, `processing fee`
6. Investment Scam — `guaranteed return`, `double your money`, `100% profit`
7. Govt Impersonation — `income tax refund`, `PM Kisan verify`, `govt scheme fee`
8. Delivery Scam — `package held + pay fee`, `customs duty`, `parcel held`

**4 Medium-Risk Indicators:**
- Suspicious shortened links (bit.ly, tinyurl, short.link)
- Urgency tactics (urgent, immediately, within 24 hours)
- Money keywords (transfer, payment, ₹ amounts)
- Verification requests (verify now, confirm identity)

---

## 6. APP SCREENS (22 SCREENS + 2 ADMIN)

| # | Screen | File | Size | Purpose |
|---|--------|------|------|---------|
| 1 | Login | login_screen.dart | 38KB | Email/password, Google Sign-In, Phone OTP |
| 2 | Dashboard | dashboard_screen.dart | 34KB | Main hub — recent scans, stats, quick actions |
| 3 | Education | education_screen.dart | 25KB | Scam awareness articles & guides |
| 4 | Guardians | guardians_screen.dart | 24KB | Link/manage guardians, alert settings |
| 5 | Edit Profile | edit_profile_screen.dart | 22KB | Update name, photo, personal info |
| 6 | Privacy & Security | privacy_security_screen.dart | 21KB | Biometric lock, consent toggles, data controls |
| 7 | Settings | settings_screen.dart | 21KB | Theme, language, notification preferences |
| 8 | Scan Detail | scan_detail_screen.dart | 20KB | Detailed analysis of a scanned message |
| 9 | Model Download | model_download_screen.dart | 19KB | Download/update TFLite model |
| 10 | Language Selector | language_selector_screen.dart | 16KB | Choose app UI language (9 options) |
| 11 | Manual Result | manual_result_screen.dart | 16KB | Results of manual text/image scan |
| 12 | History | history_screen.dart | 14KB | All past scan results |
| 13 | News Feed | feed_screen.dart | 12KB | RSS-aggregated scam news |
| 14 | Offline Setup | setup_offline_protection_screen.dart | 12KB | Configure offline ML protection |
| 15 | OTP Verification | otp_verification_screen.dart | 11KB | Enter OTP code (PIN fields UI) |
| 16 | Forgot Password | forgot_password_screen.dart | 10KB | Password reset via email OTP |
| 17 | Language Manager | language_manager_screen.dart | 9.5KB | Download/manage translation models |
| 18 | Permission Wizard | permission_wizard_screen.dart | 8.5KB | Guide users through SMS/contact/notification permissions |
| 19 | Bookmarks | bookmarks_screen.dart | 7KB | Saved articles & content |
| 20 | Article WebView | article_webview.dart | 5KB | In-app web article viewer |
| 21 | Main Screen | main_screen.dart | 1.8KB | Bottom nav container |
| 22 | Admin Dashboard | admin/admin_dashboard_screen.dart | 19KB | Admin analytics & management |
| 23 | Admin Login | admin/admin_login_screen.dart | 7KB | Admin authentication |

---

## 7. REUSABLE COMPONENTS (8)

| Component | File | Purpose |
|-----------|------|---------|
| Bottom Nav Bar | bottom_nav_bar.dart | App navigation (Dashboard, History, Education, Settings) |
| Offline-Aware Widget | offline_aware_widget.dart | Shows offline/online status banners |
| Platform Icon | platform_icon.dart | SMS/WhatsApp/Telegram icons |
| Risk Badge | risk_badge.dart | Color-coded risk level indicators |
| Scam Alert Overlay | scam_alert_overlay.dart | Full-screen scam warning overlay |
| Scan Card | scan_card.dart | Scan result summary card |
| Translation Widget | tr.dart | `Tr()` and `tr()` for translated text |
| Verification Info Card | verification_info_card.dart | Sender verification display |

---

## 8. API ENDPOINTS (COMPLETE LIST)

### Authentication (Prefix: `/api/auth`)
| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/register` | Email registration |
| POST | `/login` | Email/password login |
| POST | `/google` | Google OAuth authentication |
| POST | `/otp/*` | Phone OTP flow (send, verify) |

### Scam Detection (Prefix: `/api/scan`, `/api/sms`, `/api/manual`)
| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/scan/` | Auto scam detection |
| POST | `/api/sms/analyze` | Automatic SMS analysis |
| POST | `/api/sms/batch` | Bulk SMS analysis |
| POST | `/api/manual/` | Manual text scan |
| POST | `/api/manual/image` | Screenshot analysis |

### Guardian System (Prefix: `/api/guardian-link`, `/api/guardian-alerts`)
| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/guardian-link/request` | Request to link guardian |
| POST | `/api/guardian-link/verify` | Verify link OTP |
| GET | `/api/guardian-link/list` | List linked guardians |
| DELETE | `/api/guardian-link/{id}` | Remove guardian |
| GET | `/api/guardian-alerts/` | Get alerts received |
| POST | `/api/guardian-alerts/` | Send scam alert |

### User & Profile (Prefix: `/api/user`)
| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/user/profile` | Get user profile |
| PUT | `/api/user/profile` | Update profile |
| PUT | `/api/user/avatar` | Upload profile photo |
| etc. | ... | Full CRUD (19KB router — largest) |

### Feedback & Reputation (Prefix: `/api/feedback`, `/api/reputation`)
| Method | Endpoint | Purpose |
|--------|----------|---------|
| POST | `/api/feedback/` | Submit ML correction |
| GET | `/api/reputation/check` | Check URL/phone reputation |
| POST | `/api/reputation/report` | Report scam source |

### Privacy & Consent (Prefix: `/api/privacy`)
| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET/PUT | `/api/privacy/consent` | Manage GDPR consent |
| DELETE | `/api/privacy/data` | Delete user data |

### Education (Prefix: `/api`)
| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/api/education/feed` | Get news articles |
| GET | `/api/education/curated` | Get curated content |

### Trusted Senders (Prefix: `/api/trusted`)
| Method | Endpoint | Purpose |
|--------|----------|---------|
| CRUD | `/api/trusted/*` | Manage trusted sender list |

### Admin (Prefix: `/api/admin`)
| Method | Endpoint | Purpose |
|--------|----------|---------|
| Various | `/api/admin/*` | Admin dashboard operations |

### Health
| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/` | Root — API running confirmation |
| GET | `/health` | Health check (includes Redis status) |

---

## 9. DATABASE SCHEMA (11 MODELS)

| Model | Table | Key Purpose |
|-------|-------|-------------|
| `User` | users | Accounts, auth method, consent flags, avatar |
| `Scan` | scans | Detection results (tier, confidence, risk_level, platform) |
| `TrustedSender` | trusted_senders | User-verified safe senders |
| `Feedback` | feedback | User corrections for ML retraining |
| `Blacklist` | blacklist | Crowdsourced scam URLs/numbers/emails |
| `UserSettings` | user_settings | Notification prefs, theme, language |
| `GuardianLink` | guardian_links | Guardian-user relationships |
| `GuardianAlert` | guardian_alerts | Dispatched guardian alerts |
| `ConsentLog` | consent_logs | GDPR audit trail |
| `FeedArticle` | feed_articles | RSS-sourced news articles |
| `CuratedArticle` | curated_articles | Admin-curated educational content |
| `UserBookmark` | user_bookmarks | User's saved articles |

**Privacy-centric fields on User:**
- `consent_training_data` (bool) — Allow data for ML training
- `consent_analytics` (bool) — Allow usage analytics
- `data_retention_days` (int) — User-controlled retention (default: 365)

---

## 10. NOTIFICATION LISTENER (ANDROID)

### Monitored Messaging Platforms (8 apps)
| Package Name | Platform |
|-------------|----------|
| `com.google.android.apps.messaging` | Google SMS |
| `com.samsung.android.messaging` | Samsung SMS |
| `com.android.mms` | Default MMS |
| `com.oneplus.mms` | OnePlus SMS |
| `com.miui.mms` | Xiaomi SMS |
| `com.whatsapp` | WhatsApp |
| `com.whatsapp.w4b` | WhatsApp Business |
| `org.telegram.messenger` | Telegram |

### Privacy Features
- Contact filtering — messages from saved contacts auto-skipped
- Duplicate prevention — 200-entry recent message cache
- Foreground service — persistent notification for reliability

### Required Android Permissions (8)
1. `RECEIVE_SMS` — Receive incoming SMS
2. `READ_SMS` — Read SMS content
3. `BIND_NOTIFICATION_LISTENER_SERVICE` — Monitor notifications
4. `READ_CONTACTS` — Skip known contacts
5. `INTERNET` — API communication
6. `FOREGROUND_SERVICE` — Background protection
7. `POST_NOTIFICATIONS` — Scam warnings
8. `SYSTEM_ALERT_WINDOW` — Overlay warnings

---

## 11. UI LANGUAGE SUPPORT

**9 App UI Languages** (via Google ML Kit On-Device Translation):

| Code | Language | Native Script |
|------|----------|---------------|
| en | English | English |
| hi | Hindi | हिन्दी |
| bn | Bengali | বাংলা |
| te | Telugu | తెలుగు |
| mr | Marathi | मराठी |
| ta | Tamil | தமிழ் |
| gu | Gujarati | ગુજરાતી |
| kn | Kannada | ಕನ್ನಡ |
| ur | Urdu | اردو |

> Malayalam and Punjabi NOT supported by ML Kit (hence excluded).

**AI Scam Detection:** Supports all 22 scheduled Indian languages (via Groq cloud prompt).

---

## 12. SECURITY FEATURES

| Feature | Implementation |
|---------|----------------|
| Authentication | JWT (HS256), 30-day expiry (mobile-optimized) |
| Token Storage | Flutter Secure Storage (iOS Keychain / Android Keystore) |
| API Transport | HTTPS only |
| Password Hashing | bcrypt |
| Biometric Lock | local_auth (fingerprint/face) |
| CORS | Restricted origins (detooz.com, admin.detooz.com, localhost) |
| Request Limits | 15 MB max body size |
| Non-root Docker | Container runs as `appuser` (UID 1000) |
| Consent Management | GDPR-compliant, user-controlled |
| Data Anonymization | Anonymous scan option |
| Secret Key Guard | Raises error if default key used in production |

---

## 13. DEPLOYMENT & INFRASTRUCTURE

| Component | Technology |
|-----------|------------|
| **Backend Hosting** | AWS EC2 |
| **Container** | Docker (Python 3.11-slim) |
| **Orchestration** | docker-compose (single service) |
| **Database** | SQLite (dev) / PostgreSQL (planned prod) |
| **Cache** | Redis |
| **Workers** | 2 Uvicorn workers |
| **Health Check** | HTTP `/health` endpoint, 30s interval |
| **Deploy Script** | `deploy.ps1` (PowerShell → SSH → Docker) |
| **Pull Script** | `pull.ps1` (Git pull & restart) |
| **SSH Key** | `detooz-key.pem` |
| **Monitoring** | `monitoring/monitor.py` (13KB) |
| **Auto-sync** | RSS feeds every 30 minutes (background task) |

---

## 14. TESTING OVERVIEW

### Flutter Unit Tests (7)
| Test | Covers |
|------|--------|
| `basic_tokenizer_test.dart` | Text tokenization |
| `tokenizer_test.dart` | WordPiece tokenizer |
| `connectivity_service_test.dart` | Online/offline detection |
| `offline_cache_service_test.dart` | Hive cache operations |
| `detection_result_test.dart` | Scan result parsing |
| `scan_view_model_test.dart` | Scan data model |
| `widget_test.dart` | Basic widget rendering |

### Flutter Integration Tests (5)
| Test | Covers |
|------|--------|
| `direct_test.dart` | Direct API calls |
| `inference_debug_test.dart` | TFLite inference debugging |
| `minimal_debug_test.dart` | Minimal model loading |
| `offline_model_test.dart` | Offline ML detection |
| `tokenizer_debug_test.dart` | Tokenizer edge cases |

### Backend Tests (10)
| Test | Covers |
|------|--------|
| `test_auth.py` | Email registration/login |
| `test_feedback.py` | ML feedback submission |
| `test_guardian.py` | Guardian linking |
| `test_manual_scan.py` | Manual scan API |
| `test_reputation.py` | URL/phone reputation |
| `test_scan.py` | Auto scan detection |
| `test_services.py` | Service unit tests |
| `test_sms.py` | SMS analysis API |
| `test_trusted_sender.py` | Trusted sender CRUD |
| `test_user.py` | User profile operations |

### ML Pipeline Tests
- `test_inference.py` — Model inference validation
- `test_tflite_interactive.py` — Interactive TFLite testing
- `test_all_messages.py` — Batch message classification
- `test_tokenizer_edge.py` — Tokenizer edge cases
- `validate_tflite.py` — TFLite output verification
- `evaluate_metrics.py` — Precision/recall/F1 computation

---

## 15. PERFORMANCE CHARACTERISTICS

| Operation | Latency | Notes |
|-----------|---------|-------|
| Pattern Matching (Tier 1) | <10ms | Instant, fully offline |
| On-Device TFLite (Tier 2) | 100–200ms | Offline capable |
| Groq Cloud AI (Tier 3) | 500–1500ms | Network dependent |
| Image Analysis | 2–5s | Network dependent |
| Contact Lookup | ~50ms | Local database |

---

## 16. KEY NUMBERS AT A GLANCE

| Metric | Value |
|--------|-------|
| Total Flutter dependencies | 30+ |
| Total Python dependencies | 20 |
| Total screens | 24 (22 + 2 admin) |
| Total reusable components | 8 |
| Total API routers | 15 |
| Total backend services | 14 |
| Total database models | 11+ |
| Total tests (Flutter) | 12 (7 unit + 5 integration) |
| Total tests (Backend) | 10 |
| Training dataset size | 93,152 samples |
| Model accuracy | 99.06% |
| Model file size | 49.2 MB |
| UI languages | 9 |
| AI detection languages | 22 |
| Scam categories (regex) | 8 high-risk + 4 medium-risk |
| Monitored messaging apps | 8 |
| Android permissions | 8 |

---

## 17. APP INITIALIZATION FLOW (main.dart)

1. `WidgetsFlutterBinding.ensureInitialized()`
2. `Firebase.initializeApp()` — Firebase SDK (skipped on Web)
3. `firebaseMessagingService.initialize()` — FCM push notifications
4. `offlineCacheService.initialize()` — Hive offline cache
5. `notificationService.initialize()` — Local notifications
6. `aiService.loadModel()` — Load TFLite model (Hybrid Shield)
7. `TranslationService().initialize()` — ML Kit translation
8. `runApp(ProviderScope(child: MyApp()))` — Launch with Riverpod

**Auth Flow:** `AuthWrapper` checks `authProvider` → routes to `MainScreen` (authenticated) or `LoginScreen` (unauthenticated).

---

## 18. BACKEND STARTUP FLOW (main.py)

1. `init_db()` — Create SQLAlchemy async engine, run migrations
2. `cache.connect()` — Connect to Redis
3. `auto_sync_feeds()` — Start background RSS feed sync (every 30 minutes)
4. Mount static files for image uploads
5. Apply CORS middleware (restricted origins)
6. Apply request body size limit (15 MB)
7. Register all 15 routers with prefixes

**Shutdown:** Cancel feed sync task → disconnect Redis.

---

## 19. GUARDIAN ALERT SYSTEM

The Guardian System is a unique protective feature allowing users to link trusted contacts ("guardians") who receive alerts when scams are detected.

**Guardian Flow:**
1. User sends guardian request (email/phone)
2. Guardian receives OTP verification
3. After verification, guardian is linked
4. When a scam is detected, guardians are alerted via:
   - Firebase Cloud Messaging (push notification)
   - Email (SMTP)
   - WhatsApp (CallMeBot API)
   - Telegram (Bot API)
   - Direct SMS (flutter_sms)

---

## 20. DOCUMENTATION FILES

| File | Size | Content |
|------|------|---------|
| `detooz_technical_specifications.md` | 16KB | Complete tech specs (this extraction's base) |
| `docs/INSTALLATION_GUIDE.md` | 1.7KB | Setup guide |
| `docs/cloud_cicd_plan.md` | 14KB | CI/CD architecture plan |
| `docs/otp_auth_plan.md` | 23KB | OTP authentication design |
| `docs/database_diagram.html` | 46KB | Interactive database diagram |
| `docs/model_perfection_plan/` | 8 files | ML model improvement roadmap |
| `TRANSLATION_GUIDE.md` | 2.2KB | Translation system guide |
| `ml_pipeline/integration_plan.md` | 2.4KB | ML integration plan |
| `ml_pipeline/TOKENIZER_PLAN.md` | 10KB | Tokenizer implementation plan |

---

*End of raw information extraction.*
