# 📱 Detooz Mobile App Integration Guide

This guide is for the Frontend Developer (`Stitch`) to connect the Flutter app with the Detooz Backend.

## 🔗 Base URL
- **Local Emulator (Android):** `http://10.0.2.2:8000`
- **Real Device (Same WiFi):** `http://<YOUR_PC_IP>:8000` (e.g. `http://192.168.1.5:8000`)
- **Production:** `https://api.detooz.com` (TBD)

## 🔑 Authentication Flow
1. **Register**: `POST /api/auth/register`
   - Send `{"email": "...", "password": "...", "name": "...", "phone": "..."}`
   - Save `access_token` from response securely (SecureStorage).
2. **Login**: `POST /api/auth/login`
   - Send `username` (email) and `password` as **Form Data**.
   - Save `access_token`.

**Authentication Header:**
All protected requests must include:
`Authorization: Bearer <access_token>`

---

## 📨 SMS Detection (Core Feature)

### Analyze Incoming SMS
Call this whenever a new SMS arrives.

**Endpoint:** `POST /api/sms/analyze`

**Request Body:**
```json
{
  "sender": "+919876543210",
  "message": "Dear customer your account blocked. Click bit.ly/123",
  "timestamp": "2026-01-15T10:00:00Z"
}
```

**Response:**
```json
{
  "risk_level": "HIGH",
  "reason": "Detected KYC scam pattern",
  "confidence": 0.95,
  "is_blocked": false,
  "guardian_alerted": true
}
```

**Logic:**
- If `risk_level` is **HIGH**: Show **RED** full-screen warning.
- If `risk_level` is **MEDIUM**: Show **YELLOW** warning dialog.
- If `risk_level` is **LOW**: Do nothing / Show green toast.

---

## 🛡️ Guardian Management

### Add Guardian
**Endpoint:** `POST /api/guardian/add`

**Request Body:**
```json
{
  "name": "Mom",
  "phone": "+919876543210",
  "telegram_chat_id": "optional-chat-id" 
}
```
*Note: Telegram ID is usually obtained by the guardian messaging the bot.*

---

## �️ Image Analysis (Screenshots)

### Analyze Screenshot
Call this when user captures a screenshot or shares an image.

**Endpoint:** `POST /api/scan/analyze-image`

**Format:** `multipart/form-data`

**Fields:**
- `file`: The image file (jpg/png)
- `sender`: (Optional) Sender of the message in the screenshot
- `platform`: (Optional) "WHATSAPP", "SMS", "TELEGRAM"

**Response:**
Same as SMS Analysis (`risk_level`, `reason`, etc.)

---

## �🐞 Troubleshooting

- **Connection Refused?** 
  - Emulator: Use `10.0.2.2`, NOT `localhost`.
  - Real Device: Ensure PC firewall allows port 8000.
- **401 Unauthorized?**
  - Check if JWT token is expired (30 mins default). Auto-logout receiver.
