# 🚀 Detooz Quick Start Guide

Welcome! This guide will get you up and running in 5 minutes.

## Prerequisites

- **Docker Desktop** - [Download here](https://www.docker.com/products/docker-desktop/)
- **Flutter SDK** - [Install here](https://docs.flutter.dev/get-started/install)
- **API Keys** (get free keys):
  - [Groq API Key](https://console.groq.com/) - For AI scam detection
  - [Gemini API Key](https://aistudio.google.com/app/apikey) (optional)

---

## 🐳 Backend Setup (Docker)

### Step 1: Configure Environment
```bash
cd backend
cp .env.example .env
```

Edit `backend/.env` and add your API keys:
```env
GROQ_API_KEY=your-groq-key-here
GEMINI_API_KEY=your-gemini-key-here  # optional
SECRET_KEY=any-random-string-here
```

### Step 2: Start Backend
```bash
# From project root
docker-compose up --build
```

Wait until you see: `Application startup complete`

✅ Backend running at: **http://localhost:8000**  
📖 API Docs at: **http://localhost:8000/docs**

---

## 📱 Frontend Setup (Flutter)

### Step 1: Get Dependencies
```bash
cd app
flutter pub get
```

### Step 2: Run the App
```bash
# Android Emulator
flutter run

# Chrome (Web)
flutter run -d chrome

# Both simultaneously
flutter run -d chrome &
flutter run
```

---

## 🧪 Quick Test

1. **Register** a new user in the app
2. Go to **Guardian Network** → **My Guardians** → Generate OTP
3. Open another browser/device, register different user
4. That user enters OTP in **Protect Others** tab
5. Both users should now be linked!

---

## 🔧 Troubleshooting

### "Connection refused" on Android Emulator
The emulator uses `10.0.2.2` to reach localhost. Make sure:
- Docker Desktop is running
- Backend container is healthy: `docker ps`

### "Port 8000 already in use"
```bash
docker-compose down
docker-compose up
```

### Clean restart
```bash
docker-compose down -v  # Removes volumes too
docker-compose up --build
```

---

## 📂 Project Structure

```
Detooz/
├── app/                  # Flutter mobile app
├── backend/              # FastAPI backend
│   ├── app/
│   │   ├── routers/      # API endpoints
│   │   ├── models/       # Database models
│   │   └── services/     # Business logic
│   └── .env              # Your config (not in git)
├── docker-compose.yml    # Docker setup
└── GETTING_STARTED.md    # This file!
```

---

## 🎯 Key Features

- **AI Scam Detection** - Powered by Groq/Gemini
- **Guardian System** - Protect family members with OTP linking
- **Single-level depth** - Guardians can't have guardians (prevents loops)
- **Cross-platform** - Android, iOS, Web
+
Questions? Open an issue on GitHub! 🙌
