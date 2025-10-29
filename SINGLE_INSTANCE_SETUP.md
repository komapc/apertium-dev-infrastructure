# Single EC2 Instance Setup - Dual Purpose

## Overview

We use **ONE EC2 instance** for both:
1. **APy Translation Server** (always running)
2. **Dictionary Extractor** (on-demand)

## Instance Details

- **IP**: 52.211.137.158
- **Type**: t3.small (2 vCPU, 2GB RAM)
- **Disk**: 20GB (expandable)
- **Region**: eu-west-1 (Ireland)
- **Managed by**: Terraform (`terraform/main.tf`)

## Setup Steps

### 1. Expand Volume (One-Time)

```bash
cd terraform

# Apply volume expansion
terraform init
terraform apply -target=null_resource.expand_root_volume

# SSH to instance
ssh -i ~/.ssh/apertium.pem ubuntu@52.211.137.158

# Expand filesystem
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
df -h  # Should show ~20GB
```

### 2. Run Extractor (On-Demand)

```bash
cd terraform

# Run extractor on EC2
./run_extractor.sh

# This will:
# - Start instance if stopped
# - Clone/update extractor repo
# - Run regeneration (~1-2 hours)
# - Copy results back
# - Upload to S3
# - Stop instance
```

### 3. Deploy Dictionaries

```bash
cd terraform

# Deploy to GitHub repos
./deploy_dictionaries.sh

# This creates PRs in:
# - komapc/apertium-ido
# - komapc/apertium-ido-epo
# - komapc/vortaro
```

## Directory Structure on EC2

```
/home/ubuntu/
├── ido-esperanto-extractor/     # Extractor repo (persistent)
│   ├── data/raw/                # Wiktionary dumps
│   ├── work/                    # Intermediate files
│   ├── dist/                    # Generated dictionaries
│   ├── reports/                 # Statistics
│   └── logs/                    # Regeneration logs
│
└── apy-local/                   # APy server (if installed)
```

## Scripts Updated

All scripts now work with the single instance:

### `run_extractor.sh`
- Uses `~/ido-esperanto-extractor` (persistent)
- Clones from `fix/extractor-script-references` branch
- Runs `regenerate-on-ec2.sh`
- Copies from `~/ido-esperanto-extractor/dist/`
- Includes reports and logs

### `deploy_dictionaries.sh`
- Works with latest `extractor-results/*/`
- Creates PRs in all repos
- Shows comparison statistics

### `start_stop.sh`
- Start/stop instance manually
- Check instance status
- Get SSH command

### `expand-volume.tf`
- Expands volume without recreating instance
- Uses AWS CLI via null_resource
- Shows post-expansion commands

## Configuration

### Environment Variables

```bash
# Override defaults in run_extractor.sh
export GITHUB_REPO="https://github.com/komapc/ido-esperanto-extractor.git"
export EXTRACTOR_BRANCH="fix/extractor-script-references"
export ENTRY_POINT="regenerate-on-ec2.sh"
```

### Terraform Variables

```hcl
# terraform/terraform.tfvars
instance_type = "t3.small"
disk_size     = 20
aws_region    = "eu-west-1"
```

## Costs

### Running Costs
- **t3.small**: ~$0.02/hour (~$15/month if always on)
- **EBS 20GB**: ~$2/month
- **Data transfer**: Minimal (~$1/month)

### Optimization
- Stop instance when not translating: `./start_stop.sh stop`
- Run extractor on-demand: `./run_extractor.sh` (auto-stops)
- Total cost if stopped: ~$3/month (EBS only)

## Workflow

### Regular Translation Service
```bash
# Start instance
./start_stop.sh start

# APy server runs automatically
# Access at: http://52.211.137.158:2737
```

### Dictionary Regeneration
```bash
# Run extractor (auto-starts and stops)
./run_extractor.sh

# Deploy new dictionaries
./deploy_dictionaries.sh

# Merge PRs on GitHub
# Rebuild APy server with new dictionaries
```

## Troubleshooting

### Disk Full
```bash
ssh -i ~/.ssh/apertium.pem ubuntu@52.211.137.158

# Check space
df -h

# Clean up
cd ~/ido-esperanto-extractor
rm -rf work/*.json
rm -rf data/raw/*.xml.bz2
```

### Extractor Fails
```bash
# Check logs locally
cat terraform/extractor-run-*.log

# Or on EC2
ssh -i ~/.ssh/apertium.pem ubuntu@52.211.137.158
cd ~/ido-esperanto-extractor
tail -100 logs/regeneration_*.log
```

### Volume Expansion Needed
```bash
cd terraform
terraform apply -target=null_resource.expand_root_volume

# Then SSH and expand filesystem
ssh -i ~/.ssh/apertium.pem ubuntu@52.211.137.158
sudo growpart /dev/nvme0n1 1
sudo resize2fs /dev/nvme0n1p1
```

## SSH Access

```bash
# Direct SSH
ssh -i ~/.ssh/apertium.pem ubuntu@52.211.137.158

# Or from terraform
cd terraform
$(terraform output -raw ssh_command)
```

## Next Steps

1. ✅ Expand volume to 20GB
2. ✅ Run extractor with fixed cleaning
3. ✅ Verify entry counts (should be 6,000+)
4. ✅ Deploy to GitHub repos
5. ⏳ Merge PRs
6. ⏳ Update APy server with new dictionaries
