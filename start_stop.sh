#!/bin/bash
# Start/Stop EC2 Instance Script
# Usage: ./start_stop.sh [start|stop|status]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load instance ID and region from terraform output
get_instance_id() {
    cd "$(dirname "$0")"
    terraform output -raw instance_id 2>/dev/null || {
        echo -e "${RED}Error: Could not get instance ID. Run 'terraform apply' first.${NC}"
        exit 1
    }
}

INSTANCE_ID=$(get_instance_id)
AWS_REGION="eu-west-1"  # From terraform.tfvars
export AWS_DEFAULT_REGION=$AWS_REGION

case "$1" in
    start)
        echo -e "${YELLOW}Starting instance ${INSTANCE_ID}...${NC}"
        aws ec2 start-instances --instance-ids "$INSTANCE_ID"
        
        echo -e "${YELLOW}Waiting for instance to be running...${NC}"
        aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
        
        # Get public IP
        PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
        
        echo -e "${GREEN}Instance started successfully!${NC}"
        echo -e "${GREEN}Public IP: ${PUBLIC_IP}${NC}"
        echo -e "${GREEN}SSH: ssh -i ~/.ssh/id_rsa ubuntu@${PUBLIC_IP}${NC}"
        echo -e "${GREEN}APy URL: http://${PUBLIC_IP}:2737${NC}"
        ;;
        
    stop)
        echo -e "${YELLOW}Stopping instance ${INSTANCE_ID}...${NC}"
        aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
        
        echo -e "${YELLOW}Waiting for instance to stop...${NC}"
        aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"
        
        echo -e "${GREEN}Instance stopped successfully!${NC}"
        echo -e "${YELLOW}You will still be charged for EBS storage (~$2/month)${NC}"
        ;;
        
    status)
        STATUS=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
            --query 'Reservations[0].Instances[0].State.Name' --output text)
        
        if [ "$STATUS" = "running" ]; then
            PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
                --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)
            echo -e "${GREEN}Status: ${STATUS}${NC}"
            echo -e "${GREEN}Public IP: ${PUBLIC_IP}${NC}"
        else
            echo -e "${YELLOW}Status: ${STATUS}${NC}"
        fi
        ;;
        
    *)
        echo "Usage: $0 {start|stop|status}"
        echo ""
        echo "Commands:"
        echo "  start  - Start the EC2 instance"
        echo "  stop   - Stop the EC2 instance (saves compute costs)"
        echo "  status - Check instance status"
        exit 1
        ;;
esac

