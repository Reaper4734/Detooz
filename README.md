# Detooz (ScamShield)

> 🛡️ AI-powered scam detection app protecting users from SMS, WhatsApp, and Telegram scams.

## 📚 Documentation
- **[Backend Handover Guide](BACKEND_HANDOVER.md)** 👈 **START HERE (For Devs)**
- [Mobile Integration Guide](API_DOCS_FOR_MOBILE.md)
- [WhatsApp Detection Strategy](WHATSAPP_STRATEGY.md)

## 🏗️ Project Structure
```
Detooz/
├── backend/               # FastAPI Server (Python)
├── mobile/                # Flutter App (Dart)
├── docker/                # Docker Config
├── BACKEND_HANDOVER.md    # Developer Rules & Setup
└── task.md                # Progress Tracker
```

## ⚡ Tech Stack
- **Backend**: FastAPI, SQLAlchemy (SQLite/Postgres)
- **AI**: Groq (Text) + Gemini (Vision)
- **Mobile**: Flutter
- **Alerts**: Telegram Bot

## 🚀 Quick Start (Backend)
```bash
cd backend
# Setup venv & install deps
.\venv\Scripts\Activate
pip install -r requirements.txt
# Run server
uvicorn app.main:app --reload
```
See `BACKEND_HANDOVER.md` for full instructions.

## 📄 License
MIT
