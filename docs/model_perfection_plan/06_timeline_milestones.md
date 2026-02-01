# 📅 Timeline & Milestones

## Overview

| Phase | Duration | Key Output |
|-------|----------|------------|
| Data Foundation | Week 1-2 | 150k balanced dataset with soft labels |
| Training | Week 3 | Distilled MobileBERT model |
| Validation | Week 4-5 | Tested, calibrated model |
| Deployment | Week 6 | Production rollout |

---

## Week 1: Data Generation (Part 1)

### Day 1-2: Setup & Taxonomy

| Task | Deliverable | Owner |
|------|-------------|-------|
| Create `taxonomy_v2.py` with balanced targets | New taxonomy file | Dev |
| Set up Gemini API with GCP credits | Working API connection | Dev |
| Create `generate_balanced.py` script | Generation script | Dev |

### Day 3-5: SCAM Generation

| Task | Target | Daily Output |
|------|--------|--------------|
| Generate SCAM samples | 50,000 | ~10k/day |
| Quality check (manual) | 100/day random spot check | - |
| De-duplicate | 0 duplicates | - |

### Day 6-7: HAM & OTP Generation

| Task | Target |
|------|--------|
| Generate HAM samples | 50,000 |
| Generate OTP samples | 50,000 |
| Combine into `balanced_dataset.csv` | 150,000 total |

### Week 1 Checkpoint ✅

- [ ] 150k samples generated
- [ ] Class balance: 33/33/33 (±2%)
- [ ] Emotional keywords in all classes
- [ ] No duplicates
- [ ] Quality spot-check passed

---

## Week 2: Soft Labels & Triplets

### Day 8-10: Soft Label Generation

| Task | Deliverable |
|------|-------------|
| Send 150k samples to Gemini Pro | API calls |
| Parse probability distributions | JSON responses |
| Save to `soft_labels.parquet` | {text, probs[3]} |

### Day 11-12: Triplet Generation

| Task | Target |
|------|--------|
| Generate anchor-positive-negative triplets | 30,000 |
| Focus on emotional edge cases | 50% of triplets |
| Validate triplet quality | Manual check 200 |

### Day 13-14: Data Finalization

| Task | Deliverable |
|------|-------------|
| Merge all data into training format | `train_data.parquet` |
| Split train/val/test (80/10/10) | Three datasets |
| Create edge case test set | `edge_cases.csv` |
| Create adversarial test set | `adversarial.csv` |

### Week 2 Checkpoint ✅

- [ ] All 150k samples have soft labels
- [ ] 30k triplets generated
- [ ] Training/validation/test splits ready
- [ ] Edge case test set (200 samples)
- [ ] Budget used: ~$200 (target was $200)

---

## Week 3: Training

### Day 15-16: Training Setup

| Task | Deliverable |
|------|-------------|
| Implement `DistillationLoss` class | Training code |
| Implement `TripletLoss` class | Training code |
| Set up training script | `train_distilled.py` |
| Configure Weights & Biases logging | Experiment tracking |

### Day 17-19: Training Runs

| Run | Config | Purpose |
|-----|--------|---------|
| Run 1 | α=0.5, T=4 | Baseline |
| Run 2 | α=0.3, T=4 | More distillation |
| Run 3 | α=0.3, T=2 | Sharper distributions |
| Run 4 | α=0.3, T=6 | Softer distributions |
| Run 5 | Best config + triplets | Final model |

### Day 20-21: Model Selection

| Task | Criteria |
|------|----------|
| Evaluate all runs on validation set | F1 score |
| Select best model | Highest edge case accuracy |
| Save checkpoint | `best_distilled_model.pt` |

### Week 3 Checkpoint ✅

- [ ] 5 training runs completed
- [ ] Best model selected (expected: Run 2 or 5)
- [ ] Validation accuracy > 98%
- [ ] Edge case accuracy > 90%
- [ ] Training logged in W&B

---

## Week 4: Validation

### Day 22-24: Comprehensive Testing

| Test Suite | Samples | Target Accuracy |
|------------|---------|-----------------|
| Standard test set | 15,000 | > 99% |
| Edge cases (emotional) | 200 | > 95% |
| Adversarial | 100 | > 90% |
| Regression (classic scams) | 500 | > 99% |

