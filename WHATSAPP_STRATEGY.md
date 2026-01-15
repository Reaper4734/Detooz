# 🕵️ WhatsApp Detection Strategy (No API Required)

## ❌ The Misconception
Many developers think they need the **WhatsApp Business API** to detect scams.
**Why that fails:**
1. It's Paid.
2. It's for *Business Chatbots*, not reading user messages.
3. It cannot see what the user is chatting about with strangers.

## ✅ The Solution: Android Accessibility Service
We use Android's built-in **Accessibility Services** to "read" the screen content when WhatsApp is open. This is how antivirus apps, screen readers, and parental control apps work.

### 🛠️ Architecture

1.  **Service**: Create a `DetoozAccessibilityService` in Android (Kotlin/Java layer of Flutter).
2.  **Filter**: Listen only for package `com.whatsapp`.
3.  **Event**: On `TYPE_WINDOW_CONTENT_CHANGED` (new message appears).
4.  **Extract**: Get text from `AccessibilityNodeInfo`.
5.  **Analyze**: Run our `ScamDetector` (Local Patterns or API).
6.  **Action**: If High Risk -> Show Alert Window (`SYSTEM_ALERT_WINDOW`).

### 📱 Implementation Plan for Stitch

#### 1. Add Permissions
In `AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.BIND_ACCESSIBILITY_SERVICE" />
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW" />
```

#### 2. Service Config (`res/xml/accessibility_service_config.xml`)
```xml
<accessibility-service xmlns:android="http://schemas.android.com/apk/res/android"
    android:packageNames="com.whatsapp"
    android:accessibilityEventTypes="typeWindowContentChanged|typeNotificationStateChanged"
    android:accessibilityFeedbackType="feedbackGeneric"
    android:notificationTimeout="100"
    android:canRetrieveWindowContent="true" />
```

#### 3. Flutter Plugin
Use `flutter_accessibility_service` OR write native Android code (Recommended for performance).

---

## 📢 Sending Alerts (The "Output" Problem)
If you want to **SEND** alerts via WhatsApp (not just detect):

1. **Option A: Telegram (Recommended)**
   - Free, reliable, unlimited API.
   - Use our existing setup.

2. **Option B: Accessibility Auto-Send (Hack)**
   - Since we already have Accessibility Service...
   - We can programmatically click the "Type Message" box and "Send" button in WhatsApp.
   - *Complexity: High. Risk: WhatsApp might ban the user for botting.*

3. **Option C: Green-API / Waha** (Third Party)
   - "Grey" market APIs. Not officially free, but have free tiers.
   - *Recommendation: Stick to Telegram for now.*
