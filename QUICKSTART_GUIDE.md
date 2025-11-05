# Quick Start Guide - EC2 Extractor

## 1. How to Connect

### SSH to EC2 Instance
```bash
ssh -i ~/.ssh/id_rsa ubuntu@54.220.110.151
```

### Check Instance Status
```bash
cd terraform
./start_stop.sh status
```

### Start Instance (if stopped)
```bash
cd terraform
./start_stop.sh start
```

### Stop Instance (to save costs)
```bash
cd terraform
./start_stop.sh stop
```

---

## 2. How to Setup Extractor

**Good news: Setup is automatic!** The `run_extractor.sh` script handles everything.

### What Happens Automatically:
1. ✅ Starts EC2 instance
2. ✅ Installs dependencies (Python, git, etc.)
3. ✅ Clones extractor repository
4. ✅ Downloads Wiktionary dumps
5. ✅ Creates all necessary directories
6. ✅ Runs extraction
7. ✅ Copies results back to your machine
8. ✅ Stops instance

### Manual Setup (Only if needed)

If you want to set up manually:

```bash
# 1. SSH to instance
ssh -i ~/.ssh/id_rsa ubuntu@54.220.110.151

# 2. Clone repository
cd ~
git clone https://github.com/komapc/ido-esperanto-extractor.git
cd ido-esperanto-extractor

# 3. Install dependencies
pip3 install --user -r requirements.txt

# 4. Download dumps
bash scripts/download_dumps.sh

# 5. You're ready to run!
```

---

## 3. How to Run Extractor

### Simple Method (Recommended)

```bash
# From your local machine
cd ~/apertium-dev/terraform
./run_extractor.sh
```

That's it! The script will:
- Start the instance
- Run the extraction (~1-2 hours)
- Copy results to `extractor-results/TIMESTAMP/`
- Stop the instance

### Monitor Progress

While extraction is running:

```bash
# In another terminal
cd ~/apertium-dev/terraform
./monitor_extractor.sh
```

### Check Results

```bash
# View local results
ls -lh terraform/extractor-results/*/

# View latest results
ls -lh terraform/extractor-results/$(ls -t terraform/extractor-results/ | head -1)/
```

---

## Complete Workflow Example

```bash
# 1. Navigate to terraform directory
cd ~/apertium-dev/terraform

# 2. Run extractor (this takes 1-2 hours)
./run_extractor.sh

# 3. Wait for completion (or monitor in another terminal)
./monitor_extractor.sh

# 4. Check results
ls -lh extractor-results/*/

# 5. Deploy to GitHub (creates PRs)
./deploy_dictionaries.sh

# Done! Instance auto-stops after extraction
```

---

## Troubleshooting

### Check if extractor is running
```bash
ssh -i ~/.ssh/id_rsa ubuntu@54.220.110.151
ps aux | grep python
```

### View logs on EC2
```bash
ssh -i ~/.ssh/id_rsa ubuntu@54.220.110.151
cd ~/ido-esperanto-extractor
tail -f logs/*.log
```

### Check disk space
```bash
ssh -i ~/.ssh/id_rsa ubuntu@54.220.110.151
df -h
```

### Clean up old files
```bash
cd ~/apertium-dev/projects/dev-scripts
./cleanup_ec2_extractor.sh
```

---

## Important Paths

### On EC2 Instance
```
Translator:  /opt/ido-epo-translator/     (DO NOT TOUCH)
Extractor:   ~/ido-esperanto-extractor/   (Safe to delete)
```

### On Local Machine
```
Scripts:     ~/apertium-dev/terraform/
Results:     ~/apertium-dev/terraform/extractor-results/
Logs:        ~/apertium-dev/terraform/extractor-run-*.log
```

---

## Quick Commands Cheat Sheet

```bash
# Connect to EC2
ssh -i ~/.ssh/id_rsa ubuntu@54.220.110.151

# Run extractor
cd terraform && ./run_extractor.sh

# Monitor progress
cd terraform && ./monitor_extractor.sh

# Deploy results
cd terraform && ./deploy_dictionaries.sh

# Start/stop instance
cd terraform && ./start_stop.sh [start|stop|status]

# Clean up EC2
cd projects/dev-scripts && ./cleanup_ec2_extractor.sh
```

---

## Expected Output

### Successful Run
```
✓ Instance started
✓ SSH is ready
✓ Extractor completed
✓ Results copied to extractor-results/20251030-123456/
✓ Results uploaded to S3
✓ Instance stopped

Results location:
  Local:  extractor-results/20251030-123456/
  S3:     s3://ido-epo-translator-extractor-results/20251030-123456/
  Log:    extractor-run-20251030-123456.log
```

### Generated Files
```
extractor-results/20251030-123456/
├── apertium-ido.ido.dix              # Monolingual dictionary
├── apertium-ido-epo.ido-epo.dix      # Bilingual dictionary
├── vortaro_dictionary.json           # Vortaro format
├── ido_dictionary.json               # Source JSON
├── bidix_big.json                    # Source bilingual
└── reports/
    └── stats_summary.md              # Statistics
```

---

## Cost Estimate

- **Per run:** ~$0.02-0.04 (1-2 hours on t3.small)
- **Storage:** ~$2/month (20GB EBS)
- **Total if stopped:** ~$2/month (only EBS charges)

**Tip:** Instance auto-stops after extraction to minimize costs!

---

## Next Steps After Extraction

1. **Review results:**
   ```bash
   cat extractor-results/*/reports/stats_summary.md
   ```

2. **Deploy to GitHub:**
   ```bash
   ./deploy_dictionaries.sh
   ```

3. **Review PRs on GitHub**

4. **Merge when ready**

5. **Update translator with new dictionaries**

---

## Need Help?

- **Full documentation:** `terraform/SINGLE_INSTANCE_SETUP.md`
- **Path reference:** `terraform/PATH_REFERENCE.md`
- **Troubleshooting:** `terraform/TROUBLESHOOTING.md`
- **EC2 guide:** `projects/docs/archive/EC2_EXTRACTOR_UPDATE_GUIDE.md`
