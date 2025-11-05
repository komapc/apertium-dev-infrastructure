#!/bin/bash
# Cleanup EC2 Extractor - Remove old directories except /tmp/extractor
# Safe cleanup that preserves only the essential directory

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== EC2 Extractor Cleanup ===${NC}"
echo ""

# Get instance details
cd terraform
INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || {
    echo -e "${RED}Error: Could not get instance ID${NC}"
    exit 1
})

# Check if instance is running
INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "unknown")

if [ "$INSTANCE_STATE" != "running" ]; then
    echo -e "${YELLOW}Instance is not running. Starting...${NC}"
    aws ec2 start-instances --instance-ids "$INSTANCE_ID" >/dev/null
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
    echo -e "${GREEN}✓ Instance started${NC}"
    sleep 10  # Wait for SSH to be ready
fi

# Get IP
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

echo -e "${BLUE}Instance IP: $PUBLIC_IP${NC}"
echo ""

# Wait for SSH
echo -e "${BLUE}Waiting for SSH...${NC}"
for i in {1..30}; do
    if ssh -i ~/.ssh/id_rsa -o ConnectTimeout=2 -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "echo 'ready'" >/dev/null 2>&1; then
        echo -e "${GREEN}✓ SSH ready${NC}"
        break
    fi
    if [ $i -eq 30 ]; then
        echo -e "${RED}✗ SSH timeout${NC}"
        exit 1
    fi
    sleep 2
done

echo ""
echo -e "${BLUE}=== Current Disk Usage ===${NC}"
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "df -h /"

echo ""
echo -e "${BLUE}=== Directories in /home/ubuntu ===${NC}"
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "ls -lah /home/ubuntu/ | grep '^d'"

echo ""
echo -e "${BLUE}=== Directories in /tmp ===${NC}"
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "ls -lah /tmp/ | grep '^d' | grep -v 'systemd\|snap'"

echo ""
echo -e "${YELLOW}=== What will be cleaned ===${NC}"
echo "The following will be REMOVED:"
echo "  - /home/ubuntu/ido-esperanto-extractor/* (extractor working directory)"
echo "  - Old work files (*.json older than 7 days)"
echo "  - Old log files (*.log older than 7 days)"
echo "  - Docker cache"
echo ""
echo "The following will be KEPT:"
echo "  - /opt/ido-epo-translator/ (translator server - DO NOT TOUCH)"
echo "  - Recent logs (last 7 days)"
echo ""
echo -e "${RED}WARNING: This will delete all extractor data!${NC}"
echo "The extractor will re-download dumps on next run."
echo ""

read -p "Continue with cleanup? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Cleanup cancelled${NC}"
    exit 0
fi

echo ""
echo -e "${BLUE}=== Cleaning up ===${NC}"

# Run cleanup on EC2
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP << 'ENDSSH'
set -e

echo "Cleaning extractor directory..."
rm -rf /home/ubuntu/ido-esperanto-extractor 2>/dev/null || true

echo "Cleaning old work files (>7 days)..."
find /home/ubuntu -name "*.json" -type f -mtime +7 -delete 2>/dev/null || true

echo "Cleaning old logs (>7 days)..."
find /home/ubuntu -name "*.log" -type f -mtime +7 -delete 2>/dev/null || true

echo "Cleaning Docker cache..."
docker system prune -af 2>/dev/null || echo "Docker not installed or not running"

echo "Cleaning apt cache..."
sudo apt-get clean 2>/dev/null || true

echo "Cleaning pip cache..."
pip3 cache purge 2>/dev/null || true

echo ""
echo "=== Cleanup Complete ==="
echo ""
echo "Remaining directories:"
ls -lah /home/ubuntu/ | grep '^d' || echo "No directories in /home/ubuntu"
echo ""
ls -lah /tmp/ | grep '^d' | grep -v 'systemd\|snap' || echo "No relevant directories in /tmp"
ENDSSH

echo ""
echo -e "${BLUE}=== Disk Usage After Cleanup ===${NC}"
ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "df -h /"

echo ""
echo -e "${GREEN}✓ Cleanup complete!${NC}"
echo ""
echo -e "${YELLOW}Note: /tmp/ido-esperanto-extractor will be recreated automatically on next run${NC}"
echo ""

read -p "Stop instance now? (Y/n) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo -e "${BLUE}Stopping instance...${NC}"
    aws ec2 stop-instances --instance-ids "$INSTANCE_ID" >/dev/null
    echo -e "${GREEN}✓ Instance stopped${NC}"
else
    echo -e "${YELLOW}Instance left running${NC}"
fi
