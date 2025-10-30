# Terraform Configuration for Ido-Esperanto APy Server

This Terraform configuration provisions an AWS EC2 instance for hosting the Apertium APy translation server.

## Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** installed (>= 1.0)
3. **AWS CLI** configured with credentials
4. **SSH Key Pair** for accessing the instance

## Quick Start

### 1. Configure Variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars`:
- Set `ssh_ip` to your public IP (use `curl -4 -s ifconfig.me`)
- Adjust other variables as needed

### 2. Get Your SSH Public Key

```bash
# If you don't have an SSH key yet
ssh-keygen -t rsa -b 4096 -C "your_email@example.com"

# Note the path to your public key
cat ~/.ssh/id_rsa.pub
```

### 3. Initialize Terraform

```bash
terraform init
```

### 4. Review Plan

```bash
terraform plan
```

### 5. Apply Configuration

```bash
terraform apply
```

Type `yes` when prompted.

### 6. Setup SSH Config (Optional but Recommended)

Add to `~/.ssh/config` for easy connection:

```ssh-config
Host ido-extractor
    HostName <PUBLIC_IP>
    User ubuntu
    IdentityFile ~/.ssh/id_rsa
    ServerAliveInterval 60
```

Then connect with: `ssh ido-extractor`

### 7. Connect to Instance

After applying, Terraform will output the SSH command:

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<PUBLIC_IP>
# Or if you set up SSH config:
ssh ido-extractor
```

## Architecture

### Single Instance - Dual Purpose

This EC2 instance serves **two purposes**:

1. **APy Translation Server** (always running) - Port 2737
2. **Dictionary Extractor** (on-demand) - Batch process

**Path Separation:**
- Translator: `/opt/ido-epo-translator/` (Docker)
- Extractor: `~/ido-esperanto-extractor/` (Python)

No conflicts - completely isolated.

### Resources Created

- **EC2 Instance**: t3.small Ubuntu 22.04 LTS
- **Security Group**: Ports 22 (SSH), 80 (HTTP), 2737 (APy), 8081 (Webhook)
- **Elastic IP**: Stable public IP address
- **Key Pair**: SSH access
- **S3 Bucket**: Extractor results backup (optional)

### Instance Configuration

- **Type**: t3.small (2 vCPU, 2GB RAM)
- **OS**: Ubuntu 22.04 LTS
- **Disk**: 20GB gp3 SSD (encrypted, expandable)
- **Docker**: Pre-installed
- **User**: ubuntu (sudo access)

## Post-Deployment Setup

### 1. Deploy APy Server

```bash
# SSH to instance
ssh -i ~/.ssh/id_rsa ubuntu@<PUBLIC_IP>

# Download setup script
cd /opt/ido-epo-translator
# Copy your setup-ec2.sh script here or download from repo

# Run setup
chmod +x setup-ec2.sh
./setup-ec2.sh
```

### 2. Configure Cloudflare Worker

Set these environment variables in Cloudflare Worker dashboard:

- `APY_SERVER_URL`: `http://<PUBLIC_IP>`
- `REBUILD_WEBHOOK_URL`: `http://<PUBLIC_IP>/rebuild`
- `REBUILD_SHARED_SECRET`: Generate with `openssl rand -hex 32`

### 3. Test APy Server

```bash
# Test locally on instance
curl http://localhost:2737/listPairs

# Test from your machine
curl http://<PUBLIC_IP>:2737/listPairs
```

## Cost Estimation

### ⚠️ Important: Pay Only for Hours Running!

**AWS EC2 bills PER HOUR that the instance is RUNNING:**
- ✅ Instance running: Pay compute costs (~$0.0208/hour for t3.small)
- ✅ Instance stopped: DON'T pay compute costs
- ⚠️ Storage: Always charged (~$2/month) even when stopped

### Monthly Cost Scenarios

| Usage | Hours/Month | Cost |
|-------|-------------|------|
| Always on | ❌ Always running | ~$17/month |
| 10 hours/month | ✅ Start when needed | ~$2.21/month |
| Weekdays only | ✅ Business hours | ~$5.33/month |

**Stop the instance when not in use:**

