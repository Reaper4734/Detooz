# 🧠 Knowledge Distillation Plan

## Objective
Transfer the "intuition" of Gemini Pro (Teacher) into MobileBERT (Student) so the local model can detect nuanced scams without cloud connectivity.

---

## The Core Concept

### Traditional Training (Current)
```
Message: "Mom I'm in hospital"
Hard Label: SCAM (1)
Loss: CrossEntropy(prediction, 1)

Problem: Model learns "hospital" = SCAM (overconfident)
```

### Distillation Training (New)
```
Message: "Mom I'm in hospital"
Hard Label: SCAM (1)
Soft Label: {ham: 0.30, otp: 0.00, scam: 0.70}  ← From Gemini
Loss: α × CE(pred, hard) + (1-α) × T² × KL(pred_soft, teacher_soft)

Benefit: Model learns "hospital" is 70% likely scam, but 30% could be real
```

---

## Teacher Model Selection

### Options Evaluated

| Model | Pros | Cons | Cost/150k |
|-------|------|------|-----------|
| **Gemini 1.5 Pro** ✅ | Best Indian context, accurate | Slower | ~$80 |
| Gemini 1.5 Flash | Fast, cheap | Less nuanced | ~$20 |
| GPT-4 | Very accurate | Poor Hindi, expensive | ~$300 |
| Llama 3.1 70B (Groq) | Free | Rate limited, less accurate | $0 |

### Decision: **Gemini 1.5 Pro**
- Best understanding of Indian banking, UPI, Hinglish
- Within budget ($80 for 150k samples)
- Native Hindi capability

---

## Distillation Architecture

### Mathematical Foundation

```
Total Loss = α × L_task + (1-α) × T² × L_distill

Where:
- L_task = CrossEntropyLoss(student_logits, hard_labels)
- L_distill = KLDivLoss(softmax(student/T), softmax(teacher/T))
- α = 0.3 (weight toward distillation)
- T = 4.0 (temperature for soft distributions)
```

### Why T² Matters

| Temperature | Effect |
|-------------|--------|
| T = 1 | Sharp distributions (overconfident) |
| T = 2 | Slightly softer |
| T = 4 | **Optimal** - reveals class relationships |
| T = 8 | Too soft, loses signal |

With T=4, the distillation loss is **16x amplified**, forcing the student to carefully match the teacher's probability distribution.

---

## Implementation Details

### Data Format

```python
# Input: training_data.parquet
{
    "text": "Mom I'm in hospital, need 50k",
    "hard_label": 2,  # 0=HAM, 1=OTP, 2=SCAM
    "teacher_logits": [-1.2, -5.0, 2.3],  # Raw logits from Gemini
    "teacher_probs": [0.08, 0.01, 0.91]   # After softmax
}
```

### Loss Function Code

```python
import torch
import torch.nn as nn
import torch.nn.functional as F

class DistillationLoss(nn.Module):
    def __init__(self, alpha=0.3, temperature=4.0):
        super().__init__()
        self.alpha = alpha
        self.T = temperature
        self.ce_loss = nn.CrossEntropyLoss()
        self.kl_loss = nn.KLDivLoss(reduction="batchmean")
    
    def forward(self, student_logits, teacher_logits, hard_labels):
        # Task Loss: Did student get the right answer?
        task_loss = self.ce_loss(student_logits, hard_labels)
        
        # Distillation Loss: Does student think like teacher?
        soft_student = F.log_softmax(student_logits / self.T, dim=1)
        soft_teacher = F.softmax(teacher_logits / self.T, dim=1)
        distill_loss = self.kl_loss(soft_student, soft_teacher)
        
        # Combined Loss
        total_loss = (
            self.alpha * task_loss + 
            (1 - self.alpha) * (self.T ** 2) * distill_loss
        )
        
        return total_loss, task_loss, distill_loss
```

---

## Hyperparameter Selection

### Alpha (α) - Task vs Distillation Balance

| α Value | Focus | Use Case |
|---------|-------|----------|
| 0.1 | 90% distillation | When teacher is highly trusted |
| **0.3** ✅ | 70% distillation | **Our choice** - balanced learning |
| 0.5 | Equal weight | Conservative approach |
| 0.7 | 70% task | When hard labels are more reliable |

**Why 0.3?**: We trust Gemini's soft labels more than our potentially noisy hard labels.

### Temperature (T)

| T Value | Effect | Result |
|---------|--------|--------|
| 2 | Less soft | Student might miss subtle patterns |
| **4** ✅ | Optimal | **Our choice** - reveals uncertainty |
| 6 | Very soft | Might be too smooth |

---

## Training Process

### Phase 1: Soft Label Generation (Pre-training)

```
1. For each message in dataset:
   a. Send to Gemini Pro
   b. Get probability distribution
   c. Save as soft label
```

### Phase 2: Distillation Training

```python
# Training Loop
for epoch in range(5):
    for batch in train_loader:
        texts, hard_labels, teacher_logits = batch
        
        # Forward pass
        student_logits = model(texts)
        
        # Compute loss
        loss, task_loss, distill_loss = criterion(
            student_logits, teacher_logits, hard_labels
        )
        
        # Backward pass
        optimizer.zero_grad()
        loss.backward()
        optimizer.step()
        
        # Log metrics
        log(f"Loss: {loss:.4f} | Task: {task_loss:.4f} | Distill: {distill_loss:.4f}")
```

### Phase 3: Post-Training Calibration

After distillation, calibrate probabilities:

```python
# Isotonic Regression for probability calibration
from sklearn.isotonic import IsotonicRegression

# Fit calibrator on validation set
calibrator = IsotonicRegression(out_of_bounds='clip')
calibrator.fit(val_probs, val_labels)

# Apply to predictions
calibrated_probs = calibrator.transform(raw_probs)
```

---

## Expected Improvements

### Before Distillation

| Edge Case | Prediction | Confidence |
|-----------|------------|------------|
| "Mom I'm sad" | SCAM | 75% ❌ |
| "Hospital, need money" | SCAM | 90% (correct) |
| "I'm in trouble helping friend" | SCAM | 65% ❌ |

### After Distillation

| Edge Case | Prediction | Confidence |
|-----------|------------|------------|
| "Mom I'm sad" | HAM | 85% ✅ |
| "Hospital, need money" | SCAM | 92% ✅ |
| "I'm in trouble helping friend" | HAM | 78% ✅ |

---

## Ablation Studies Planned

| Experiment | α | T | Purpose |
|------------|---|---|---------|
| Baseline | 0.5 | 4 | Start point |
| Task-heavy | 0.7 | 4 | If hard labels reliable |
| Distill-heavy | 0.3 | 4 | Trust teacher more |
| Cold | 0.3 | 2 | Sharp distributions |
| Warm | 0.3 | 6 | Very soft distributions |
| **Final** | 0.3 | 4 | Expected optimal |

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Teacher gives wrong soft labels | Manual review of 500 random samples |
| Overfitting to teacher | Early stopping based on validation loss |
| Catastrophic forgetting | Include original training data (10%) |
| Calibration drift | Post-training isotonic regression |

---

## Budget for This Phase

| Task | Cost |
|------|------|
| Soft label generation (150k) | $80 |
| 5 training runs (ablations) | $20 (compute) |
| Validation scoring | $10 |
| **Total** | **$110** |

---

## Next Document
→ [03_training_architecture.md](./03_training_architecture.md)
