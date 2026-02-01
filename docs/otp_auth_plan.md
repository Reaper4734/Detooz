# 🔐 Free Email & Phone OTP Authentication Plan

## Objective
Implement secure OTP-based authentication with **zero cost**:
- Email OTP: Gmail SMTP (500 emails/day free)
- Phone OTP: Firebase Phone Auth (10k SMS/month free)

---

## Free Tier Comparison

### Email OTP Options

| Provider | Free Limit | Reliability | Setup |
|----------|------------|-------------|-------|
| **Gmail SMTP** ✅ | 500/day | High | Easy |
| SendGrid | 100/day | High | Medium |
| Resend | 3000/month | High | Easy |
| Mailgun | Trial only | High | Medium |

**Winner: Gmail SMTP** - 500/day is plenty for an MVP, zero cost.

### Phone OTP Options

| Provider | Free Limit | India Support | Setup |
|----------|------------|---------------|-------|
| **Firebase Phone Auth** ✅ | 10k/month | ✅ Yes | Easy |
| Twilio | Trial credits | ✅ Yes | Medium |
| MSG91 | Trial only | ✅ Yes | Medium |
| Vonage | Trial only | ✅ Yes | Medium |

**Winner: Firebase Phone Auth** - 10k verifications/month free, native Flutter support.

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    Flutter App                          │
├─────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌─────────────────────────────┐│
│  │  Email OTP      │    │  Phone OTP (Firebase)       ││
│  │                 │    │                             ││
│  │ 1. Enter email  │    │ 1. Enter phone              ││
│  │ 2. Call backend │    │ 2. Firebase sends SMS       ││
│  │ 3. Backend sends│    │ 3. User enters OTP          ││
│  │ 4. User enters  │    │ 4. Firebase verifies        ││
│  │ 5. Backend verify│   │ 5. Get Firebase token       ││
│  │ 6. Get JWT      │    │ 6. Exchange for JWT         ││
│  └─────────────────┘    └─────────────────────────────┘│
│           │                         │                   │
│           ▼                         ▼                   │
│  ┌─────────────────────────────────────────────────────┐│
│  │              FastAPI Backend                        ││
│  │  - Generate OTP (email)                             ││
│  │  - Send via Gmail SMTP                              ││
│  │  - Verify OTP                                       ││
│  │  - Verify Firebase token (phone)                    ││
│  │  - Issue JWT                                        ││
│  └─────────────────────────────────────────────────────┘│
└─────────────────────────────────────────────────────────┘
```

---

## Phase 1: Email OTP (Backend)

### 1.1 Gmail SMTP Setup

**Step 1: Enable 2FA on Gmail**
1. Go to https://myaccount.google.com/security
2. Enable 2-Step Verification

**Step 2: Create App Password**
1. Go to https://myaccount.google.com/apppasswords
2. Select "Mail" and "Other (Custom name)"
3. Name it "Detooz OTP"
4. Copy the 16-character password

**Step 3: Store in .env**
```bash
# .env
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=your-email@gmail.com
SMTP_PASSWORD=xxxx-xxxx-xxxx-xxxx  # App password
```

### 1.2 Backend Implementation

```python
# app/services/otp_service.py
import random
import string
import smtplib
from email.mime.text import MIMEText
from email.mime.multipart import MIMEMultipart
from datetime import datetime, timedelta
from typing import Optional
import os
import hashlib

# In-memory OTP storage (use Redis in production)
otp_store: dict = {}

