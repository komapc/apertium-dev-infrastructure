# Using the On-Demand Extractor

## Quick Start

### 1. Create Infrastructure

```bash
cd terraform

# Configure
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your settings

# Apply
terraform init
terraform apply
```

This creates:
- EC2 instance (t3.small)
- S3 bucket for results
- SSH key pair
- Security groups

### 2. Run Extractor

```bash
cd terraform
./run_extractor.sh
```

**What happens:**
1. ✅ Starts EC2 instance (~30 seconds)
2. ✅ Waits for SSH (~30 seconds)
3. ✅ Clones repository (2-5 minutes)
4. ✅ Installs dependencies (5-10 minutes)
5. ✅ Runs extractor (30-90 minutes)
6. ✅ Copies results locally
7. ✅ Uploads to S3
8. ✅ Stops instance automatically

**Total time:** ~40-130 minutes  
**Cost:** ~$0.02-0.04 per run

### 3. Check Results

```bash
# Local results
ls -lh extractor-results/

# S3 results
aws s3 ls s3://ido-epo-translator-extractor-results/

# Latest results
ls -lh extractor-results/$(ls -t extractor-results/ | head -1)
```

---

## Configuration

### Environment Variables

```bash
# Override GitHub repository
export GITHUB_REPO="https://github.com/your-org/your-repo.git"

# Run extractor
./run_extractor.sh
```

### Customize Output Directory

Edit the script to change:
```bash
RESULTS_DIR="extractor-results/$TIMESTAMP"  # Change this
```

---

## What Gets Created

### Local Files

```
extractor-results/
├── 20231025-143022/      # Timestamp-based directory
│   ├── dictionary.json
│   ├── logs/
│   └── ...
└── 20231025-160845/
    └── ...

extractor-run-20231025-143022.log  # Execution log
```

### S3 Bucket

```
s3://ido-epo-translator-extractor-results/
├── 20231025-143022/
│   ├── dictionary.json
│   └── ...
└── 20231025-160845/
    └── ...
```

### EC2 Instance

- **Status:** Running only during extractor execution
- **Auto-stops:** Yes, after completion
- **Cost:** ~$0.02/hour while running

---

## Troubleshooting

### SSH Connection Failed

```bash
# Check instance status
./start_stop.sh status

# Check SSH key permissions
chmod 600 ~/.ssh/id_rsa

# Retry with verbose output
ssh -v -i ~/.ssh/id_rsa ubuntu@<IP>
```

### Extractor Fails

```bash
# Check logs
cat extractor-run-*.log

# Check EC2 logs
aws ec2 get-console-output --instance-id <INSTANCE_ID>

# Manually SSH and debug
ssh -i ~/.ssh/id_rsa ubuntu@<IP>
cd /tmp/ido-esperanto-extractor
python3 main.py --help
```

### S3 Upload Fails

```bash
# Check AWS credentials
aws s3 ls

# Check bucket exists
terraform output s3_bucket_name

# Manual upload
aws s3 sync extractor-results/20231025-143022/ s3://<bucket>/20231025-143022/
```

### Instance Won't Start

```bash
# Check AWS console
aws ec2 describe-instances --instance-ids <INSTANCE_ID>

# Check security group
aws ec2 describe-security-groups --group-ids <SG_ID>

# Check if instance limit reached
aws service-quotas get-service-quota --service-code ec2 --quota-code L-0263D0A3
```

---

## Cost Tracking

### Estimate Costs

```bash
# Check AWS costs (requires AWS Cost Explorer)
aws ce get-cost-and-usage \
  --time-period Start=2023-10-01,End=2023-10-31 \
  --granularity MONTHLY \
  --metrics BlendedCost
```

### Cost Breakdown

| Component | Cost | When |
|-----------|------|------|
| EC2 compute | $0.02-0.04 | Per run (~2 hours) |
| EBS storage | $2/month | Always (minimal when stopped) |
| S3 storage | $0.023/GB | Per result set |
| Data transfer | Free | First 100GB |

**Example:** 10 runs/month = ~$0.20-0.40 compute + $2 storage = **~$2.20-2.40/month**

---

## Advanced Usage

### Run on Schedule

```bash
# Add to crontab
crontab -e

# Run every Monday at 2 AM
0 2 * * 1 cd /path/to/terraform && ./run_extractor.sh
```

### Parallel Runs

**Not recommended** - instances are shared. Run sequentially.

### Customize Extractor Parameters

Edit the SSH command in `run_extractor.sh`:

```bash
python3 main.py --output-dir /tmp/extractor-results --max-entries 10000
```

### Skip S3 Upload

```bash
# Set environment variable
export SKIP_S3=true
./run_extractor.sh
```

Or comment out S3 section in script.

---

## Maintenance

### Update Repository

No action needed - script clones fresh each time.

### Update Dependencies

Dependencies installed from `requirements.txt` each run.

### Update EC2 AMI

```bash
# Re-create instance with latest AMI
terraform taint aws_instance.apy_server
terraform apply
```

### Clean Up Old Results

```bash
# Local cleanup (after 30 days)
find extractor-results/ -mtime +30 -type d -exec rm -rf {} +

# S3 cleanup (automatic after 90 days via lifecycle policy)
```

---

## Security

### SSH Key Management

```bash
# Generate new key
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa-extractor

# Update Terraform
# Edit terraform.tfvars
ssh_public_key_path = "~/.ssh/id_rsa-extractor.pub"
terraform apply
```

### S3 Bucket Access

```bash
# Make bucket public (NOT recommended)
aws s3api put-bucket-policy --bucket <bucket> --policy file://public-policy.json

# Use IAM roles instead
```

### Instance Security

- Security group restricts SSH to your IP
- Instance has no public web access
- Results stored encrypted in S3

---

## Monitoring

### CloudWatch Metrics

```bash
# View instance metrics
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=<INSTANCE_ID> \
  --start-time 2023-10-25T00:00:00Z \
  --end-time 2023-10-25T23:59:59Z \
  --period 3600 \
  --statistics Average
```

### Log Analysis

```bash
# Search logs
grep "ERROR" extractor-run-*.log

# Count successful runs
ls -1 extractor-results/ | wc -l

# Check latest results
ls -lh extractor-results/$(ls -t extractor-results/ | head -1)
```

---

## Next Steps

1. ✅ Test run: `./run_extractor.sh`
2. ✅ Verify results: Check `extractor-results/`
3. ✅ Review S3: `aws s3 ls s3://<bucket>/`
4. ✅ Integrate results: Use generated dictionaries

---

## Need Help?

- Check logs: `cat extractor-run-*.log`
- AWS Console: EC2 Dashboard
- Terraform docs: `terraform/README.md`
- Cost guide: `terraform/COST_OPTIMIZATION.md`

