# Extractor - How To

## 1️⃣ Connect to EC2

```bash
ssh -i ~/.ssh/id_rsa ubuntu@54.220.110.151
```

## 2️⃣ Setup (Automatic)

No manual setup needed! Just run the extractor.

## 3️⃣ Run Extractor

```bash
cd ~/apertium-dev/terraform
./run_extractor.sh
```

**That's it!** Wait 1-2 hours for completion.

---

## Monitor Progress (Optional)

```bash
cd ~/apertium-dev/terraform
./monitor_extractor.sh
```

---

## Check Results

```bash
ls -lh terraform/extractor-results/*/
```

---

## Deploy to GitHub

```bash
cd ~/apertium-dev/terraform
./deploy_dictionaries.sh
```

---

## Instance Control

```bash
cd ~/apertium-dev/terraform

# Check status
./start_stop.sh status

# Start instance
./start_stop.sh start

# Stop instance (save costs)
./start_stop.sh stop
```

---

## Complete Example

```bash
# 1. Run extractor (auto-starts instance)
cd ~/apertium-dev/terraform
./run_extractor.sh

# 2. Wait for completion (~1-2 hours)
# Instance auto-stops when done

# 3. Check results
ls -lh extractor-results/*/

# 4. Deploy
./deploy_dictionaries.sh
```

---

## Paths to Remember

| Location | Path | Purpose |
|----------|------|---------|
| **EC2 Translator** | `/opt/ido-epo-translator/` | DO NOT TOUCH |
| **EC2 Extractor** | `~/ido-esperanto-extractor/` | Safe to delete |
| **Local Results** | `terraform/extractor-results/` | Generated files |
| **Local Logs** | `terraform/extractor-run-*.log` | Run logs |

---

## Troubleshooting

### Extractor fails?
```bash
# Check logs
cat terraform/extractor-run-*.log

# Or on EC2
ssh -i ~/.ssh/id_rsa ubuntu@54.220.110.151
tail -f ~/ido-esperanto-extractor/logs/*.log
```

### Disk full?
```bash
cd ~/apertium-dev/projects/dev-scripts
./cleanup_ec2_extractor.sh
```

### Instance stuck?
```bash
cd ~/apertium-dev/terraform
./start_stop.sh stop
./start_stop.sh start
```

---

## Quick Reference

```bash
# Connect
ssh -i ~/.ssh/id_rsa ubuntu@54.220.110.151

# Run
cd terraform && ./run_extractor.sh

# Monitor
cd terraform && ./monitor_extractor.sh

# Deploy
cd terraform && ./deploy_dictionaries.sh
```

**IP:** 54.220.110.151  
**SSH Key:** ~/.ssh/id_rsa  
**Runtime:** 1-2 hours  
**Cost:** ~$0.02-0.04 per run
