# Detooz Frontend Analysis Report

## 1. Modular Architecture
The Detooz mobile app is built with **Flutter (^3.6.0)**, employing a strictly modular architecture to ensure high performance and maintainability across platforms:

- **State Management**: Uses **Riverpod (2.6.1)** for reactive, globally accessible application state.
- **Service-Oriented Design**: Dedicated services for TFLite inference, translation, and background notification management.
- **Local Persistence**: **Hive** for fast key-value storage and **Flutter Secure Storage** for handling sensitive tokens.

## 2. UI/UX: The Neo-Brutalist Migration
The application has recently undergone a major visual overhaul, moving from a standard "Glassmorphism" look to **Neo-Brutalism**:

- **Visual Language**: Sharp borders, heavy drop-shadows (brutal shadows), and high-contrast color palettes (e.g., Cyan primary, Bold Black accents).
- **Responsive Scaling**: Custom `responsive_utils.dart` for device-independent Font and Layout scaling (sp/h).
- **Dynamic Micro-Animations**: Used for OTP input fields, screen transitions, and status indicators.

## 3. Core Features

### 3.1 On-Device Scam Detection
- **TFLite Integration**: Performs inference locally using the **MobileBERT** model for sub-200ms detection without an internet connection.
- **Permission Wizard**: A multi-step flow that handles Android's sensitive SMS and Notification Listener permissions.

### 3.2 Notification Listener Service
- **Real-time Monitoring**: Intercepts notifications from SMS, WhatsApp, and Telegram.
- **Privacy Filtering**: Automatically skips messages from known contacts, focusing only on unknown/potentially suspicious senders.

### 3.3 Multilingual Interface
- Supports **9 major Indian languages** for the UI.
- Uses **Google ML Kit** for on-the-fly translation of suspicious messages during the initial detection phase.

## 4. Key Screens & Flows

| Screen | Primary Purpose |
|--------|-----------------|
| **Dashboard** | High-level summary of protection status and recent scan activity. |
| **Scan Detail** | In-depth breakdown of a specific message, including the AI's "Explanation" for its classification. |
| **Guardians** | Comprehensive management of linked safety networks. |
| **Permission Wizard** | Guided onboarding for critical system-level access. |
| **Language Manager** | Efficient management of offline translation models. |

## 5. Security & Privacy Features
- **Secure Storage**: JWT tokens and sensitive user information are never stored in plain-text.
- **Consent Collection**: Granular UI controls for opting in/out of ML training data contribution.
- **Foreground Service**: Ensures the protection layer remains active in the background, compliant with Android's modern background execution limits.
