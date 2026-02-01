# ⚙️ Training Architecture Plan

## Objective
Design a robust, reproducible training pipeline that combines:
- Distillation Loss (from teacher)
- Triplet Loss (for hard negatives)
- Classification Loss (for accuracy)

---

## Model Architecture

### Base Model: MobileBERT

| Property | Value |
|----------|-------|
| Model | `google/mobilebert-uncased` |
| Parameters | 25.3M |
| Hidden Size | 512 |
| Layers | 24 |
| Heads | 4 |
| Vocab Size | 30,522 |

### Classification Head

```python
class ScamClassifier(nn.Module):
    def __init__(self, base_model):
        super().__init__()
        self.bert = base_model
        self.dropout = nn.Dropout(0.3)
        self.classifier = nn.Linear(512, 3)  # HAM, OTP, SCAM
    
    def forward(self, input_ids, attention_mask):
        outputs = self.bert(input_ids, attention_mask)
        pooled = outputs.pooler_output
        pooled = self.dropout(pooled)
        logits = self.classifier(pooled)
        return logits
```

---

## Multi-Objective Training

### Combined Loss Function

```
Total Loss = λ₁ × L_distill + λ₂ × L_triplet + λ₃ × L_classification

Where:
- λ₁ = 0.5 (distillation weight)
- λ₂ = 0.3 (triplet weight)
- λ₃ = 0.2 (classification weight)
```

### Loss Components

#### 1. Distillation Loss (from previous doc)
```python
L_distill = α × CE(student, hard) + (1-α) × T² × KL(student_soft, teacher_soft)
```

#### 2. Triplet Loss
```python
class TripletLoss(nn.Module):
    def __init__(self, margin=1.0):
        super().__init__()
        self.margin = margin
    
    def forward(self, anchor, positive, negative):
        # anchor, positive = same class
        # negative = different class (hard negative)
        pos_dist = F.pairwise_distance(anchor, positive)
        neg_dist = F.pairwise_distance(anchor, negative)
        loss = F.relu(pos_dist - neg_dist + self.margin)
        return loss.mean()
```

#### 3. Classification Loss (backup)
```python
L_classification = CrossEntropyLoss(student_logits, hard_labels)
```

---

## Training Configuration

### Hyperparameters

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Learning Rate | 2e-5 | Standard for BERT fine-tuning |
| Batch Size | 32 | Balance of memory and gradient stability |
| Epochs | 5 | Early stopping on val loss |
| Warmup Steps | 10% | Gradual LR increase |
| Weight Decay | 0.01 | Regularization |
| Max Seq Length | 128 | Most SMS < 160 chars |
| Dropout | 0.3 | Prevent overfitting |

### Optimizer: AdamW

```python
optimizer = torch.optim.AdamW(
    model.parameters(),
    lr=2e-5,
    weight_decay=0.01,
    betas=(0.9, 0.999)
)
```

### Learning Rate Scheduler

```python
from transformers import get_linear_schedule_with_warmup

scheduler = get_linear_schedule_with_warmup(
    optimizer,
    num_warmup_steps=int(0.1 * total_steps),
    num_training_steps=total_steps
)
```

---

## Data Loading Strategy

### Training Data Split

| Set | Percentage | Samples | Purpose |
|-----|------------|---------|---------|
| Train | 80% | 120,000 | Model learning |
| Validation | 10% | 15,000 | Early stopping |
| Test | 10% | 15,000 | Final evaluation |

### Stratified Sampling
```python
from sklearn.model_selection import train_test_split

train, temp = train_test_split(data, test_size=0.2, stratify=data['label'])
val, test = train_test_split(temp, test_size=0.5, stratify=temp['label'])
```

### DataLoader Configuration
```python
train_loader = DataLoader(
    train_dataset,
    batch_size=32,
    shuffle=True,
    num_workers=4,
    pin_memory=True
)
```

---

## Training Loop Structure

