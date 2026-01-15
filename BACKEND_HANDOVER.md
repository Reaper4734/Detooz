# 📘 Detooz Backend - Handover Documentation

**Version:** 1.0.0 (MVP)
**Status:** Production Ready (Local/Docker)
**Tech Stack:** FastAPI, SQLite/PostgreSQL, Groq AI, Gemini Vision

---

## 🚀 Quick Start for Frontend Devs

### 1. Prerequisites
- Python 3.10+
- (Optional) Docker

### 2. Run Locally (Recommended)
```bash
cd backend
python -m venv venv
# Windows
.\venv\Scripts\activate
# Mac/Linux
source venv/bin/activate

pip install -r requirements.txt
python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```
Server will be live at: `http://localhost:8000`
**API Docs (Swagger UI):** `http://localhost:8000/docs`

---

## 📱 Mobile App Integration Details

### Base URLs
- **Android Emulator**: `http://10.0.2.2:8000`
- **Physical Device**: `http://<YOUR_PC_IP>:8000` (Ensure firewall allows port 8000)

### 🔑 Authentication (JWT)
The app uses **Bearer Token** authentication.
1. **Register/Login** to get `access_token`.
2. Store token in `FlutterSecureStorage`.
3. Add header to *every* subsequent request:
   `Authorization: Bearer <your_token>`

### 🛠️ Key Endpoints Overview

| Feature | Method | Endpoint | Description |
| :--- | :--- | :--- | :--- |
| **Auth** | POST | `/api/auth/login` | Returns JWT token |
| | POST | `/api/auth/register` | Create user |
| **SMS** | POST | `/api/sms/analyze` | **Core:** Check SMS for scams |
| | POST | `/api/sms/block/{sender}` | Block a phone number |
| **Image**| POST | `/api/scan/analyze-image` | Upload screenshot for AI check |
| **Guard**| POST | `/api/guardian/add` | Add parent/guardian for alerts |

> **Pro Tip:** Check `API_DOCS_FOR_MOBILE.md` for exact JSON payloads and examples.

---

## 🧠 AI & Detection Logic

### 1. Text Analysis (SMS/WhatsApp)
- **Layer 1: Pattern Matching** (Local)
  - Checks against 60+ Indian scam patterns (KYC, Lottery, OTP).
  - *Speed:* <10ms.
- **Layer 2: AI Analysis** (Groq/Llama 3.3)
  - Used if patterns are inconclusive.
  - Understands context (Hindi/Hinglish supported).
  - *Speed:* ~1-2s.

### 2. Image Analysis
- Uses **Google Gemini Vision**.
- Send screenshots to extract text and detect fraudulent UI/logos.

### 3. Alerts
- If Risk = `HIGH`:
  - App shoud show **Red Overlay**.
  - Backend automatically notifies Guardians via **Telegram**.

---

## 📂 Project Structure

```
Detooz/
├── backend/               # FastAPI Server
│   ├── app/
│   │   ├── routers/       # API Endpoints (sms, scan, auth)
│   │   ├── services/      # AI Logic (scam_detector.py)
│   │   ├── models/        # Database Tables
│   │   └── schemas/       # JSON Request/Response format
│   ├── .env               # API Keys (Keep secret!)
│   └── detooz.db          # Local Database
│
├── mobile/                # Flutter App
│   ├── lib/               # Dart Code
│   └── android/           # Android Native Config
│
├── API_DOCS_FOR_MOBILE.md # Integration Guide
├── WHATSAPP_STRATEGY.md   # How to build WhatsApp detection
└── task.md                # Progress Tracker
```

## 🔮 Future Work (WhatsApp)
Check `WHATSAPP_STRATEGY.md` for the blueprint on implementing **Android Accessibility Services** to read WhatsApp messages without an API.

---

**Built with ❤️ by the Backend Team**