### Day 25-26: Calibration

| Task | Deliverable |
|------|-------------|
| Run calibration tests | Reliability diagram |
| Apply isotonic regression if needed | Calibrated model |
| Verify confidence = accuracy | Within 5% error |

### Day 27-28: Bug Fixes & Refinement

| Task | Action |
|------|--------|
| Analyze failure cases | Document patterns |
| Add to training data if needed | Augmentation |
| Retrain if significant issues | Quick 1-epoch fine-tune |

### Week 4 Checkpoint ✅

- [ ] All test suites pass thresholds
- [ ] Calibration error < 5%
- [ ] No critical failure patterns
- [ ] Model approved for deployment

---

## Week 5: Pre-Deployment

### Day 29-30: TFLite Conversion

| Task | Deliverable |
|------|-------------|
| Convert PyTorch → TFLite (FP16) | `scam_detector_v2.tflite` |
| Validate TFLite matches PyTorch | < 1% prediction difference |
| Size check | < 30MB |

### Day 31-32: Integration Testing

| Task | Deliverable |
|------|-------------|
| Replace model in Flutter app | App build |
| Run full inference tests on device | Logcat verification |
| Test on multiple devices | at least 3 Android devices |

### Day 33-35: Feature Flag Setup

| Task | Deliverable |
|------|-------------|
| Add v2 model to assets | Both models in app |
| Implement feature flag logic | `FeatureFlags` class |
| Set up Firebase Remote Config | Cloud control |
| Test rollback mechanism | Works within 5 min |

### Week 5 Checkpoint ✅

- [ ] TFLite model validated
- [ ] Runs correctly on physical devices
- [ ] Feature flag system working
- [ ] Rollback tested and documented

---

## Week 6: Deployment

### Day 36-37: Canary Release

| Task | Target |
|------|--------|
| Deploy to 1% of users | ~100 users |
| Monitor for 48 hours | Dashboard active |
| Check false positive rate | < 3% |

### Day 38-39: Expanded Rollout

| Day | Percentage | Monitoring |
|-----|------------|------------|
| Day 38 | 5% → 25% | Continuous |
| Day 39 | 25% → 50% | Continuous |

### Day 40-41: Full Rollout

| Task | Target |
|------|--------|
| Increase to 75% | Day 40 |
| Increase to 100% | Day 41 |
| Celebrate 🎉 | Day 41 |

### Day 42: Cleanup

| Task | Deliverable |
|------|-------------|
| Remove v1 model from assets | App size reduction |
| Remove feature flag code | Clean code |
| Document lessons learned | Postmortem doc |
| Archive experiment data | GCS/S3 backup |

### Week 6 Checkpoint ✅

- [ ] 100% rollout complete
- [ ] No critical issues in 7 days
- [ ] User feedback positive
- [ ] Documentation updated

---

## Risk Mitigation Timeline

| Risk | Detection | Response |
|------|-----------|----------|
| Data quality issues | Week 1 spot checks | Regenerate affected category |
| Training instability | Week 3 W&B monitoring | Adjust hyperparameters |
| Poor edge case performance | Week 4 tests | Add more triplets, retrain |
| TFLite mismatch | Week 5 validation | Debug conversion, retry |
| Production issues | Week 6 monitoring | Rollback, investigate |

---

## Success Celebration 🎉

### When All Milestones Complete

| Metric | Target | Status |
|--------|--------|--------|
| Overall Accuracy | 99%+ | _TBD_ |
| Emotional Edge Cases | 95%+ | _TBD_ |
| False Positive Rate | < 2% | _TBD_ |
| Deployment | 100% | _TBD_ |

**Celebration Ideas:**
- Team dinner/party
- LinkedIn announcement
- Case study writeup
- Submit to ML conference?

---

## Quick Reference

```
Week 1: Generate 150k balanced data
Week 2: Soft labels + triplets
Week 3: Train distilled model
Week 4: Validate thoroughly
Week 5: TFLite + integration
Week 6: Deploy gradually
```

**Total Budget**: $300-400 of $600 available
**Remaining Buffer**: ~$200 for future iterations
