# Dictionary Deployment Solutions

## Problem Statement

After extractor runs on EC2, it generates:
- `apertium-ido.ido.dix` (monolingual Ido dictionary)
- `apertium-ido-epo.ido-epo.dix` (bilingual dictionary)

**Need:** Automatically deploy these to:
- `apertium/apertium-ido` repository
- `apertium/apertium-ido-epo` repository

**Goal:** Push as PR for review and merge

---

## Solution 1: Local Script with GitHub CLI (RECOMMENDED)

### How It Works

```bash
# After extractor completes
1. Copy generated .dix files locally
2. Clone target repositories
3. Copy files to repos
4. Create feature branch
5. Commit changes
6. Push branch
7. Create PR via GitHub CLI
```

### Pros
- ✅ Full control
- ✅ Easy to debug
- ✅ Works with existing GitHub CLI
- ✅ Can be run manually or automated
- ✅ Can review changes before PR

### Cons
- ⚠️ Requires local GitHub access
- ⚠️ Need to handle authentication
- ⚠️ Manual step needed

### Implementation

```bash
#!/bin/bash
# deploy_dictionaries.sh

# 1. Get latest extractor results
RESULTS_DIR=$(ls -t extractor-results/ | head -1)
SOURCE_DIX="$RESULTS_DIR/apertium-ido.ido.dix"
SOURCE_BIDIX="$RESULTS_DIR/apertium-ido-epo.ido-epo.dix"

# 2. Clone repos
git clone https://github.com/komapc/apertium-ido.git /tmp/apertium-ido
git clone https://github.com/komapc/apertium-ido-epo.git /tmp/apertium-ido-epo

# 3. Copy monolingual dictionary
cp "$SOURCE_DIX" /tmp/apertium-ido/apertium-ido.ido.dix

# 4. Copy bilingual dictionary
cp "$SOURCE_BIDIX" /tmp/apertium-ido-epo/apertium-ido-epo.ido-epo.dix

# 5. Create PR for apertium-ido
cd /tmp/apertium-ido
git checkout -b dictionary-update-$(date +%Y%m%d)
git add apertium-ido.ido.dix
git commit -m "feat: Update Ido monolingual dictionary from extractor

Generated: $(date)
Source: EC2 on-demand extractor run"
git push origin dictionary-update-$(date +%Y%m%d)
gh pr create --title "Update Ido Dictionary" --body "Auto-generated from extractor"

# 6. Create PR for apertium-ido-epo
cd /tmp/apertium-ido-epo
git checkout -b dictionary-update-$(date +%Y%m%d)
git add apertium-ido-epo.ido-epo.dix
git commit -m "feat: Update bilingual dictionary from extractor

Generated: $(date)
Source: EC2 on-demand extractor run"
git push origin dictionary-update-$(date +%Y%m%d)
gh pr create --title "Update Bilingual Dictionary" --body "Auto-generated from extractor"

# 7. Cleanup
rm -rf /tmp/apertium-ido /tmp/apertium-ido-epo
```

**Run After:** EC2 extractor completes  
**Requirements:** GitHub CLI (`gh`), authentication configured

---

## Solution 2: EC2-Based Deployment Script

### How It Works

```bash
# On EC2 after extractor completes
1. Upload .dix files to S3
2. Trigger Lambda function or webhook
3. Lambda clones repos, copies files, creates PRs
```

### Pros
- ✅ Fully automated
- ✅ No local dependencies
- ✅ Can trigger from EC2

### Cons
- ⚠️ Need AWS Lambda setup
- ⚠️ More complex infrastructure
- ⚠️ Requires AWS IAM permissions
- ⚠️ GitHub token management in AWS

### Implementation

**Step 1: Upload to S3**
```bash
# In run_extractor.sh after completion
aws s3 cp /tmp/extractor-results/*.dix s3://ido-epo-extractor-results/dictionaries/
```

