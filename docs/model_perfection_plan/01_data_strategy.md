# 📊 Data Strategy Plan

## Objective
Create a **production-ready, weighted** dataset for Indian scam detection:
- 4 Languages: English, Hinglish, Hindi, Marathi
- **Smart weighting** (not naive 33/33/33 balance)
- Heavy focus on **Hard Negatives** (the core problem)
- Minimal OTP (easy pattern, low volume needed)

---

## Current Dataset Problems (Diagnosed)

| Problem | Impact | Solution |
|---------|--------|----------|
| 24% duplicates | Overfitting | De-duplication + validation |
| Class imbalance (65% HAM) | Bias toward safe | Smart weighting |
| "mummy/papa" only in HAM | Can't detect family scams | Add to SCAM categories |
| No Hard Negatives | Can't distinguish emotional contexts | **Massive Hard Neg allocation** |
| Only English/Hinglish | Can't handle native scripts | Add Hindi & Marathi |

---

## The Optimized "Hybrid" Strategy

### Why NOT 33/33/33 Balance?

| Class | Pattern Complexity | Learning Difficulty | Data Needed |
|-------|-------------------|---------------------|-------------|
| OTP | Simple ("Your OTP is [DIGITS]") | **Easy** | Low (5k/lang) |
| HAM (General) | Standard chat patterns | Medium | Medium (10k/lang) |
| HAM (Hard Neg) | "Safe Emotion" vs "Scam Emotion" | **Very Hard** | **High (15k/lang)** |
| SCAM | 15+ sub-categories | Hard | High (20k/lang) |

### Target Dataset: 200k samples (SMART WEIGHTED)

| Class | Percentage | Total | Per Language | Rationale |
|-------|------------|-------|--------------|-----------|
| **SCAM** | 40% | 80,000 | 20,000 | 15+ categories need coverage |
| **HAM (Hard Neg)** | 30% | 60,000 | 15,000 | **THE CORE FIX** |
| **HAM (General)** | 20% | 40,000 | 10,000 | Easy patterns, less needed |
| **OTP** | 10% | 20,000 | 5,000 | Simple pattern, 5k is plenty |
| **Total** | 100% | **200,000** | 50,000 | - |

---

## Per-Language Breakdown

| Language | SCAM | Hard Neg | HAM (Gen) | OTP | Total |
|----------|------|----------|-----------|-----|-------|
| English | 20,000 | 15,000 | 10,000 | 5,000 | 50,000 |
| Hinglish | 20,000 | 15,000 | 10,000 | 5,000 | 50,000 |
| Hindi | 20,000 | 15,000 | 10,000 | 5,000 | 50,000 |
| Marathi | 20,000 | 15,000 | 10,000 | 5,000 | 50,000 |
| **Total** | **80,000** | **60,000** | **40,000** | **20,000** | **200,000** |

---

## Hard Negative Categories (THE CRITICAL 30%)

### Purpose
Teach the model: **"Emotional ≠ Scam"**

### Hard Negative Types (15k per language)

| Category | Per-Lang Target | Key Pattern |
|----------|-----------------|-------------|
| `trouble_self_solved` | 3,000 | "I'm in trouble" + solves it themselves |
| `hospital_positive` | 3,000 | Hospital mentions, positive outcome |
| `money_received` | 2,000 | "Got the money" (not asking) |
| `urgent_legitimate` | 2,000 | "Urgent meeting" (work context) |
| `help_non_monetary` | 2,500 | "Help me decide" / "Pick me up" |
| `family_casual_emotion` | 2,500 | "Miss you", "Sad day", "Bad mood" |

### Hard Negative Prompt Examples

```
Category: trouble_self_solved
Prompt: "Generate messages where someone mentions trouble/problem 
but explicitly resolves it WITHOUT asking for money.
Examples: 'Was in trouble but friend helped', 'Problem sorted now',
'Had an issue but fixed it myself'"
```

```
Category: hospital_positive
Prompt: "Generate messages mentioning hospital/doctor but with 
POSITIVE outcomes. Examples: 'Hospital visit went well', 
'Doctor said all clear', 'Discharged today, feeling better'"
```

```
Category: help_non_monetary
Prompt: "Generate messages asking for help but NOT money.
Examples: 'Help me choose a dress', 'Can you pick me up?',
'Need your advice on something', 'Pray for me'"
```

---

## SCAM Categories (40%)

### Category Breakdown (20k per language)

| Category | Per-Lang Target | Key Focus |
|----------|-----------------|-----------|
| `kyc_fraud` | 1,500 | Bank/wallet KYC threats |
| `digital_arrest` | 1,500 | Police/CBI impersonation |
| `family_emergency_scam` | 2,000 | **Mom/Dad/Son + MONEY ASK** |
| `part_time_job` | 1,500 | Fake WFH opportunities |
| `lottery_kbc` | 1,200 | Prize/lottery scams |
| `electricity_bill` | 1,200 | Utility disconnection |
| `income_tax` | 1,200 | Tax refund phishing |
| `loan_harassment` | 1,200 | Predatory lending |
| `stock_crypto` | 1,500 | Investment scams |
| `romance_scam` | 1,200 | Relationship manipulation |
| `customer_care` | 1,200 | Fake support numbers |
| `sim_trai` | 1,200 | SIM block threats |
| `apk_malware` | 1,000 | Malicious app links |
| `sextortion` | 1,000 | Blackmail threats |
| `challan_traffic` | 800 | Fake traffic fines |
| `boss_ceo_fraud` | 800 | Executive impersonation |

### Key Differentiator for Family Scams

