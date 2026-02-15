# Fresh Model Training — Complete Dataset Plan

## Architecture

```
Layer 1: MobileBERT (text classification) ← THIS PLAN
Layer 2: URL Analysis (domain reputation)  ← LATER
```

3 classes: **HAM** (safe) · **SCAM** (fraud) · **OTP** (codes)

---

## Data Sources

| Source | Samples | What |
|---|---|---|
| Gemini 3 Pro × 4 keys | 100,000 | SCAM + Hard Neg + HAM General |
| Existing real data | 4,000 | OTP (from `final_training_set.csv`) |
| **Total** | **104,000** | — |

---

## SCAM — 40,000 (25 categories)

### 📱 SMS Scams (10 types)

| # | Category | Count | Pattern | Example |
|---|---|---|---|---|
| 1 | `sms_kyc_fraud` | 2,000 | Bank/wallet KYC expiry threat | "SBI: KYC expired. Update now or account blocked: sbi-kyc.in" |
| 2 | `sms_challan` | 2,000 | Fake traffic e-challan + APK/link | "E-Challan: MH12AB1234 fine ₹2000. Pay: echallan-parivahan.org.in" |
| 3 | `sms_electricity` | 1,500 | Power disconnection tonight | "MSEDCL: Bill overdue. Disconnection at 8pm. Pay: msedcl-pay.in" |
| 4 | `sms_income_tax` | 1,500 | Fake ITR refund approved | "IT Dept: Refund ₹18,500 approved. Deposit to A/c: itr-refund.co.in" |
| 5 | `sms_sim_trai` | 1,500 | TRAI SIM block warning | "TRAI: Your SIM linked to fraud. Blocked in 24hrs. Verify: trai-verify.in" |
| 6 | `sms_india_post` | 1,500 | Fake parcel address update | "India Post: Package at warehouse. Update address or returned: indiapost-track.in" |
| 7 | `sms_loan_offer` | 1,500 | Predatory instant loan | "Pre-approved loan ₹5L at 0% interest! Download: quickloan-app.in" |
| 8 | `sms_credit_card` | 1,500 | Reward points expiry | "HDFC: 15,000 points expire tonight! Redeem: hdfc-rewards.co.in" |
| 9 | `sms_apk_malware` | 1,000 | Fake app download | "Install SBI Secure v3.0 to continue banking: download.sbi-secure.in/app.apk" |
| 10 | `sms_fake_support` | 1,000 | Fake customer care number | "Amazon refund failed. Call toll-free: 1800-XXX-XXXX to claim" |

### 💬 WhatsApp Scams (8 types)

| # | Category | Count | Pattern | Example |
|---|---|---|---|---|
| 11 | `wa_investment` | 2,000 | Stock/crypto guaranteed returns | "Join our premium trading group. 40% weekly returns guaranteed. Results: [screenshot]" |
| 12 | `wa_part_time_job` | 2,000 | Like/subscribe/rate task scam | "Earn ₹5000-15000/day! Just like YouTube videos. WhatsApp HR: 9123456780" |
| 13 | `wa_hi_mom` | 1,500 | "Hi Mom/Dad" new number scam | "Hi Papa, this is my new number. Old phone broke. Can you send ₹5000 urgently?" |
| 14 | `wa_boss_ceo` | 1,500 | CEO/MD impersonation | "Hi, I'm in a confidential meeting. Buy 5 Amazon gift cards ₹10K each. Urgent - MD" |
| 15 | `wa_romance` | 1,000 | Love interest + gift/customs fee | "Hello dear, I'm sending expensive gift from London. Just pay customs $200" |
| 16 | `wa_qr_code` | 1,000 | "Scan to receive money" fraud | "I'm sending ₹5000. Please scan this QR code to receive the payment" |
| 17 | `wa_gold_upgrade` | 800 | WhatsApp Gold/premium upgrade | "EXCLUSIVE: Upgrade to WhatsApp Gold! New features + video calling: wa-gold.com" |
| 18 | `wa_sextortion` | 1,200 | Video call blackmail | "I recorded our video call. Pay ₹50,000 or I share with all your contacts" |