```python
def train_epoch(model, loader, optimizer, scheduler, criterion):
    model.train()
    total_loss = 0
    
    for batch in tqdm(loader):
        # Unpack batch
        input_ids = batch['input_ids'].to(device)
        attention_mask = batch['attention_mask'].to(device)
        hard_labels = batch['labels'].to(device)
        teacher_logits = batch['teacher_logits'].to(device)
        
        # Forward pass
        student_logits = model(input_ids, attention_mask)
        
        # Compute losses
        distill_loss = distillation_criterion(
            student_logits, teacher_logits, hard_labels
        )
        
        # If triplet batch available
        if 'anchor_ids' in batch:
            anchor_emb = model.get_embedding(batch['anchor_ids'])
            pos_emb = model.get_embedding(batch['pos_ids'])
            neg_emb = model.get_embedding(batch['neg_ids'])
            triplet_loss = triplet_criterion(anchor_emb, pos_emb, neg_emb)
        else:
            triplet_loss = 0
        
        # Combined loss
        loss = 0.5 * distill_loss + 0.3 * triplet_loss + 0.2 * class_loss
        
        # Backward pass
        optimizer.zero_grad()
        loss.backward()
        torch.nn.utils.clip_grad_norm_(model.parameters(), 1.0)
        optimizer.step()
        scheduler.step()
        
        total_loss += loss.item()
    
    return total_loss / len(loader)
```

---

## Early Stopping

```python
class EarlyStopping:
    def __init__(self, patience=3, min_delta=0.001):
        self.patience = patience
        self.min_delta = min_delta
        self.counter = 0
        self.best_loss = float('inf')
        self.early_stop = False
    
    def __call__(self, val_loss, model):
        if val_loss < self.best_loss - self.min_delta:
            self.best_loss = val_loss
            self.counter = 0
            self.save_checkpoint(model)
        else:
            self.counter += 1
            if self.counter >= self.patience:
                self.early_stop = True
```

---

## Gradient Accumulation (for larger effective batch)

```python
accumulation_steps = 4
effective_batch_size = 32 * 4  # = 128

for i, batch in enumerate(loader):
    loss = compute_loss(batch)
    loss = loss / accumulation_steps
    loss.backward()
    
    if (i + 1) % accumulation_steps == 0:
        optimizer.step()
        scheduler.step()
        optimizer.zero_grad()
```

---

## Mixed Precision Training

```python
from torch.cuda.amp import GradScaler, autocast

scaler = GradScaler()

for batch in loader:
    with autocast():
        logits = model(input_ids, attention_mask)
        loss = criterion(logits, labels)
    
    scaler.scale(loss).backward()
    scaler.step(optimizer)
    scaler.update()
    optimizer.zero_grad()
```

**Benefits**:
- 2x faster training
- 50% less memory usage
- No accuracy loss

---

## Hardware Requirements

| Resource | Minimum | Recommended |
|----------|---------|-------------|
| GPU | GTX 1660 (6GB) | RTX 3080 (10GB) |
| RAM | 16GB | 32GB |
| Storage | 20GB SSD | 50GB SSD |
| Training Time | 4 hours | 2 hours |

### Google Colab Alternative

```python
# Use Colab Pro for T4/A100
!pip install transformers torch
# Upload data to Google Drive
# Run training notebook
```

---

## Checkpointing Strategy

```python
# Save best model
torch.save({
    'epoch': epoch,
    'model_state_dict': model.state_dict(),
    'optimizer_state_dict': optimizer.state_dict(),
    'loss': best_loss,
    'config': config
}, 'checkpoints/best_model.pt')

# Save every epoch
torch.save(model.state_dict(), f'checkpoints/epoch_{epoch}.pt')
```

---

## Experiment Tracking

### Using Weights & Biases

```python
import wandb

wandb.init(project="detooz-distillation", config=config)

# Log metrics
wandb.log({
    "train_loss": train_loss,
    "val_loss": val_loss,
    "accuracy": accuracy,
    "learning_rate": scheduler.get_last_lr()[0]
})

# Log model
wandb.save('checkpoints/best_model.pt')
```

---

## Next Document
→ [04_validation_framework.md](./04_validation_framework.md)
