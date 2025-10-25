# Quick Start Guide

## 1. Get Your Public IP

```bash
curl -s https://api.ipify.org
```

Copy this IP address - you'll need it for SSH access.

## 2. Create Configuration File

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` and update:
- `ssh_ip`: Replace `YOUR_IP_HERE/32` with your IP from step 1

## 3. Initialize and Deploy

```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Create the infrastructure
terraform apply
```

Type `yes` when prompted.

## 4. Connect to Your Instance

After applying, Terraform will show outputs including the SSH command.

```bash
# Use the output from terraform apply
ssh -i ~/.ssh/id_rsa ubuntu@<PUBLIC_IP>
```

## 5. Deploy APy Server

```bash
# On the EC2 instance
cd /opt/ido-epo-translator

# Copy your setup script or download it
# Then run:
chmod +x setup-ec2.sh
./setup-ec2.sh
```

## 6. Configure Cloudflare Worker

Go to Cloudflare Dashboard → Workers → Your Worker → Settings → Variables

Add:
- `APY_SERVER_URL`: Use the public IP from terraform output
- `REBUILD_WEBHOOK_URL`: Use the public IP from terraform output + `/rebuild`

## What Was Created?

- **EC2 Instance**: Ubuntu 22.04 LTS
- **Instance Type**: t3.small (2GB RAM, 2 vCPU)
- **Disk**: 20GB encrypted SSD
- **Security**: SSH limited to your IP, HTTP open
- **Static IP**: Elastic IP for stable address
- **Cost**: ~$15-25/month

## Next Steps

See `README.md` for detailed documentation and troubleshooting.

