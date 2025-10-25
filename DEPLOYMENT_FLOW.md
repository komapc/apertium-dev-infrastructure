# Dictionary Deployment Flow

## Complete Workflow

```
┌─────────────────────────────────────────────────────────────┐
│  1. Run Extractor on EC2                                   │
│     ./run_extractor.sh                                      │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ EC2 Instance                                          │  │
│  │  ├─ Clone extractor repo                              │  │
│  │  ├─ Install dependencies                               │  │
│  │  ├─ Download dumps                                     │  │
│  │  ├─ Parse sources                                       │  │
│  │  ├─ Merge dictionaries                                 │  │
│  │  └─ Export Apertium files                              │  │
│  │     ├─ apertium-ido.ido.dix (monolingual)             │  │
│  │     └─ apertium-ido-epo.ido-epo.dix (bilingual)       │  │
│  └─────────────────────────────────────────────────────┘  │
│         │                                                   │
│         ▼                                                   │
│  Copy results locally                                       │
│  extractor-results/20251025-182612/                        │
│         │                                                   │
│         ▼                                                   │
│  Upload to S3                                               │
│  s3://ido-epo-extractor-results/20251025-182612/           │
│         │                                                   │
│         ▼                                                   │
│  Stop EC2 instance                                          │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  2. Deploy Dictionaries                                     │
│     ./deploy_dictionaries.sh                               │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │ Local Machine                                        │  │
│  │  ├─ Clone apertium-ido                               │  │
│  │  ├─ Clone apertium-ido-epo                            │  │
│  │  ├─ Copy dictionaries                                 │  │
│  │  ├─ Create feature branches                           │  │
│  │  ├─ Commit changes                                    │  │
│  │  ├─ Push branches                                     │  │
│  │  └─ Create PRs via GitHub CLI                         │  │
│  └─────────────────────────────────────────────────────┘  │
│         │                                                   │
│         ▼                                                   │
│  PRs Created                                                │
│  ├─ komapc/apertium-ido PR#X                               │
│  └─ komapc/apertium-ido-epo PR#Y                           │
└─────────────────────────────────────────────────────────────┘
         │
         ▼
┌─────────────────────────────────────────────────────────────┐
│  3. Review & Merge                                          │
│     Review PRs on GitHub                                    │
│     Run tests if available                                  │
│     Merge when ready                                        │
└─────────────────────────────────────────────────────────────┘
```

## File Flow

```
Extractor Output:
├── apertium-ido.ido.dix          → apertium-ido repo
└── apertium-ido-epo.ido-epo.dix  → apertium-ido-epo repo
```

## Timing

| Step | Duration | Frequency |
|------|----------|-----------|
| Download dumps | 10-30 min | Once per run |
| Parse sources | 30-60 min | Once per run |
| Merge dictionaries | 5-10 min | Once per run |
| Export to Apertium | 2-5 min | Once per run |
| **Total extractor** | **50-110 min** | **On-demand** |
| Deploy dictionaries | 2-5 min | After extractor |
| Review & merge | 5-30 min | Manual |

**Total:** ~1-2 hours end-to-end

## Cost

| Component | Cost |
|-----------|------|
| EC2 runtime | $0.02-0.04 |
| S3 storage | $0.001-0.005 |
| Deployment | $0 (GitHub free) |
| **Total** | **~$0.03 per run** |

## Automation Levels

### Level 1: Manual (Current)
```bash
./run_extractor.sh              # Manual trigger
./deploy_dictionaries.sh        # Manual trigger
# Review PRs manually
```

### Level 2: Semi-Automatic (Next)
```bash
./run_extractor.sh && ./deploy_dictionaries.sh
# Review PRs manually
```

### Level 3: Fully Automatic (Future)
```bash
# Webhook triggers everything
# PRs created automatically
# You just review and merge
```

## Dependencies

### Required
- ✅ GitHub CLI (`gh`)
- ✅ GitHub authentication
- ✅ AWS CLI configured
- ✅ SSH key for EC2

### Optional
- AWS Lambda (for full automation)
- GitHub Actions (for CI/CD)
- S3 bucket (for backup)

## Error Handling

### If Deploy Fails
- PR not created? Check GitHub CLI auth
- Can't push? Check repository permissions
- Can't clone? Check internet connection

### Recovery
- Script cleans up temp directories
- Failed PRs don't affect repos
- Can re-run deployment script safely

## Workflow Examples

### Example 1: Standard Run
```bash
# Run extractor
cd terraform
./run_extractor.sh

# After completion, deploy
./deploy_dictionaries.sh

# Review PRs on GitHub
gh pr list --repo komapc/apertium-ido
gh pr list --repo komapc/apertium-ido-epo
```

### Example 2: Custom Results Directory
```bash
# Use specific results
./deploy_dictionaries.sh extractor-results/20251025-182612
```

### Example 3: Deploy from S3
```bash
# Download from S3 first
aws s3 sync s3://ido-epo-extractor-results/20251025-182612/ ./local-results/

# Deploy
./deploy_dictionaries.sh local-results
```