### 📲 Telegram Scams (7 types)

| # | Category | Count | Pattern | Example |
|---|---|---|---|---|
| 19 | `tg_crypto_invest` | 2,000 | USDT mining / crypto platform | "Made $3,000 today on USDT mining pool! Join and earn passive income: crypto-earn.vip" |
| 20 | `tg_task_earning` | 2,000 | Prepaid task deposit scam | "Complete 3 tasks, earn ₹1500. Deposit ₹500 to unlock premium tasks. Guaranteed refund" |
| 21 | `tg_pump_dump` | 1,000 | Insider stock/crypto tip | "🔥INSIDER TIP: Buy $XCOIN now at ₹2. Target ₹50 by Friday. Don't miss this 25x gem!" |
| 22 | `tg_bot_fraud` | 1,000 | Fake verification/KYC bot | "Complete KYC verification to claim your 500 USDT airdrop: @VerifyKYC_bot" |
| 23 | `tg_fake_channel` | 800 | Impersonating real company/expert | "Official Zerodha Trading Tips™ | Join VIP channel for guaranteed intraday calls" |
| 24 | `tg_pig_butchering` | 800 | Long-form trust + invest grooming | "We've been chatting for weeks, I trust you. Let me teach you my crypto strategy..." |
| 25 | `tg_malware_link` | 400 | Fake app/file download | "Download our trading app for real-time signals: zerodha-pro.apk" |

### 🔀 Cross-Platform Scams (embedded in above)

These patterns appear on ALL platforms and are baked into the categories above:

| Pattern | SMS | WhatsApp | Telegram |
|---|---|---|---|
| Digital arrest (police/CBI) | ✅ `sms_sim_trai` | ✅ `wa_hi_mom` variant | ✅ `tg_bot_fraud` |
| Family emergency + money | ✅ `sms_fake_support` | ✅ `wa_hi_mom` | — |
| Lottery/KBC | Baked into `sms_credit_card` | Baked into `wa_investment` | Baked into `tg_pump_dump` |

---

## Hard Negatives — 35,000 (7 categories, 5K each)

**Teaching: "Emotional ≠ Scam" and "URL ≠ Scam"**

| # | Category | Count | Pattern | Example |
|---|---|---|---|---|
| 1 | `hn_trouble_solved` | 5,000 | Problem → resolved, NO money | "Was in big trouble but Ravi helped. All sorted now, don't worry" |
| 2 | `hn_hospital_positive` | 5,000 | Hospital → good outcome | "Mom's surgery went perfectly. Doctor said she'll be home by evening" |
| 3 | `hn_money_received` | 5,000 | Money topic → receiving/thanking | "Got the 2000 you sent. Thanks bro, lifesaver!" |
| 4 | `hn_urgent_work` | 5,000 | "Urgent" → legitimate context | "URGENT: Client presentation moved to 2pm. Bring laptop and projector" |
| 5 | `hn_help_non_money` | 5,000 | Help request → NOT money | "Help me pick a birthday gift for mom. What should I get?" |
| 6 | `hn_family_emotion` | 5,000 | Emotional → no action needed | "Miss you so much mummy. Will come home this Diwali for sure" |
| 7 | `hn_safe_with_links` | 5,000 | Message WITH URLs → safe | "Watch this amazing recipe: youtu.be/abc123. Try it tonight!" |

---

## HAM General — 25,000 (10 categories)

