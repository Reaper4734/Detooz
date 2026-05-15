# Detooz: Detection Methodology & Workflows

## Overview
Detooz rejects the traditional cybersecurity methodology of passive antivirus scanning. Instead, it employs an active, intent-based behavioral monitoring methodology structured around a "Hybrid-AI Shield."

## The Hybrid-AI Shield: 3-Tier Detection
When a message arrives on the user's device, it is processed through a cascading pipeline designed to maximize speed while minimizing battery consumption and cloud dependency.

### Tier 1: Pattern Matching (Instantaneous - <10ms)
Before any AI is invoked, the message is scanned locally using rigorous Regular Expressions (Regex).
*   **Heuristics:** Checks for definitive scam structures such as "KYC suspend", "urgent Aadhar link", "prize winner", or "customs duty held".
*   **Outcome:** If a definitive match is found, the message is instantly flagged as malicious, entirely bypassing the need for heavy ML computation.

### Tier 2: On-Device Machine Learning (~100-200ms)
If Tier 1 is inconclusive, the message is passed to the local MobileBERT SLM.
*   **Methodology:** The model performs a 3-class sequence classification (HAM, OTP, or SCAM). It analyzes the structural phrasing, grammatical anomalies, and psychological intent (e.g., artificial urgency) of the text.
*   **Privacy Guard:** Because this happens entirely offline on the device's silicon, the user's private messages are never transmitted over the internet.

### Tier 3: Cloud AI Escallation (~500-1500ms)
Only in cases of extreme ambiguity (where the local model's confidence threshold is low) is the message anonymized and securely transmitted via HTTPS to the Detooz backend.
*   **Methodology:** The backend queries a massive Large Language Model (Llama 3.3 70B via Groq) to perform deep contextual analysis across multiple Indian languages. The result is cached in Redis to instantly protect other users who might receive the same novel scam.

## The Guardian Network Methodology
A defining feature of Detooz's methodology is recognizing that *humans are the weakest link* in cybersecurity. 

*   **The Vulnerability:** Even with a bright red warning on their screen, a panicked victim (e.g., an elderly user told their bank account is frozen) might still click a malicious link.
*   **The Solution:** Users can link their account to a "Trusted Guardian" (a tech-savvy family member). 
*   **The Workflow:** If the Detooz app detects a high-risk scam arriving on the vulnerable user's phone, it does not just warn the user. It immediately fires a server-side webhook via Firebase Cloud Messaging (FCM) to the Guardian's phone, sending them a push notification and email.
*   **The Outcome:** The Guardian can intervene (call the victim) before the victim completes the fraudulent transaction, effectively closing the psychological vulnerability gap.

## Background Monitoring Workflow
1.  **Interception:** The Android Notification Listener service silently monitors incoming notifications from registered packages (`com.whatsapp`, `com.android.mms`, etc.).
2.  **Filtering:** Messages from saved contacts (read via `READ_CONTACTS` permission) are instantly discarded from analysis to respect privacy and save compute power.
3.  **De-duplication:** A rolling cache of recent message hashes prevents the system from scanning the same message twice.
4.  **Overlay Alert:** If a threat is detected, Detooz triggers an aggressive `SYSTEM_ALERT_WINDOW` overlay, drawing a warning shield directly over the messaging app to physically block the user from interacting with the scam payload.