class OTPService:
    OTP_EXPIRY_MINUTES = 5
    OTP_LENGTH = 6
    
    @staticmethod
    def generate_otp() -> str:
        """Generate a 6-digit OTP"""
        return ''.join(random.choices(string.digits, k=6))
    
    @staticmethod
    def hash_otp(otp: str) -> str:
        """Hash OTP for secure storage"""
        return hashlib.sha256(otp.encode()).hexdigest()
    
    @classmethod
    def store_otp(cls, identifier: str, otp: str) -> None:
        """Store OTP with expiry"""
        otp_store[identifier] = {
            'otp_hash': cls.hash_otp(otp),
            'expires_at': datetime.utcnow() + timedelta(minutes=cls.OTP_EXPIRY_MINUTES),
            'attempts': 0
        }
    
    @classmethod
    def verify_otp(cls, identifier: str, otp: str) -> tuple[bool, str]:
        """Verify OTP and return (success, message)"""
        if identifier not in otp_store:
            return False, "OTP not found or expired"
        
        stored = otp_store[identifier]
        
        # Check expiry
        if datetime.utcnow() > stored['expires_at']:
            del otp_store[identifier]
            return False, "OTP expired"
        
        # Check attempts (max 3)
        if stored['attempts'] >= 3:
            del otp_store[identifier]
            return False, "Too many failed attempts"
        
        # Verify OTP
        if stored['otp_hash'] != cls.hash_otp(otp):
            stored['attempts'] += 1
            return False, "Invalid OTP"
        
        # Success - clean up
        del otp_store[identifier]
        return True, "OTP verified"
    
    @staticmethod
    def send_email_otp(email: str, otp: str) -> bool:
        """Send OTP via Gmail SMTP"""
        try:
            smtp_host = os.getenv('SMTP_HOST', 'smtp.gmail.com')
            smtp_port = int(os.getenv('SMTP_PORT', 587))
            smtp_user = os.getenv('SMTP_USER')
            smtp_pass = os.getenv('SMTP_PASSWORD')
            
            # Create message
            msg = MIMEMultipart('alternative')
            msg['Subject'] = f'Your Detooz Verification Code: {otp}'
            msg['From'] = smtp_user
            msg['To'] = email
            
            # HTML email template
            html = f"""
            <html>
            <body style="font-family: Arial, sans-serif; padding: 20px;">
                <h2 style="color: #2563eb;">Detooz Verification</h2>
                <p>Your verification code is:</p>
                <h1 style="color: #1f2937; font-size: 36px; letter-spacing: 8px;">{otp}</h1>
                <p style="color: #6b7280;">This code expires in 5 minutes.</p>
                <p style="color: #6b7280;">If you didn't request this, please ignore this email.</p>
            </body>
            </html>
            """
            
            msg.attach(MIMEText(html, 'html'))
            
            # Send email
            with smtplib.SMTP(smtp_host, smtp_port) as server:
                server.starttls()
                server.login(smtp_user, smtp_pass)
                server.send_message(msg)
            
            return True
        except Exception as e:
            print(f"Email send error: {e}")
            return False
```

### 1.3 Email OTP Router

```python
# app/routers/auth_otp.py
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, EmailStr
from app.services.otp_service import OTPService
from app.core.security import create_access_token
from app.db.database import async_session
from app.models import User
from sqlalchemy import select

router = APIRouter()

class EmailOTPRequest(BaseModel):
    email: EmailStr

class VerifyOTPRequest(BaseModel):
    email: EmailStr
    otp: str

class OTPResponse(BaseModel):
    success: bool
    message: str

class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: int
    is_new_user: bool

@router.post("/send-email-otp", response_model=OTPResponse)
async def send_email_otp(request: EmailOTPRequest):
    """Send OTP to email address"""
    otp = OTPService.generate_otp()
    
    # Store OTP
    OTPService.store_otp(request.email, otp)
    
    # Send email
    success = OTPService.send_email_otp(request.email, otp)
    
    if not success:
        raise HTTPException(status_code=500, detail="Failed to send OTP")
    
    return OTPResponse(success=True, message="OTP sent to email")

@router.post("/verify-email-otp", response_model=TokenResponse)
async def verify_email_otp(request: VerifyOTPRequest):
    """Verify email OTP and return JWT token"""
    success, message = OTPService.verify_otp(request.email, request.otp)
    
    if not success:
        raise HTTPException(status_code=400, detail=message)
    
    # Get or create user
    async with async_session() as db:
        result = await db.execute(
            select(User).where(User.email == request.email)
        )
        user = result.scalar_one_or_none()
        
        is_new_user = False
        if not user:
            # Create new user
            user = User(
                email=request.email,
                email_verified=True
            )
            db.add(user)
            await db.commit()
            await db.refresh(user)
            is_new_user = True
        else:
            # Mark email as verified
            user.email_verified = True
            await db.commit()
    
    # Generate JWT
    token = create_access_token(data={"sub": str(user.id)})
    
    return TokenResponse(
        access_token=token,
        user_id=user.id,
        is_new_user=is_new_user
    )
