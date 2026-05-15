# Solving the Multilingual Challenge in Detooz

## The Fundamental Problem
India is a linguistically diverse country. Scammers actively exploit this by sending phishing links and fraudulent messages in regional languages (Hindi, Tamil, Bengali) or mixed-code formats (e.g., "Hinglish"). 

The core AI model powering Detooz's on-device detection is **MobileBERT** (`google/mobilebert-uncased`). While highly optimized for mobile devices, it was pre-trained almost exclusively on an English corpus. It cannot natively understand the semantics or intent of regional Indian languages. 

## The Constraint
The easiest solution to this problem would be to send the incoming text to a cloud translation service (like the Google Translate API or DeepL). However, doing so would completely violate Detooz's **Zero-Trust, Privacy-First architecture**. Sending a user's private SMS messages to a third-party cloud server is an unacceptable security risk. 

## The Solution: On-Device ML Kit Translation
To bridge the gap between regional Indian languages and the English-only MobileBERT model without compromising privacy, Detooz integrates **Google ML Kit Translation** directly into the Flutter mobile application.

### How It Works (The Workflow)
1. **Interception:** A message arrives on the user's phone in a regional language (e.g., Hindi: "प्रिय ग्राहक, आपका बैंक खाता ब्लॉक कर दिया गया है...").
2. **Local Translation:** The Flutter app uses `google_mlkit_translation` to detect the language. It then utilizes locally downloaded, compressed language packs to translate the text into English *entirely offline* on the device.
3. **Inference:** The newly translated English string ("Dear customer, your bank account has been blocked...") is instantly fed into the TFLite MobileBERT model.
4. **Classification:** Because the *intent* of the translated sentence clearly matches a banking scam profile, MobileBERT accurately flags it as `SCAM` and triggers the overlay shield.

### Supported Languages
By utilizing ML Kit, Detooz effectively "tricks" the English model into understanding 9 Indian languages natively on the device:
*   Hindi (hi)
*   Bengali (bn)
*   Telugu (te)
*   Marathi (mr)
*   Tamil (ta)
*   Gujarati (gu)
*   Kannada (kn)
*   Urdu (ur)
*   *(English is processed natively)*

*Note: Malayalam and Punjabi are currently not supported by ML Kit, so they rely on the Tier 3 Cloud AI (Groq Llama 3.3) for translation and detection if they bypass Tier 1.*
