# Change Email — Backend Integration Report

**Date:** April 15, 2026  
**Author:** Frontend Team  
**Status:** UI Complete, Backend Integration Pending  
**Priority:** Medium

---

## 1. Overview

The "Change Email" feature allows authenticated users to update their email address from within the Profile Settings screen. The full UI flow has been implemented with mock backend calls. This document describes exactly what the backend developer needs to implement and where to wire it in.

---

## 2. UI Flow Diagram

```
Profile Screen                  Change Email Screen              OTP Verification Screen
┌──────────────┐               ┌──────────────────┐             ┌──────────────────┐
│              │   Tap Edit    │                  │  On Submit  │                  │
│  Email: ✏️   │──────────────▷│  Password Field  │────────────▷│  6-digit OTP     │
│              │               │  New Email Field │             │  for new email   │
│              │               │  [CONTINUE]      │             │  [VERIFY]        │
│              │               │                  │             │  [RESEND OTP]    │
│              │◁──────────────│  ◁ Back Button   │◁────────────│  ◁ Back Button   │
│              │  result=true  │                  │  pop()      │                  │
│  Refresh     │               │                  │             │  Auto-submit     │
│  Profile     │               │  Validates:      │             │  on 6 digits     │
└──────────────┘               │  - password req  │             └──────────────────┘
                               │  - email format  │
                               │  - email != old  │
                               └──────────────────┘
```

### Flow Steps:
1. User taps **edit icon** on the email field in Profile Settings
2. `ChangeEmailScreen` opens — user enters **current password** + **new email**
3. Frontend validates input format (empty, length, email regex, same-email check)
4. Frontend calls **API 1: Verify Password & Send OTP** to the new email
5. If password is **incorrect** → show error, stay on Change Email screen
6. If password is **correct** → backend sends OTP to new email, navigate to OTP screen
7. User enters 6-digit OTP
8. Frontend calls **API 2: Verify OTP & Update Email**
9. If OTP is **valid** → email updated, pop back to Profile, refresh profile data
10. If OTP is **invalid** → show error, user can retry or go back

---

## 3. Required API Endpoints

### API 1: Verify Password & Send Email Change OTP

**Purpose:** Verify the user's current password and send a 6-digit OTP to the new email address.

| Field       | Value                                    |
|-------------|------------------------------------------|
| Method      | `POST`                                   |
| Endpoint    | `/api/v1/auth/change-email/request`      |
| Auth        | Bearer Token (required)                  |

**Request Body:**
```json
{
  "current_password": "string",
  "new_email": "string"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Verification code sent to new email"
}
```

**Error Responses:**

| Status | Scenario                  | Response Body                                         |
|--------|---------------------------|-------------------------------------------------------|
| 401    | Incorrect password        | `{ "success": false, "message": "Incorrect password" }` |
| 409    | Email already in use      | `{ "success": false, "message": "Email already registered" }` |
| 429    | Too many requests         | `{ "success": false, "message": "Too many attempts. Try again later" }` |
| 422    | Invalid email format      | `{ "success": false, "message": "Invalid email address" }` |

---

### API 2: Verify OTP & Complete Email Change

**Purpose:** Verify the OTP sent to the new email and update the user's email address.

| Field       | Value                                    |
|-------------|------------------------------------------|
| Method      | `POST`                                   |
| Endpoint    | `/api/v1/auth/change-email/verify`       |
| Auth        | Bearer Token (required)                  |

**Request Body:**
```json
{
  "new_email": "string",
  "otp": "string (6 digits)"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "Email updated successfully",
  "access_token": "new_jwt_token (if email is part of token claims)"
}
```

**Error Responses:**

| Status | Scenario           | Response Body                                          |
|--------|--------------------|--------------------------------------------------------|
| 400    | Invalid/expired OTP| `{ "success": false, "message": "Invalid or expired OTP" }` |
| 429    | Too many attempts  | `{ "success": false, "message": "Too many attempts" }`    |

---

### API 3: Resend OTP (Optional, reuses existing)

**Purpose:** Resend the OTP to the new email if user didn't receive it.

| Field       | Value                                    |
|-------------|------------------------------------------|
| Method      | `POST`                                   |
| Endpoint    | `/api/v1/auth/change-email/resend`       |
| Auth        | Bearer Token (required)                  |

**Request Body:**
```json
{
  "new_email": "string"
}
```

**Success Response (200):**
```json
{
  "success": true,
  "message": "OTP resent successfully"
}
```

---

## 4. Frontend Files & Mock Locations

These are the exact locations in the codebase where mock calls need to be replaced with real API calls.

### File: `lib/ui/screens/change_email_screen.dart`