```

---

## Phase 2: Phone OTP (Firebase)

### 2.1 Firebase Setup

**Step 1: Firebase Console**
1. Go to https://console.firebase.google.com
2. Select your project (or create one)
3. Go to Authentication → Sign-in method
4. Enable "Phone" provider

**Step 2: Add SHA-1 to Firebase**
```bash
# Get SHA-1 from debug keystore
cd app/android
./gradlew signingReport
# Copy the SHA-1 and add to Firebase Console → Project Settings → Your apps → Android
```

**Step 3: Download google-services.json**
1. Firebase Console → Project Settings → Your apps
2. Download `google-services.json`
3. Place in `app/android/app/`

### 2.2 Flutter Dependencies

```yaml
# pubspec.yaml
dependencies:
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
```

### 2.3 Flutter Phone Auth Service

```dart
// lib/services/phone_auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  String? _verificationId;
  int? _resendToken;
  
  /// Send OTP to phone number
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
    required Function(PhoneAuthCredential credential) onAutoVerify,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,  // Format: +91XXXXXXXXXX
        timeout: const Duration(seconds: 60),
        
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-verification (Android only)
          onAutoVerify(credential);
        },
        
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        
        codeSent: (String verificationId, int? resendToken) {
          _verificationId = verificationId;
          _resendToken = resendToken;
          onCodeSent(verificationId);
        },
        
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
        
        forceResendingToken: _resendToken,
      );
    } catch (e) {
      onError(e.toString());
    }
  }
  
  /// Verify OTP and sign in
  Future<UserCredential?> verifyOTP(String otp) async {
    if (_verificationId == null) {
      throw Exception('Please request OTP first');
    }
    
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: otp,
    );
    
    return await _auth.signInWithCredential(credential);
  }
  
  /// Get Firebase ID token to send to backend
  Future<String?> getIdToken() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return await user.getIdToken();
  }
  
  /// Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }
}
```

### 2.4 Backend Firebase Token Verification

```python
# app/services/firebase_service.py
import firebase_admin
from firebase_admin import credentials, auth
import os

# Initialize Firebase Admin
cred = credentials.Certificate('firebase-service-account.json')
firebase_admin.initialize_app(cred)

class FirebaseService:
    @staticmethod
    def verify_token(id_token: str) -> dict:
        """Verify Firebase ID token and return user info"""
        try:
            decoded = auth.verify_id_token(id_token)
            return {
                'uid': decoded['uid'],
                'phone': decoded.get('phone_number'),
                'email': decoded.get('email'),
            }
        except Exception as e:
            raise ValueError(f"Invalid token: {e}")
```

```python
# app/routers/auth_otp.py (add phone auth)
class PhoneTokenRequest(BaseModel):
    firebase_token: str

@router.post("/verify-phone-token", response_model=TokenResponse)
async def verify_phone_token(request: PhoneTokenRequest):
    """Verify Firebase phone token and return JWT"""
    try:
        firebase_user = FirebaseService.verify_token(request.firebase_token)
    except ValueError as e:
        raise HTTPException(status_code=401, detail=str(e))
    
    phone = firebase_user.get('phone')
    if not phone:
        raise HTTPException(status_code=400, detail="No phone number in token")
    
    # Get or create user
    async with async_session() as db:
        result = await db.execute(
            select(User).where(User.phone == phone)
        )
        user = result.scalar_one_or_none()
        
        is_new_user = False
        if not user:
            user = User(
                phone=phone,
                phone_verified=True,
                firebase_uid=firebase_user['uid']
            )
            db.add(user)
            await db.commit()
            await db.refresh(user)
            is_new_user = True
    
    # Generate JWT
    token = create_access_token(data={"sub": str(user.id)})
    
    return TokenResponse(
        access_token=token,
        user_id=user.id,
        is_new_user=is_new_user
    )
