# Running Extractor on On-Demand EC2 Instance

## Overview

This guide covers running the extractor on a temporary EC2 instance that:
1. Starts automatically
2. Runs the extractor
3. Copies results back
4. Shuts down automatically

**Cost:** Only pay for the ~30-90 minutes the instance runs!

---

## Approaches Comparison

### Option 1: Docker Image (Recommended)

**How it works:**
- Pre-build Docker image with extractor + dependencies
- Push to Docker Hub or AWS ECR
- EC2 pulls image and runs
- No git clone needed

**Pros:**
- ✅ Fastest startup (no git clone)
- ✅ Isolated environment
- ✅ Reproducible builds
- ✅ Can cache dependencies
- ✅ Easy to version

**Cons:**
- ⚠️ Requires Docker image setup
- ⚠️ Need Docker Hub account or ECR setup

**Best for:** Production, repeat runs

---

### Option 2: Git Clone on Server

**How it works:**
- EC2 instance clones repo fresh each time
- Installs dependencies
- Runs extractor
- Copies results back

**Pros:**
- ✅ Always latest code
- ✅ No Docker setup needed
- ✅ Simple to implement

**Cons:**
- ⚠️ Slower startup (git clone + install)
- ⚠️ Install dependencies each time
- ⚠️ More network usage

**Best for:** Development, testing

---

### Option 3: Copy Scripts Only

**How it works:**
- SCP extractor scripts to EC2
- Run directly (assumes dependencies pre-installed)

**Pros:**
- ✅ Minimal setup
- ✅ Fast execution

**Cons:**
- ⚠️ Requires persistent EC2 or snapshot
- ⚠️ Hard to maintain
- ⚠️ Less flexible

**Best for:** Quick tests, not recommended

---

## Where Artifacts Get Copied

### Option A: SCP to Local Machine

```bash
# Results copied to:
~/apertium-dev/extractor-results/YYYY-MM-DD-HHMMSS/
```

**Pros:**
- ✅ Local access
- ✅ Easy to inspect
- ✅ Version controlled locally

**Cons:**
- ⚠️ Requires local disk space
- ⚠️ Need to manage locally

---

### Option B: S3 Bucket

```bash
# Results uploaded to:
s3://your-bucket/extractor-results/YYYY-MM-DD-HHMMSS/
```

**Pros:**
- ✅ Scalable storage
- ✅ Accessible from anywhere
- ✅ Can set up versioning
- ✅ Can share with team

**Cons:**
- ⚠️ S3 storage costs (minimal)
- ⚠️ Requires S3 setup

---

### Option C: Both Local + S3

**Best of both worlds:**
- Upload to S3 for archive
- Download to local for immediate use

---

## Implementation Approaches

### Approach 1: Docker Image (Full Script)

```bash
#!/bin/bash
# run_extractor_docker.sh

set -e

INSTANCE_ID=$(terraform output -raw instance_id)
AWS_REGION=$(terraform output -raw aws_region)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="extractor-results/$TIMESTAMP"

# Start instance
echo "Starting EC2 instance..."
aws ec2 start-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

# Get IP
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Instance IP: $PUBLIC_IP"
echo "Waiting for SSH to be ready..."
sleep 30

# Run extractor via Docker
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP << 'ENDSSH'
  set -e
  
  # Pull latest extractor image
  docker pull your-dockerhub/extractor:latest
  
  # Run extractor
  docker run --rm \
    -v /tmp/extractor-results:/results \
    your-dockerhub/extractor:latest \
    python3 main.py
  
  # Results now in /tmp/extractor-results
ENDSSH

# Copy results back
mkdir -p "$RESULTS_DIR"
scp -i ~/.ssh/id_rsa -r ubuntu@$PUBLIC_IP:/tmp/extractor-results/* "$RESULTS_DIR/"

# Optionally upload to S3
aws s3 sync "$RESULTS_DIR/" "s3://your-bucket/extractor-results/$TIMESTAMP/"

# Stop instance
echo "Stopping instance..."
aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"

echo "Done! Results in: $RESULTS_DIR"
```

---

### Approach 2: Git Clone (Full Script)

```bash
#!/bin/bash
# run_extractor_gitclone.sh

set -e

INSTANCE_ID=$(terraform output -raw instance_id)
AWS_REGION=$(terraform output -raw aws_region)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="extractor-results/$TIMESTAMP"
GITHUB_REPO="https://github.com/komapc/ido-esperanto-extractor.git"

# Start instance
echo "Starting EC2 instance..."
aws ec2 start-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

# Get IP
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo "Instance IP: $PUBLIC_IP"
echo "Waiting for SSH to be ready..."
sleep 30

# Run extractor
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP << ENDSSH
  set -e
  
  # Clone repository
  cd /tmp
  git clone $GITHUB_REPO
  cd ido-esperanto-extractor
  
  # Install dependencies
  pip3 install -r requirements.txt
  
  # Run extractor
  python3 main.py --output-dir /tmp/results
  
  # Results now in /tmp/results
ENDSSH

# Copy results back
mkdir -p "$RESULTS_DIR"
scp -i ~/.ssh/id_rsa -r ubuntu@$PUBLIC_IP:/tmp/results/* "$RESULTS_DIR/"

# Optionally upload to S3
aws s3 sync "$RESULTS_DIR/" "s3://your-bucket/extractor-results/$TIMESTAMP/"

# Stop instance
echo "Stopping instance..."
aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"

echo "Done! Results in: $RESULTS_DIR"
```

---

### Approach 3: Copy Scripts Only (Quick Test)

