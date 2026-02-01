# ✅ Validation Framework

## Objective
Prove the distilled model works correctly through comprehensive testing:
- Standard metrics (accuracy, precision, recall)
- Edge case testing (emotional, cultural)
- Adversarial testing (intentionally tricky)
- Regression testing (no performance drop)

---

## Test Suite Architecture

```
validation/
├── standard/
│   ├── test_accuracy.py
│   ├── test_precision_recall.py
│   └── test_confusion_matrix.py
├── edge_cases/
│   ├── test_emotional_messages.py
│   ├── test_family_communications.py
│   └── test_indian_context.py
├── adversarial/
│   ├── test_scam_disguised_as_ham.py
│   └── test_ham_with_scam_keywords.py
├── regression/
│   ├── test_classic_scams.py
│   └── test_otp_detection.py
└── datasets/
    ├── edge_cases.csv
    ├── adversarial.csv
    └── benchmark.csv
```

---

## Standard Metrics

### Primary Metrics

| Metric | Formula | Target |
|--------|---------|--------|
| Accuracy | (TP+TN) / Total | > 99% |
| Precision (SCAM) | TP_scam / (TP_scam + FP_scam) | > 98% |
| Recall (SCAM) | TP_scam / (TP_scam + FN_scam) | > 97% |
| F1 Score | 2 × (P×R)/(P+R) | > 97% |

### Per-Class Metrics

| Class | Target Precision | Target Recall |
|-------|------------------|---------------|
| HAM | > 98% | > 99% |
| OTP | > 99% | > 99% |
| SCAM | > 97% | > 96% |

### Confusion Matrix Analysis

```
              Predicted
              HAM   OTP   SCAM
Actual HAM    [98%]  [1%]  [1%]   ← Max 1% false scam
       OTP    [0%]  [99%]  [1%]
       SCAM   [3%]  [1%]  [96%]   ← Allow 3% false safe
```

---

## Edge Case Test Suite

### Category 1: Emotional Family Messages (50 cases)

| Test ID | Message | Expected | Critical? |
|---------|---------|----------|-----------|
| EF-001 | "Mummy, I'm sad today" | HAM | ✅ |
| EF-002 | "Papa, bad day at work" | HAM | ✅ |
| EF-003 | "Mom, I need to talk" | HAM | ✅ |
| EF-004 | "Dad, I'm in trouble with homework" | HAM | ✅ |
| EF-005 | "Mummy ghar kab aaogi, miss you" | HAM | ✅ |
| EF-006 | "Beta, hospital appointment is tomorrow" | HAM | ✅ |
| EF-007 | "Family emergency - grandpa is unwell" | HAM | ✅ |
| EF-008 | "Mom I lost my phone, calling from friend's" | HAM | ✅ |
| EF-009 | "Papa, police stopped me for documents" | HAM | ✅ |
| EF-010 | "Urgent: Meeting with principal tomorrow" | HAM | ✅ |

### Category 2: Family Emergency Scams (50 cases)

| Test ID | Message | Expected | Critical? |
|---------|---------|----------|-----------|
| FS-001 | "Mummy, hospital admit, 50k bhejo" | SCAM | ✅ |
| FS-002 | "Papa, police station, need 1 lakh bail" | SCAM | ✅ |
| FS-003 | "Mom, accident happened, send money to this UPI" | SCAM | ✅ |
| FS-004 | "Dad, in jail, transfer money urgently" | SCAM | ✅ |
| FS-005 | "Your son is in hospital, pay 25000 now" | SCAM | ✅ |
| FS-006 | "I am your son's friend, he needs money" | SCAM | ✅ |
| FS-007 | "Beta, this is doctor, surgery cost 50k" | SCAM | ✅ |
| FS-008 | "Mom new number, old phone stolen, send money" | SCAM | ✅ |
| FS-009 | "Papa, custom officer, gift parcel fee 10k" | SCAM | ✅ |
| FS-010 | "Mummy, friend's funeral, need urgent help money" | SCAM | ✅ |

### Category 3: Indian Context (30 cases)

| Test ID | Message | Expected |
|---------|---------|----------|
| IC-001 | "Zomato order arriving in 10 mins" | HAM |
| IC-002 | "Swiggy refund of Rs.150 processed" | HAM |
| IC-003 | "PhonePe: Payment of Rs.500 successful" | HAM |
| IC-004 | "IRCTC booking confirmed, PNR 123456" | HAM |
| IC-005 | "Ola ride booked, driver arriving" | HAM |
| IC-006 | "BJP/Congress rally, vote for us" | HAM |
| IC-007 | "Diwali offer! 50% off on Myntra" | HAM |
| IC-008 | "GST registration pending, click here" | SCAM |
| IC-009 | "TRAI: SIM block in 24 hours" | SCAM |
| IC-010 | "Income tax refund 25000, submit PAN" | SCAM |

### Category 4: Hinglish Messages (30 cases)

| Test ID | Message | Expected |
|---------|---------|----------|
| HL-001 | "Bhai, party kab hai?" | HAM |
| HL-002 | "Yaar, office mein tension chal rahi" | HAM |
| HL-003 | "Urgent: Aapka account block ho jayega" | SCAM |
| HL-004 | "Paisa bhejo, bahut zarurat hai" | SCAM |
| HL-005 | "Kal milte hain, same time" | HAM |
| HL-006 | "KYC update karo, nahi to account band" | SCAM |
| HL-007 | "Ghar pahunch gaya, don't worry" | HAM |
| HL-008 | "Lottery jeeta hai aapne, claim now" | SCAM |
| HL-009 | "Lunch kha liya? Main office mein" | HAM |
| HL-010 | "Police complaint, case register hoga" | SCAM |

