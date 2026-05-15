# Detooz: Technology Stack & Infrastructure

## Overview
Detooz leverages a modern, scalable technology stack divided into an on-device mobile frontend and a high-performance cloud backend, glued together by highly optimized machine learning models.

## Mobile Application (Frontend)
The user-facing application is designed for Android, focusing on seamless background execution and intuitive UI.
*   **Framework:** Flutter (Dart) for high-performance, cross-platform UI rendering.
*   **State Management:** Riverpod for predictable state container management.
*   **Local Storage:** Hive for fast, offline NoSQL database storage on the device.
*   **Security:** `flutter_secure_storage` to encrypt tokens via Android Keystore.
*   **Localization:** Google ML Kit Translation allows the UI to dynamically support 9 regional languages.
*   **Background Monitoring:** Custom Android Native Notification Listener services intercept incoming messages across SMS, WhatsApp, and Telegram.

## Backend Architecture
The backend is designed for high concurrency, low latency, and deep API integrations.
*   **Core Framework:** FastAPI (Python), utilizing asynchronous `async/await` operations to handle thousands of concurrent client requests.
*   **Database:** PostgreSQL for production data persistence; SQLite for local development. Managed via SQLAlchemy (async ORM).
*   **Caching:** Redis for rapid, in-memory caching of rate limits and recent analyses.
*   **Authentication:** JWT (JSON Web Tokens) with bcrypt hashing for stateless, secure API communication.
*   **Deployment:** Containerized via Docker and deployed on AWS EC2 instances powered by AMD EPYC™ processors for exceptional multithreaded performance.

## Artificial Intelligence & Machine Learning
Detooz utilizes a bifurcated AI strategy, balancing local performance with cloud capabilities.

### 1. On-Device Model (The Edge Guardian)
*   **Architecture:** TFLite (TensorFlow Lite) integration via `tflite_flutter`.
*   **Model:** A fine-tuned `google/mobilebert-uncased` Small Language Model (SLM).
*   **Footprint:** Highly compressed to just 49.2 MB to run efficiently on lower-end Android devices without draining the battery.
*   **Dataset & Training:** Trained on a curated corpus of 93,152 samples encompassing safe messages (HAM), legitimate OTPs, and SCAM intents across multiple languages.
*   **Performance Metrics:** Achieves **99.06% accuracy** with an F1-Score of 0.99 for SCAM classification and perfect 1.00 recall for OTPs.

### 2. Cloud AI (The Heavy Lifter)
*   **Provider:** Groq Cloud Infrastructure.
*   **Model:** Meta's Llama 3.3 70B Versatile model.
*   **Purpose:** Activated only for highly ambiguous edge cases that the local SLM cannot confidently classify. It possesses deep reasoning capabilities and native support for 22 scheduled Indian languages.
*   **Image Analysis:** Integrates with OpenRouter (Meta Llama 3.2 11B Vision) to perform Optical Character Recognition (OCR) and intent analysis on user-submitted screenshots (e.g., WhatsApp scam images).