| # | Category | Count | Key Focus |
|---|---|---|---|
| 1 | `ham_personal_family` | 3,000 | Casual family chat, plans |
| 2 | `ham_personal_friends` | 2,500 | Friend conversations |
| 3 | `ham_work_professional` | 2,500 | Office, meetings, deadlines |
| 4 | `ham_youtube_social` | 3,000 | YouTube, Instagram, Twitter links shared |
| 5 | `ham_promo_retail` | 3,000 | Real Zomato, Myntra, Amazon, Flipkart SMS/WA |
| 6 | `ham_promo_banking` | 2,500 | Real bank debit/credit alerts with UPI refs |
| 7 | `ham_news_sharing` | 2,000 | Sharing news articles, blog links |
| 8 | `ham_subscription` | 2,000 | Netflix, Jio, Spotify renewal alerts |
| 9 | `ham_payment_confirm` | 2,000 | "Paid ₹500 to Ramesh via GPay" |
| 10 | `ham_hinglish_casual` | 2,500 | "Bro kal milte hai", "Kya scene hai" |

---

## OTP — 4,000 (from existing real data)

Extracted from `final_training_set.csv` — real bank/app OTPs. No generation needed.

---

## Platform Distribution in SCAM Data

| Platform | Samples | % of SCAM | Categories |
|---|---|---|---|
| SMS-origin | 15,500 | 39% | 10 types |
| WhatsApp-origin | 12,000 | 30% | 8 types |
| Telegram-origin | 8,000 | 20% | 7 types |
| Cross-platform | 4,500 | 11% | Baked into above |
| **Total SCAM** | **40,000** | 100% | 25 types |

> [!NOTE]
> **Why platform-aware categories?** SMS scams use short, link-heavy messages. WhatsApp scams use conversational, trust-building patterns. Telegram scams use group-based, crypto-focused language. The model needs exposure to ALL writing styles.

---

## Generation Plan — 4× Gemini 3 Pro Keys

```
Target:    100,000 clean (+ 4K real OTP)
Generate:  200,000 raw (2× over-generation)
API calls: 200K ÷ 25 = 8,000 calls
With 4 keys (6,000 RPD): Done in ~1.5 days
```

| Day | API Calls | What |
|---|---|---|
| **Day 1** | 6,000 | All SCAM (40K) + Hard Negatives (35K) |
| **Day 2 AM** | 2,000 | HAM General (25K) + re-gen gaps |
| **Day 2 PM** | — | Quality filter + merge with OTP |

---

## Quality Filter

| Step | Rule |
|---|---|
| Length | 15 < chars < 500 |
| Script | English/Roman only |
| Dedup | Jaccard similarity < 0.7 |
| Prompt leak | < 60% prompt overlap |
| **Hard Neg gate** | Must NOT contain money request |
| **SCAM gate** | Must contain urgency/money/action |
| OTP gate | Must contain digits |

---

## Training Config

| Setting | Value |
|---|---|
| Base model | `google/mobilebert-uncased` |
| Classes | 3 (HAM=0, OTP=1, SCAM=2) |
| Max seq | 128 |
| Epochs | 5 + early stopping (patience=2) |
| Batch | 32 |
| LR | 2e-5 cosine decay |
| Label smoothing | 0.1 |
| Class weights | {HAM: 1.0, OTP: 1.3, SCAM: 1.2} |
| Split | 80/10/10 stratified |
| Gate | Adversarial accuracy > 92% |

---

## Files to Build

| File | Type | Description |
|---|---|---|
| `data_generation/taxonomy_v2.py` | NEW | All 42 categories + prompt templates |
| `data_generation/multi_key_gen.py` | NEW | 4-key async Gemini 3 Pro generator |
| `data_generation/quality_filter.py` | MODIFY | Dedup + length + label verification |
| `data_generation/extract_otp.py` | NEW | Extract 4K real OTP from existing CSV |
| `adversarial_test_set.csv` | NEW | 200 hand-crafted edge cases |
| `train_v2.py` | NEW | MobileBERT + improvements |
| `pipeline_v2.py` | NEW | End-to-end orchestrator |

---

## Env Variables

```
GEMINI_KEY_1=your_key_1
GEMINI_KEY_2=your_key_2
GEMINI_KEY_3=your_key_3
GEMINI_KEY_4=your_key_4
```
