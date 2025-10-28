# Deployment Options for Terraform Infrastructure

## Current State

- ✅ Terraform infrastructure configured and tested
- ✅ Git repository initialized locally
- ✅ Extractor is currently running on EC2
- ❌ Not yet pushed to GitHub

## Option 1: New Dedicated Repository (RECOMMENDED)

**Repository Name:** `apertium-terraform` or `ido-epo-infrastructure`

**Pros:**
- ✅ Clean separation of concerns
- ✅ Infrastructure code separate from application code
- ✅ Can be reused for other projects
- ✅ Easy to manage permissions (who can deploy?)
- ✅ Can have its own CI/CD

**Cons:**
- ⚠️ One more repository to manage

**Setup:**
```bash
cd terraform
git remote add origin https://github.com/komapc/apertium-terraform.git
git push -u origin master
```

**Use Case:** If you plan to use this infrastructure for multiple projects or want clean separation.

---

## Option 2: Add to Extractor Repository

**Repository:** `ido-esperanto-extractor`

**Pros:**
- ✅ Related code stays together
- ✅ One less repository
- ✅ Easy to find infrastructure for extractor

**Cons:**
- ⚠️ Infrastructure mixed with application code
- ⚠️ Less reusable for other projects

**Setup:**
```bash
cd projects/extractor
mkdir -p infra
cp -r /home/mark/apertium-dev/terraform/* infra/
cd infra
git init
git add -A
git commit -m "feat: Add AWS EC2 on-demand infrastructure"
```

**Use Case:** If this infrastructure is ONLY for the extractor project.

---

## Option 3: Keep Local Only

**Pros:**
- ✅ No GitHub management
- ✅ Fully under your control
- ✅ No public visibility

**Cons:**
- ❌ No backup in case of local failure
- ❌ Harder to share with team
- ❌ No version control on GitHub

**Setup:** Nothing needed - already local

**Use Case:** Personal use only, no collaboration needed.

---

## Recommendation

**Create a new repository:** `apertium-terraform`

**Reasoning:**
1. Infrastructure code is different from application code
2. Can be reused for translator/other projects
3. Clean separation of concerns
4. Better security (can restrict who has access)
5. Follows common DevOps practices

---

## Step-by-Step: Create New Repo

### 1. Create Repository on GitHub

```bash
# Using GitHub CLI
gh repo create apertium-terraform --public --description "Infrastructure as Code for Ido-Esperanto projects"

# Or manually:
# Go to https://github.com/new
# Name: apertium-terraform
# Description: AWS EC2 infrastructure for on-demand extractor runs
# Public
# Click "Create repository"
```

### 2. Push Code

```bash
cd /home/mark/apertium-dev/terraform

# Add remote
git remote add origin https://github.com/komapc/apertium-terraform.git

# Push
git push -u origin master
```

### 3. Create `.gitignore` (already exists)

Make sure sensitive files are ignored:
- `terraform.tfvars` (contains your IP)
- `*.tfstate*` (contains secrets)
- `.terraform/` (cache)

### 4. Add README

The existing `README.md` is good, but update it with:
- Link to parent project
- How to use
- Cost information

---

## After Push: What to Document

Update the main project README:

```markdown
## Infrastructure

AWS EC2 infrastructure for on-demand extractor runs:

- Repository: [apertium-terraform](https://github.com/komapc/apertium-terraform)
- Usage: See terraform/USAGE_EXTRACTOR.md
- Cost: ~$0.02-0.04 per run, ~$2/month storage
```

---

## Security Considerations

### Before Pushing:

1. **Check `.gitignore`** - Make sure sensitive files aren't committed
2. **Review `terraform.tfvars`** - Contains your public IP (OK to share)
3. **Check for secrets** - No AWS keys, passwords, etc.

### Files That Should NOT Be Pushed:

- `terraform.tfvars` - Your specific config
- `*.tfstate` - Contains state
- `.terraform/` - Cache directory
- `*.log` - May contain sensitive info

### Files Safe to Push:

- `*.tf` - Infrastructure code
- `*.sh` - Scripts
- `*.md` - Documentation
- `terraform.tfvars.example` - Template
- `.gitignore` - Ignore rules

---

## Decision Time

**Choose based on your needs:**

1. **Planning multiple projects?** → Option 1 (New Repo)
2. **Only for extractor?** → Option 2 (Add to Extractor)
3. **Personal use only?** → Option 3 (Keep Local)

---

## Next Steps

Once you decide:

1. **If Option 1:** Create GitHub repo and push
2. **If Option 2:** Copy files to extractor repo
3. **If Option 3:** Nothing needed

Then update documentation to reference the infrastructure.

