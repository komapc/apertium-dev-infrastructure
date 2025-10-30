#!/bin/bash
# Monitor Extractor Progress
# Usage: ./monitor_extractor.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || echo "not-found")
PUBLIC_IP=$(terraform output -raw public_ip 2>/dev/null || echo "not-found")
LOG_FILE=$(ls -t extractor-run-*.log 2>/dev/null | head -1 || echo "")

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "======================================"
echo "Extractor Progress Monitor"
echo "======================================"
echo ""

# Check instance status
echo -e "${BLUE}Instance Status:${NC}"
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region eu-west-1 \
    --query 'Reservations[0].Instances[0].[State.Name]' --output text 2>/dev/null || echo "not-found"
echo ""

# Check if extractor process is running
echo -e "${BLUE}Extractor Process:${NC}"
if [ "$PUBLIC_IP" != "not-found" ]; then
    # Check if instance exists and is accessible
    INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region eu-west-1 \
        --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "unknown")
    
    if [ "$INSTANCE_STATE" = "running" ]; then
        PROCESS_OUTPUT=$(ssh -i ~/.ssh/id_rsa -o ConnectTimeout=2 ubuntu@$PUBLIC_IP \
            "ps aux | grep 'python3 run.py' | grep -v grep" 2>/dev/null)
        
        if [ -n "$PROCESS_OUTPUT" ]; then
            echo "✅ Running"
        else
            echo "⚠ Not running (instance is up but no extractor process)"
        fi
    elif [ "$INSTANCE_STATE" = "stopped" ]; then
        echo "⚠ Instance stopped"
    elif [ "$INSTANCE_STATE" = "terminated" ]; then
        echo "❌ Instance terminated"
    else
        echo "⚠ Instance state: $INSTANCE_STATE"
    fi
else
    echo "Instance not available"
fi
echo ""

# Show recent log output
if [ -n "$LOG_FILE" ] && [ -f "$LOG_FILE" ]; then
    echo -e "${BLUE}Recent Log Output (last 15 lines):${NC}"
    tail -15 "$LOG_FILE" 2>/dev/null | grep -E "(Running|Parsing|Merging|Exporting|ERROR|FAILED|✓|✗|downloading|Downloading|Download)" || tail -5 "$LOG_FILE" 2>/dev/null
    echo ""
    
    # Check for errors
    if grep -q "ERROR\|FAILED\|error" "$LOG_FILE" 2>/dev/null; then
        echo -e "${RED}⚠ Errors found in log!${NC}"
        grep -i "error\|failed" "$LOG_FILE" 2>/dev/null | tail -3
        echo ""
    fi
fi

# Check file generation
echo -e "${BLUE}Generated Files:${NC}"
if [ "$PUBLIC_IP" != "not-found" ]; then
    INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region eu-west-1 \
        --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "unknown")
    
    if [ "$INSTANCE_STATE" = "running" ]; then
        FILE_COUNT=$(ssh -i ~/.ssh/id_rsa ubuntu@$PUBLIC_IP \
            "cd ~/ido-esperanto-extractor && find data sources -name '*.json' -type f 2>/dev/null | wc -l" 2>/dev/null || echo "0")
        echo "JSON files created: $FILE_COUNT"
        
        # Check for final outputs
        OUTPUTS=$(ssh -i ~/.ssh/id_rsa ubuntu@$PUBLIC_IP \
            "cd ~/ido-esperanto-extractor && ls -lh dictionary*.json apertium*.dix 2>/dev/null | head -5" 2>/dev/null)
        
        if [ -n "$OUTPUTS" ]; then
            echo "$OUTPUTS"
        else
            echo "No outputs yet"
        fi
    else
        echo "Instance $INSTANCE_STATE - cannot check files"
    fi
else
    echo "Cannot check - instance not available"
fi
echo ""

# Time elapsed
if [ -n "$LOG_FILE" ]; then
    START_TIME=$(stat -c %Y "$LOG_FILE" 2>/dev/null || echo 0)
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    MINUTES=$((ELAPSED / 60))
    SECONDS=$((ELAPSED % 60))
    echo -e "${BLUE}Time Elapsed:${NC} ${MINUTES}m ${SECONDS}s"
fi

echo ""
echo "======================================"
echo "To watch logs live:"
echo "  tail -f $LOG_FILE"
echo "======================================"