**Step 2: Lambda Function**
```python
# lambda/deploy_dictionaries.py
import boto3
import subprocess
import tempfile
import os

def lambda_handler(event, context):
    # Get files from S3
    s3 = boto3.client('s3')
    s3.download_file('ido-epo-extractor-results', 'dictionaries/apertium-ido.ido.dix', '/tmp/apertium-ido.ido.dix')
    
    # Clone repos
    with tempfile.TemporaryDirectory() as tmpdir:
        os.chdir(tmpdir)
        subprocess.run(['git', 'clone', 'https://github.com/komapc/apertium-ido.git'])
        
        # Copy file
        subprocess.run(['cp', '/tmp/apertium-ido.ido.dix', 'apertium-ido/'])
        
        # Create PR
        os.chdir('apertium-ido')
        subprocess.run(['git', 'checkout', '-b', 'auto-update'])
        subprocess.run(['git', 'add', 'apertium-ido.ido.dix'])
        subprocess.run(['git', 'commit', '-m', 'Update dictionary'])
        subprocess.run(['git', 'push', 'origin', 'auto-update'])
        
        # Create PR via GitHub API
        # ...
```

**Trigger:** S3 upload event → Lambda

---

## Solution 3: GitHub Actions Workflow

### How It Works

```bash
# Triggered by extractor completion webhook
1. GitHub Actions runs
2. Downloads dictionaries from S3 or artifact
3. Creates PRs in target repos
```

### Pros
- ✅ Uses existing GitHub Actions
- ✅ No local setup needed
- ✅ Automatic authentication
- ✅ Can run on schedule or webhook

### Cons
- ⚠️ Need to set up workflow
- ⚠️ GitHub Actions minute limits
- ⚠️ Webhook setup required

### Implementation

```yaml
# .github/workflows/deploy-dictionaries.yml
name: Deploy Dictionaries

on:
  workflow_dispatch:
  repository_dispatch:
    types: [extractor-complete]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - name: Download dictionaries
        run: |
          aws s3 sync s3://ido-epo-extractor-results/dictionaries/ ./dictionaries/
      
      - name: Deploy to apertium-ido
        uses: peter-evans/create-pull-request@v5
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          repository: komapc/apertium-ido
          branch: dictionary-update
          commit-message: "feat: Update Ido dictionary"
          title: "Update Ido Dictionary"
          body: "Auto-generated from extractor"
          path: ./dictionaries/apertium-ido.ido.dix
      
      - name: Deploy to apertium-ido-epo
        uses: peter-evans/create-pull-request@v5
        with:
          token: ${{ secrets.GITHUB_TOKEN }}
          repository: komapc/apertium-ido-epo
          branch: dictionary-update
          commit-message: "feat: Update bilingual dictionary"
          title: "Update Bilingual Dictionary"
          body: "Auto-generated from extractor"
          path: ./dictionaries/apertium-ido-epo.ido-epo.dix
```

**Trigger:** Webhook from EC2 after extractor completes

---

## Comparison

| Feature | Solution 1: Local Script | Solution 2: Lambda | Solution 3: GitHub Actions |
|---------|---------------------------|---------------------|----------------------------|
| **Setup Complexity** | Low | High | Medium |
| **Automation Level** | Manual trigger | Fully automatic | Semi-automatic |
| **Requires** | GitHub CLI | AWS Lambda | GitHub Actions |
| **Cost** | Free | ~$0 | Free (public repos) |
| **Debugging** | Easy | Medium | Medium |
| **Control** | Full | Medium | Medium |
| **Best For** | Occasional runs | Frequent runs | CI/CD integration |

---

## Recommendation

**Start with Solution 1 (Local Script)**

**Why:**
- ✅ Simplest to implement
- ✅ Easy to test and debug
- ✅ Full control over what gets deployed
- ✅ Can review changes before PR
- ✅ No additional infrastructure needed

**When to Consider Others:**
- Need fully automated pipeline → Solution 2 or 3
- Frequent runs (>weekly) → Solution 2 or 3
- Team collaboration → Solution 3 (GitHub Actions)

---

## Implementation Priority

### Phase 1: Basic Deployment (Solution 1)
- Create `deploy_dictionaries.sh`
- Test with dry-run
- Create PRs manually to verify

### Phase 2: Automation (Optional)
- Add to EC2 post-completion hook
- Trigger automatically after extractor

### Phase 3: Full Automation (Future)
- Implement Lambda or GitHub Actions
- Set up webhooks
- Add notifications

---

## Next Steps

1. **Create deployment script** (`deploy_dictionaries.sh`)
2. **Test locally** with sample dictionaries
3. **Document workflow** in `USAGE_EXTRACTOR.md`
4. **Create PR** for review
5. **Deploy** when ready

