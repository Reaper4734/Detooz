# Detooz (ScamShield)

> AI-powered scam detection app protecting users from SMS, WhatsApp, and Telegram scams.

## Project Structure

```
Detooz/
├── backend/           # Python FastAPI server
│   ├── app/
│   │   ├── main.py
│   │   ├── config.py
│   │   ├── routers/
│   │   ├── services/
│   │   ├── models/
│   │   └── schemas/
│   └── tests/
├── app/               # Flutter mobile app (coming soon)
├── docker/            # Docker configuration
└── docs/              # Documentation
```

## Quick Start

### Backend

```bash
cd backend
python -m venv venv
.\venv\Scripts\Activate  # Windows
pip install -r requirements.txt
uvicorn app.main:app --reload
```

### Docker

```bash
cd docker
docker-compose up -d
```

## Tech Stack

- **Backend**: FastAPI, PostgreSQL, Redis
- **AI**: Groq API (Llama 3)
- **Mobile**: Flutter
- **Alerts**: CallMeBot (WhatsApp)

## License

MIT