| SCAM Pattern | Hard Negative (HAM) Pattern |
|--------------|----------------------------|
| "Mom hospital, **send 50k**" | "Mom hospital, **discharged, all okay**" |
| "Papa police station, **transfer money**" | "Papa police station **ke paas, picking you**" |
| "Trouble, **need money urgently**" | "Trouble **but sorted now**, thanks" |

---

## HAM (General) Categories (20%)

| Category | Per-Lang Target | Key Focus |
|----------|-----------------|-----------|
| `personal_family_casual` | 2,500 | Casual family chat (no emotion) |
| `personal_friends` | 2,000 | Friend conversations |
| `work_professional` | 2,000 | Office/work messages |
| `promotional_retail` | 1,500 | Zomato, Myntra, Amazon |
| `promotional_banking` | 1,000 | Real bank alerts |
| `promotional_travel` | 1,000 | Flight, hotel confirmations |

---

## OTP Categories (10%)

| Category | Per-Lang Target |
|----------|-----------------|
| `otp_banking` | 2,000 |
| `otp_wallet` | 1,500 |
| `otp_ecommerce` | 800 |
| `otp_social` | 500 |
| `otp_government` | 200 |

> **Why 5k per language is enough:**
> - OTP pattern is structurally simple: `[SERVICE] + "OTP" + [DIGITS]`
> - Model will achieve 99.9% OTP accuracy after ~2k examples
> - Extra OTP samples waste training capacity on an easy problem

---

## Language-Specific Examples

### Hard Negative Examples (THE CRITICAL ONES)

| Language | Message | Why HAM (not SCAM) |
|----------|---------|-------------------|
| English | "Was in hospital, discharged now, all good" | Positive outcome, no money ask |
| Hinglish | "Mushkil mein tha lekin ab sab theek" | Past tense trouble, resolved |
| Hindi | "परेशानी थी पर अब ठीक हो गया" | Self-resolved problem |
| Marathi | "अडचण होती पण आता ठीक आहे" | Self-resolved problem |
| English | "Mom, I'm sad today, can you call?" | Emotional, asks for call not money |
| Hinglish | "Hospital pahunch gaye, pray karo" | Asks for prayer not money |

### SCAM Examples (Contrast)

| Language | Message | Why SCAM |
|----------|---------|----------|
| English | "In hospital, need 50k urgently, send to this UPI" | Money + urgency + UPI |
| Hinglish | "Mushkil mein hun, 50000 bhejo jaldi" | Present tense + money ask |
| Hindi | "परेशानी में हूं, ₹50000 भेजो" | Direct money request |
| Marathi | "अडचणीत आहे, ₹50000 पाठवा" | Direct money request |

---

## Triplet Generation (50k pairs)

### Priority Weighting for Triplets

| Triplet Type | Count | Focus |
|--------------|-------|-------|
| Emotional (SCAM ↔ Hard Neg) | 30,000 | **Core problem** |
| Financial (SCAM ↔ Promo HAM) | 10,000 | KYC vs real bank |
| Urgency (SCAM ↔ Work HAM) | 10,000 | Fake vs real urgency |

### Triplet Format

```json
{
  "anchor": "Mummy hospital mein, 50k bhejo (SCAM)",
  "positive": "Papa police station, paisa transfer karo (SCAM)",
  "negative": "Mummy hospital pahunch gayi, all okay (HAM)"
}
```

---

## Data Quality Controls

### Pre-Generation

| Check | Threshold |
|-------|-----------|
| Minimum text length | 15 characters |
| Maximum text length | 500 characters |
| Script validation | Match expected per language |
| Money ask detection | SCAM must have it, Hard Neg must NOT |

### Post-Generation Validation

| Check | Action |
|-------|--------|
| Hard Neg contains money ask? | **REJECT** (critical bug) |
| SCAM missing urgency/money? | Flag for review |
| Duplicate detection | Hash-based removal |
| Near-duplicate detection | Cosine sim > 0.95 → remove |

---

## File Structure

```
ml_pipeline/
├── data_v2/
│   ├── english/
│   │   ├── scam.csv           # 20k
│   │   ├── hard_negative.csv  # 15k (THE CORE FIX)
│   │   ├── ham_general.csv    # 10k
│   │   └── otp.csv            # 5k
│   ├── hinglish/
│   ├── hindi/
│   ├── marathi/
│   └── combined/
│       ├── weighted_dataset.csv
│       ├── soft_labels.parquet
│       └── triplets.json
└── taxonomy_v2.py
```

---

## Budget Allocation ($300)

| Task | Samples | Est. Cost |
|------|---------|-----------|
| SCAM generation (80k) | 80,000 | $50 |
| Hard Negative generation (60k) | 60,000 | $45 |
| HAM General generation (40k) | 40,000 | $25 |
| OTP generation (20k) | 20,000 | $10 |
| Quality validation + re-gen | - | $30 |
| Soft label scoring | 200,000 | $80 |
| Triplet generation | 50,000 | $40 |
| Buffer for retries | - | $20 |
| **Total** | **200k + 50k triplets** | **$300** |

---

## Summary: Why This Strategy Wins

| Aspect | Naive 33/33/33 | Optimized Hybrid |
|--------|----------------|------------------|
| OTP | 66k (overkill) | 20k (sufficient) |
| Hard Negatives | 4k (dangerous) | **60k (core fix)** |
| SCAM coverage | 66k | 80k (better) |
| Learned outcome | "Hospital = Scam" | **"Hospital + Money = Scam"** |

> **The Core Insight:**
> We're not training a generic classifier. We're training a model to understand:
> **"Emotion without money ask = Safe"**
> **"Emotion with money ask = Scam"**

---

## Next Document
→ [02_knowledge_distillation.md](./02_knowledge_distillation.md)