#### Mock Location 1 — Password Verification + Send OTP (Line ~93)
```dart
// ── Mock: Simulate password verification delay ──
// When backend is wired, this will call the real API:
//   final result = await apiService.verifyPasswordAndSendEmailOTP(
//     password: _passwordController.text.trim(),
//     newEmail: _newEmailController.text.trim(),
//   );
await Future.delayed(const Duration(milliseconds: 1200));
```

**Replace with:**
```dart
final result = await apiService.changeEmailRequest(
  password: _passwordController.text.trim(),
  newEmail: _newEmailController.text.trim(),
);
if (result['success'] != true) {
  setState(() => _passwordError = result['message'] ?? 'Verification failed');
  return;
}
```

#### Mock Location 2 — OTP Verification (Line ~108)
```dart
onVerifyOTP: (otp) async {
  // ── Mock: Simulate OTP verification ──
  // When backend is wired:
  //   return await apiService.verifyEmailChangeOTP(email: newEmail, otp: otp);
  await Future.delayed(const Duration(milliseconds: 800));
  return true;
},
```

**Replace with:**
```dart
onVerifyOTP: (otp) async {
  final response = await apiService.changeEmailVerify(
    newEmail: newEmail,
    otp: otp,
  );
  if (response['access_token'] != null) {
    // Store new token if email is part of JWT claims
    await tokenService.saveToken(response['access_token']);
  }
  return response['success'] == true;
},
```

#### Mock Location 3 — Resend OTP (Line ~114)
```dart
onResendOTP: () async {
  // ── Mock: Simulate resend ──
  await Future.delayed(const Duration(milliseconds: 500));
},
```

**Replace with:**
```dart
onResendOTP: () async {
  await apiService.changeEmailResend(newEmail: newEmail);
},
```

---

## 5. API Service Methods to Add

Add these methods to `lib/services/api_service.dart`:

```dart
/// Step 1: Verify password and send OTP to new email
Future<Map<String, dynamic>> changeEmailRequest({
  required String password,
  required String newEmail,
}) async {
  // POST /api/v1/auth/change-email/request
  // Body: { "current_password": password, "new_email": newEmail }
  // Returns: { "success": bool, "message": String }
}

/// Step 2: Verify OTP and complete email change
Future<Map<String, dynamic>> changeEmailVerify({
  required String newEmail,
  required String otp,
}) async {
  // POST /api/v1/auth/change-email/verify
  // Body: { "new_email": newEmail, "otp": otp }
  // Returns: { "success": bool, "message": String, "access_token"?: String }
}

/// Step 3: Resend OTP to new email
Future<void> changeEmailResend({required String newEmail}) async {
  // POST /api/v1/auth/change-email/resend
  // Body: { "new_email": newEmail }
}
```

---

## 6. Backend Implementation Notes

### Security Considerations
- **Rate limiting:** Apply rate limits on all 3 endpoints (e.g., 5 requests/minute per user)
- **OTP expiry:** OTPs should expire after 5-10 minutes
- **OTP attempts:** Lock after 5 failed verification attempts
- **Password hashing:** Use existing password verification logic (bcrypt/argon2)
- **Email uniqueness:** Check that the new email is not already registered before sending OTP
- **Session invalidation:** Consider invalidating other sessions after email change (optional)

### Token Handling
- If the JWT contains the user's email in its claims, a **new token must be issued** after email change and returned in the verify response
- The frontend will store this new token automatically

### Email Template
- Send a professional OTP email to the new address
- Subject: "Verify your new email — Detooz"
- Body should include: 6-digit code, expiry time, "if you didn't request this" disclaimer

### Database Operations (on successful verify)
1. Update user's email in the users table
2. Mark the old email as "changed" in audit log (optional)
3. Send a notification to the **old email** informing them of the change (security best practice)

---

## 7. Testing Checklist for Backend

- [ ] Correct password + valid new email → OTP sent, 200 response
- [ ] Incorrect password → 401, no OTP sent
- [ ] New email already registered → 409
- [ ] Valid OTP within expiry → email updated, new token issued
- [ ] Invalid OTP → 400
- [ ] Expired OTP → 400
- [ ] Resend OTP → new OTP sent, old OTP invalidated
- [ ] Rate limiting works on all endpoints
- [ ] Old email receives notification of change
- [ ] JWT with updated email works for subsequent requests

---

## 8. Existing Related Code

| File | Purpose |
|------|---------|
| `lib/services/api_service.dart` | Add the 3 new methods here |
| `lib/ui/screens/change_email_screen.dart` | **NEW** — Contains 3 mock locations to replace |
| `lib/ui/screens/otp_verification_screen.dart` | Reused as-is, receives callbacks from ChangeEmailScreen |
| `lib/ui/screens/edit_profile_screen.dart` | Entry point, navigates to ChangeEmailScreen |
| `lib/ui/providers.dart` | `userProfileProvider` — call `.loadProfile()` after email change |

---

*End of report. Contact the frontend team for any clarification on UI behavior or callback structures.*