---

## Adversarial Test Suite

### Purpose
Test model against intentionally crafted messages designed to fool it.

### Type 1: Scams disguised as HAM

| Test ID | Message | Trick | Expected |
|---------|---------|-------|----------|
| ADV-001 | "Hey friend, check out my new investment app" | Casual tone | SCAM |
| ADV-002 | "Good morning! Your refund is ready" | Pleasant greeting | SCAM |
| ADV-003 | "Family reunion next week, please pay here" | Family context | SCAM |
| ADV-004 | "Happy birthday! Click to claim gift" | Celebration | SCAM |
| ADV-005 | "Office party, contribute Rs.500 to this UPI" | Work context | SCAM |

### Type 2: HAM with scam-like keywords

| Test ID | Message | Keyword Trap | Expected |
|---------|---------|--------------|----------|
| ADV-011 | "Meeting urgent, come to office now" | "urgent" | HAM |
| ADV-012 | "Hospital visit went well, feeling better" | "hospital" | HAM |
| ADV-013 | "Police uncle visited school for safety talk" | "police" | HAM |
| ADV-014 | "Got the money you sent, thanks!" | "money" | HAM |
| ADV-015 | "Help me choose a dress for party" | "help" | HAM |

---

## Benchmark Dataset

### Composition

| Source | Samples | Purpose |
|--------|---------|---------|
| Edge cases (manual) | 200 | Emotional testing |
| Adversarial (crafted) | 100 | Robustness testing |
| Real scams (anonymized) | 500 | Production realism |
| Real HAM (anonymized) | 500 | Production realism |
| OTP samples | 200 | OTP accuracy |
| **Total** | **1,500** | Golden test set |

### Collection Criteria

1. **In-the-Wild**: Real messages from user reports (anonymized)
2. **Expert-Curated**: Security researchers' scam samples
3. **Synthetic Edge**: LLM-generated edge cases
4. **Regional Variety**: North/South/East/West India

---

## Regression Testing

### Purpose
Ensure new model doesn't lose performance on "easy" cases.

### Baseline Categories (Must Pass 99%+)

| Category | Sample Count | Min Accuracy |
|----------|--------------|--------------|
| Classic lottery scams | 100 | 99% |
| KYC phishing | 100 | 99% |
| Link-based scams | 100 | 99% |
| Standard OTPs | 100 | 99% |
| Promotional HAM | 100 | 99% |

### Regression Script

```python
def test_regression(model, baseline_dataset):
    results = {}
    for category, samples in baseline_dataset.items():
        preds = [model.predict(s['text']) for s in samples]
        accuracy = sum(p == s['label'] for p, s in zip(preds, samples)) / len(samples)
        results[category] = accuracy
        assert accuracy >= 0.99, f"Regression in {category}: {accuracy}"
    return results
```

---

## Confidence Calibration Testing

### Test: Probability Reliability

```python
def test_calibration(model, test_set):
    """
    Check if 80% confidence means 80% real accuracy
    """
    bins = defaultdict(list)
    
    for sample in test_set:
        pred, conf = model.predict_with_confidence(sample['text'])
        bin_idx = int(conf * 10)  # 0-10 bins
        bins[bin_idx].append(pred == sample['label'])
    
    for bin_idx, results in sorted(bins.items()):
        expected_accuracy = (bin_idx + 0.5) / 10
        actual_accuracy = sum(results) / len(results)
        error = abs(expected_accuracy - actual_accuracy)
        print(f"Bin {bin_idx*10}-{(bin_idx+1)*10}%: Expected {expected_accuracy:.0%}, Got {actual_accuracy:.0%}")
        assert error < 0.1, f"Calibration error in bin {bin_idx}"
```

---

## A/B Testing Framework

### Pre-Production Testing

| Group | Model | Users | Duration |
|-------|-------|-------|----------|
| Control | Current (v1) | 50% | 2 weeks |
| Treatment | New (v2) | 50% | 2 weeks |

### Metrics to Track

| Metric | How to Measure | Target |
|--------|----------------|--------|
| False Positive Rate | User reports "not scam" | < 2% |
| False Negative Rate | User reports "missed scam" | < 3% |
| User Engagement | App opens, manual scans | Increase |
| Latency | Time to prediction | < 100ms |

### Statistical Significance

```python
from scipy import stats

def ab_test_significance(control_rate, treatment_rate, n_control, n_treatment):
    z = (treatment_rate - control_rate) / \
        np.sqrt(control_rate * (1-control_rate) * (1/n_control + 1/n_treatment))
    p_value = 1 - stats.norm.cdf(abs(z))
    return p_value < 0.05  # Significant if True
```

---

## Continuous Integration

### Automated Test Pipeline

```yaml
# .github/workflows/model_validation.yml
name: Model Validation

on:
  push:
    paths:
      - 'ml_pipeline/**'

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run edge case tests
        run: pytest validation/edge_cases/ -v
      - name: Run regression tests
        run: pytest validation/regression/ -v
      - name: Check accuracy thresholds
        run: python validation/check_thresholds.py
```

---

## Next Document
→ [05_deployment_strategy.md](./05_deployment_strategy.md)