```bash
#!/bin/bash
# run_extractor_copy.sh

set -e

INSTANCE_ID=$(terraform output -raw instance_id)
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="extractor-results/$TIMESTAMP"

# Start instance
aws ec2 start-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"

PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

sleep 30

# Copy scripts
scp -i ~/.ssh/id_rsa -r projects/extractor ubuntu@$PUBLIC_IP:/tmp/

# Run extractor
ssh -i ~/.ssh/id_rsa ubuntu@$PUBLIC_IP << 'ENDSSH'
  cd /tmp/extractor
  pip3 install -r requirements.txt
  python3 main.py --output-dir /tmp/results
ENDSSH

# Copy results back
mkdir -p "$RESULTS_DIR"
scp -i ~/.ssh/id_rsa -r ubuntu@$PUBLIC_IP:/tmp/results/* "$RESULTS_DIR/"

# Stop instance
aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"

echo "Done! Results in: $RESULTS_DIR"
```

---

## What Else You Need to Know

### 1. Pre-requisites

**Required:**
- ✅ AWS CLI configured (`aws configure`)
- ✅ Terraform outputs available
- ✅ SSH key pair set up
- ✅ EC2 instance already created via Terraform

**Optional but Recommended:**
- Docker Hub account (for Docker approach)
- S3 bucket (for artifact storage)
- EC2 instance with Docker pre-installed

---

### 2. Security Considerations

**Security Group Rules:**
- Port 22 (SSH) must be open from your IP
- No need for HTTP/HTTPS ports
- Consider using AWS Systems Manager instead of SSH (more secure)

**SSH Key Management:**
- Private key should have correct permissions: `chmod 600 ~/.ssh/id_rsa`
- Consider using AWS Secrets Manager for key storage

**Network:**
- Instance should have internet access to pull Docker images / git repos
- Outbound HTTPS (443) must be allowed

---

### 3. Cost Optimization

**Instance Type:**
```bash
# In terraform/variables.tf
instance_type = "t3.micro"  # Cheaper for short runs
```

**Estimated Costs:**
- t3.micro: ~$0.01/hour × 2 hours = $0.02
- t3.small: ~$0.02/hour × 2 hours = $0.04

**Storage Costs:**
- EBS: $0.10/GB/month × 20GB = $2/month (only when stopped, minimal when running)

---

### 4. IAM Permissions Needed

Your AWS credentials need:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:StartInstances",
        "ec2:StopInstances",
        "ec2:DescribeInstances",
        "ec2:DescribeInstanceStatus"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject"
      ],
      "Resource": "arn:aws:s3:::your-bucket/*"
    }
  ]
}
```

---

### 5. Error Handling

**What if extractor fails?**

- Script should still shut down instance
- Logs should be copied back
- Exit code should indicate success/failure

**What if SSH fails?**

- Script should retry SSH connection
- Wait longer for instance boot (up to 5 minutes)
- Send notification on failure

**What if instance won't start?**

- Check AWS console for errors
- Verify security group
- Check instance status

---

### 6. Monitoring & Logging

**CloudWatch Logs:**
```bash
# View instance logs
aws ec2 get-console-output --instance-id $INSTANCE_ID
```

**Local Logging:**
```bash
# Log everything
./run_extractor.sh 2>&1 | tee extractor-run-$(date +%Y%m%d).log
```

---

### 7. S3 Setup (Optional)

**Create bucket:**
```bash
aws s3 mb s3://ido-epo-extractor-results --region eu-west-1
```

**Set up versioning:**
```bash
aws s3api put-bucket-versioning \
  --bucket ido-epo-extractor-results \
  --versioning-configuration Status=Enabled
```

**Set up lifecycle:**
```bash
# Auto-delete after 90 days
aws s3api put-bucket-lifecycle-configuration \
  --bucket ido-epo-extractor-results \
  --lifecycle-configuration file://lifecycle.json
```

---

### 8. Docker Image Preparation

**Create Dockerfile:**
```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    && rm -rf /var/lib/apt/lists/*

# Copy extractor code
COPY . .

# Install Python dependencies
RUN pip3 install --no-cache-dir -r requirements.txt

# Run extractor
CMD ["python3", "main.py"]
```

**Build and push:**
```bash
docker build -t your-dockerhub/extractor:latest .
docker push your-dockerhub/extractor:latest
```

---

### 9. Time Estimates

| Step | Git Clone Approach | Docker Approach |
|------|-------------------|-----------------|
| Start instance | 30 seconds | 30 seconds |
| SSH ready | 30 seconds | 30 seconds |
| Clone/Pull | 2-5 minutes | 1-2 minutes |
| Install deps | 5-10 minutes | 0 (pre-installed) |
| Run extractor | 30-90 minutes | 30-90 minutes |
| Copy results | 1-5 minutes | 1-5 minutes |
| Stop instance | 30 seconds | 30 seconds |
| **Total** | **40-130 minutes** | **33-118 minutes** |

---

### 10. Alternatives to Consider

**AWS Lambda:**
- ⚠️ 15-minute timeout limit
- ⚠️ Limited disk space
- ❌ Not suitable for 30-90 minute runs

**AWS Batch:**
- ✅ Better for long-running jobs
- ✅ Can use Spot instances
- ⚠️ More complex setup

**Docker on Local Machine:**
- ✅ No EC2 costs
- ⚠️ Uses your local resources
- ✅ Simple setup

---

## Recommendation

**For Your Use Case:**

1. **Start with Git Clone approach** (simplest)
2. **Move to Docker approach** when you have multiple runs
3. **Use S3 for artifact storage** for better organization
4. **Use t3.micro** to save costs

**Suggested Workflow:**
```bash
# 1. Create EC2 instance
cd terraform
terraform apply

# 2. Run extractor when needed
./run_extractor.sh

# 3. Check results
ls -lh extractor-results/

# 4. Destroy when done (optional)
terraform destroy
```

Would you like me to create the actual script files based on your preferred approach?

