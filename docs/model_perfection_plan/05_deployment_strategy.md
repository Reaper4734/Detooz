# 🚀 Deployment Strategy

## Objective
Deploy the distilled model safely with:
- Zero downtime
- Easy rollback
- Gradual rollout
- Real-time monitoring

---

## Deployment Pipeline

```
[Training Complete] → [TFLite Export] → [Validation Pass] → [Canary Deploy] → [Gradual Rollout] → [Full Deploy]
                                                ↓                                       ↓
                                           [Rollback] ←←←←←←← [Issue Detected] ←←←←←←←←←
```

---

## Phase 1: TFLite Conversion

### Conversion Script

```python
def convert_and_validate():
    # 1. Load trained PyTorch model
    model = load_checkpoint('checkpoints/best_model.pt')
    
    # 2. Convert to TFLite
    tflite_model = convert_to_tflite(
        model,
        input_signature=[1, 128],
        quantization='fp16'
    )
    
    # 3. Validate predictions match
    test_messages = load_test_set()
    for msg in test_messages:
        pytorch_pred = model.predict(msg)
        tflite_pred = tflite_model.predict(msg)
        assert abs(pytorch_pred - tflite_pred) < 0.01
    
    # 4. Save to assets
    save_tflite('app/assets/scam_detector_v2.tflite')
```

### Model Versioning

| Version | File | Size | Description |
|---------|------|------|-------------|
| v1 | `scam_detector.tflite` | 25MB | Current production |
| v2 | `scam_detector_v2.tflite` | 25MB | Distilled model |
| v1_backup | `scam_detector_backup.tflite` | 25MB | Rollback copy |

---

## Phase 2: Feature Flag System

### Implementation

```dart
// lib/services/feature_flags.dart
class FeatureFlags {
  static const bool USE_DISTILLED_MODEL = false;  // Toggle
  static const double ROLLOUT_PERCENTAGE = 0.0;   // 0-100%
  static const String MODEL_VERSION = 'v1';
  
  static bool shouldUseNewModel(String userId) {
    if (!USE_DISTILLED_MODEL) return false;
    
    // Hash-based consistent assignment
    final hash = userId.hashCode.abs() % 100;
    return hash < ROLLOUT_PERCENTAGE;
  }
}
```

### Remote Config (Firebase)

```dart
// Fetch from Firebase Remote Config
final remoteConfig = FirebaseRemoteConfig.instance;
await remoteConfig.fetchAndActivate();

final useNewModel = remoteConfig.getBool('use_distilled_model');
final rolloutPercent = remoteConfig.getDouble('model_rollout_percent');
```

---

## Phase 3: Gradual Rollout

### Rollout Schedule

| Day | Percentage | Users | Action |
|-----|------------|-------|--------|
| 1 | 1% | ~100 | Canary testing |
| 3 | 5% | ~500 | Early adopters |
| 5 | 25% | ~2,500 | Expanded testing |
| 7 | 50% | ~5,000 | Half population |
| 10 | 75% | ~7,500 | Majority |
| 14 | 100% | All | Full rollout |

### Go/No-Go Criteria at Each Stage

| Metric | Threshold | Action if Exceeded |
|--------|-----------|-------------------|
| False positive rate | > 3% | Pause, investigate |
| User complaints | > 5/day | Reduce rollout % |
| Crash rate | > 0.1% | Immediate rollback |
| Latency p99 | > 200ms | Investigate |

---

## Phase 4: Monitoring Dashboard

### Real-Time Metrics

```
┌─────────────────────────────────────────────────────────┐
│ 📊 Model V2 Performance Dashboard                       │
├─────────────────────────────────────────────────────────┤
│ Rollout: [===========                    ] 35%          │
│                                                         │
│ ┌─────────────┬─────────────┬─────────────┐            │
│ │ Predictions │ v1 (65%)    │ v2 (35%)    │            │
│ ├─────────────┼─────────────┼─────────────┤            │
│ │ Total       │ 12,450      │ 6,720       │            │
│ │ SCAM        │ 1,245 (10%) │ 672 (10%)   │            │
│ │ HAM         │ 10,830 (87%)│ 5,847 (87%) │            │
│ │ OTP         │ 375 (3%)    │ 201 (3%)    │            │
│ └─────────────┴─────────────┴─────────────┘            │
│                                                         │
│ False Positives Today: 3 (0.09%)  ✅ Below threshold   │
│ User Reports: 1                    ✅ Normal            │
│ Avg Latency: 45ms                  ✅ Good              │
└─────────────────────────────────────────────────────────┘
```

### Alerting Rules

| Alert | Condition | Action |
|-------|-----------|--------|
| 🔴 Critical | Crash rate > 0.5% | Page on-call, auto-rollback |
| 🟠 Warning | FP rate > 2% | Slack notification |
| 🟡 Info | Latency > 100ms | Log for review |
| 🟢 Success | Rollout complete | Celebration 🎉 |

---

## Phase 5: Rollback Procedure

### Automatic Rollback

```dart
// If critical metrics exceeded, auto-rollback
class ModelManager {
  Future<void> checkAndRollback() async {
    final metrics = await fetchMetrics();
    
    if (metrics.falsePositiveRate > 0.03 || 
        metrics.crashRate > 0.001) {
      await rollbackToV1();
      await notifyTeam('Auto-rollback triggered');
    }
  }
  
  Future<void> rollbackToV1() async {
    // Switch feature flag
    await FirebaseRemoteConfig.instance.setDefaults({
      'use_distilled_model': false,
      'model_rollout_percent': 0.0,
    });
    
    // Force refresh on next app open
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('force_model_refresh', true);
  }
}
```

### Manual Rollback Steps

1. **Firebase Console** → Remote Config → Set `use_distilled_model = false`
2. **Force Publish** → Immediate propagation
3. **Verify** → Check dashboard shows 0% on v2
4. **Postmortem** → Document what went wrong

---

## Phase 6: Post-Deployment

### Success Criteria (Day 14+)

| Metric | Target | Actual |
|--------|--------|--------|
| Accuracy | 99%+ | _TBD_ |
| False Positive Rate | < 2% | _TBD_ |
| User Complaints | < 1/day | _TBD_ |
| Latency p50 | < 50ms | _TBD_ |

### Cleanup Tasks

1. Remove v1 model from assets (save 25MB)
2. Remove feature flag code
3. Update documentation
4. Archive experiment data

---

## Incident Response

### If Something Goes Wrong

| Severity | Example | Response Time | Action |
|----------|---------|---------------|--------|
| P1 | App crashing | 15 min | Rollback immediately |
| P2 | Wrong predictions | 1 hour | Pause rollout, investigate |
| P3 | Slow performance | 4 hours | Monitor, fix in next release |
| P4 | Minor bugs | Next sprint | Log and schedule |

### Communication Template

```
🚨 Model Deployment Incident

Status: [Investigating / Mitigating / Resolved]
Impact: [X% users affected]
Start Time: [HH:MM UTC]
Current Action: [Brief description]

Updates will be posted every [30 min / 1 hour].
```

---

## Next Document
→ [06_timeline_milestones.md](./06_timeline_milestones.md)