```bash
cd terraform
./start_stop.sh stop   # Stops compute billing
./start_stop.sh start  # Starts when needed
```

### Enable Automated Scheduling

**Automatically start/stop instance on schedule** (costs $0 extra):

```hcl
# In terraform.tfvars
enable_automation = true
stop_schedule    = "cron(0 2 * * ? *)"  # Stop at 2 AM
start_schedule   = "cron(0 8 * * ? *)"  # Start at 8 AM
```

See `AUTOMATION_GUIDE.md` for EventBridge automation setup and `COST_OPTIMIZATION.md` for detailed cost breakdown.

## Security Considerations

### Permission Model

- SSH access limited to your IP address
- HTTP (port 80) open to all (Cloudflare Worker)
- Direct APy access (port 2737) open but can be restricted

### Hardening Recommendations

1. **Restrict Port 2737**:
   ```hcl
   # In security group, change CIDR to Cloudflare IPs only
   cidr_blocks = ["173.245.48.0/20", "103.21.244.0/22"]
   ```

2. **Enable AWS WAF** for DDoS protection

3. **Set up CloudWatch** monitoring and alerts

4. **Use AWS Systems Manager** for SSH-free access

5. **Enable VPC Flow Logs** for network monitoring

## Managing the Infrastructure

### View Resources

```bash
terraform show
```

### Update Instance Type

Edit `terraform.tfvars`:
```hcl
instance_type = "t3.medium"
```

Then apply:
```bash
terraform apply
```

### Add More Disk Space

Edit `terraform.tfvars`:
```hcl
disk_size = 50
```

Then apply:
```bash
terraform apply
```

### Destroy Resources

```bash
terraform destroy
```

**Warning**: This will delete all resources. Make sure you have backups!

## Dictionary Extractor

The same instance can run the dictionary extractor on-demand:

```bash
# Run extractor (auto-starts instance, runs extraction, copies results, stops instance)
./run_extractor.sh

# Monitor progress
./monitor_extractor.sh

# Deploy results to GitHub
./deploy_dictionaries.sh
```

**Working Directory:** `~/ido-esperanto-extractor/`  
**Results:** Copied to `extractor-results/TIMESTAMP/`  
**Runtime:** ~1-2 hours  
**Cost:** ~$0.02-0.04 per run

See `SINGLE_INSTANCE_SETUP.md` for detailed extractor documentation.

## Troubleshooting

### Instance Won't Start

```bash
# Check instance status
aws ec2 describe-instance-status --instance-ids <INSTANCE_ID>

# View console output
aws ec2 get-console-output --instance-id <INSTANCE_ID>
```

### Can't SSH

1. **Check your IP changed:**
   ```bash
   MY_IP=$(curl -4 -s ifconfig.me)
   aws ec2 authorize-security-group-ingress \
     --group-id <SECURITY_GROUP_ID> \
     --protocol tcp --port 22 --cidr $MY_IP/32
   ```

2. Verify key pair is correct
3. Check instance is running
4. Try: `ssh -v -i <key> ubuntu@<IP>`

### APy Not Responding

1. SSH to instance
2. Check Docker: `docker ps`
3. Check logs: `docker logs apy-server`
4. Check port: `netstat -tlnp | grep 2737`

### Extractor Fails

1. Check logs: `cat extractor-run-*.log`
2. Or on EC2: `ssh ido-extractor 'tail -50 ~/ido-esperanto-extractor/logs/*.log'`
3. Resume from failed stage: `python3 scripts/pipeline_manager.py --stage <stage-name>`

## Outputs

After applying, Terraform provides:

- `instance_id`: EC2 instance ID
- `public_ip`: Public IP address
- `public_dns`: Public DNS name
- `ssh_command`: Ready-to-use SSH command
- `apy_url`: APy server URL
- `cloudflare_worker_config`: Environment variables for Cloudflare

## Files

- `main.tf`: Main infrastructure configuration
- `variables.tf`: Variable definitions
- `outputs.tf`: Output definitions
- `terraform.tfvars.example`: Example variable values
- `README.md`: This file

## References

- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Docker Installation](https://docs.docker.com/engine/install/ubuntu/)