```

---

## Phase 3: Flutter UI

### 3.1 OTP Input Screen

```dart
// lib/ui/screens/otp_screen.dart
import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class OTPScreen extends StatefulWidget {
  final String identifier;  // email or phone
  final bool isPhone;
  
  const OTPScreen({
    required this.identifier,
    required this.isPhone,
    super.key,
  });

  @override
  State<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends State<OTPScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  int _resendTimer = 30;
  
  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }
  
  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (_resendTimer > 0) {
        setState(() => _resendTimer--);
        return true;
      }
      return false;
    });
  }
  
  Future<void> _verifyOTP() async {
    if (_otpController.text.length != 6) return;
    
    setState(() => _isLoading = true);
    
    try {
      if (widget.isPhone) {
        // Phone OTP via Firebase
        await _verifyPhoneOTP();
      } else {
        // Email OTP via backend
        await _verifyEmailOTP();
      }
    } finally {
      setState(() => _isLoading = false);
    }
  }
  
  Future<void> _verifyEmailOTP() async {
    // Call backend API
    final response = await apiService.post('/auth/verify-email-otp', {
      'email': widget.identifier,
      'otp': _otpController.text,
    });
    
    if (response.success) {
      // Store token and navigate
      await authService.saveToken(response.data['access_token']);
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
  
  Future<void> _verifyPhoneOTP() async {
    // Verify with Firebase
    final credential = await phoneAuthService.verifyOTP(_otpController.text);
    
    if (credential != null) {
      // Get Firebase token
      final firebaseToken = await phoneAuthService.getIdToken();
      
      // Exchange for backend JWT
      final response = await apiService.post('/auth/verify-phone-token', {
        'firebase_token': firebaseToken,
      });
      
      if (response.success) {
        await authService.saveToken(response.data['access_token']);
        Navigator.pushReplacementNamed(context, '/home');
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              'Enter the 6-digit code sent to',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 8),
            Text(
              widget.identifier,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 32),
            
            // OTP Input
            PinCodeTextField(
              appContext: context,
              length: 6,
              controller: _otpController,
              keyboardType: TextInputType.number,
              animationType: AnimationType.fade,
              pinTheme: PinTheme(
                shape: PinCodeFieldShape.box,
                borderRadius: BorderRadius.circular(8),
                fieldHeight: 50,
                fieldWidth: 45,
                activeFillColor: Colors.white,
                inactiveFillColor: Colors.grey.shade100,
                selectedFillColor: Colors.blue.shade50,
              ),
              enableActiveFill: true,
              onCompleted: (_) => _verifyOTP(),
              onChanged: (_) {},
            ),
            
            const SizedBox(height: 24),
            
            // Verify Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verifyOTP,
                child: _isLoading
                    ? const CircularProgressIndicator()
                    : const Text('Verify'),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Resend
            TextButton(
              onPressed: _resendTimer == 0 ? _resendOTP : null,
              child: Text(
                _resendTimer > 0
                    ? 'Resend in $_resendTimer s'
                    : 'Resend OTP',
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Future<void> _resendOTP() async {
    setState(() => _resendTimer = 30);
    _startResendTimer();
    // Re-send OTP logic
  }
}
```

---

## Phase 4: Database Schema Update

```python
# app/models/user.py (updated)
class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True)
    
    # Email auth
    email = Column(String, unique=True, nullable=True)
    email_verified = Column(Boolean, default=False)
    
    # Phone auth
    phone = Column(String, unique=True, nullable=True)
    phone_verified = Column(Boolean, default=False)
    
    # Firebase
    firebase_uid = Column(String, unique=True, nullable=True)
    
    # Profile
    name = Column(String, nullable=True)
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # Legacy password (for migration)
    password_hash = Column(String, nullable=True)
```

---

## Security Best Practices

| Practice | Implementation |
|----------|----------------|
| Rate limiting | Max 3 OTP requests per email/phone per hour |
| OTP expiry | 5 minutes |
| Max attempts | 3 wrong attempts = OTP invalidated |
| Hash storage | Store OTP hash, not plaintext |
| HTTPS only | All API calls over TLS |
| Token rotation | JWT expires in 7 days, refresh available |

---

## Cost Summary

| Service | Free Tier | Your Usage | Cost |
|---------|-----------|------------|------|
| Gmail SMTP | 500 emails/day | ~50/day | **$0** |
| Firebase Phone Auth | 10k SMS/month | ~500/month | **$0** |
| **Total** | - | - | **$0/month** |

---

## Files to Create/Modify

### Backend
```
backend/
├── app/
│   ├── services/
│   │   ├── otp_service.py        # [NEW]
│   │   └── firebase_service.py   # [NEW]
│   ├── routers/
│   │   └── auth_otp.py           # [NEW]
│   └── models/
│       └── user.py               # [UPDATE]
└── .env                          # [UPDATE]
```

### Flutter
```
app/
├── lib/
│   ├── services/
│   │   └── phone_auth_service.dart  # [NEW]
│   └── ui/screens/
│       └── otp_screen.dart          # [NEW]
├── android/app/
│   └── google-services.json         # [NEW]
└── pubspec.yaml                     # [UPDATE]
```

---

## Implementation Steps

1. **Gmail SMTP setup** (10 min)
   - Enable 2FA, create app password
   
2. **Firebase Phone Auth setup** (15 min)
   - Enable in console, add SHA-1
   
3. **Backend OTP service** (30 min)
   - Create otp_service.py and auth_otp.py

4. **Flutter phone auth** (30 min)
   - Add firebase packages, create service

5. **Flutter UI** (45 min)
   - Login screen, OTP screen

6. **Testing** (30 min)
   - Test email and phone flows

**Total: ~2.5 hours**

---

Ready to implement?
