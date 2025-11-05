#!/bin/bash
# Improved Extractor Runner with Better Error Handling
# Runs extraction in background on EC2 and polls for completion

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

INSTANCE_ID=$(terraform output -raw instance_id 2>/dev/null || {
    echo -e "${RED}Error: Could not get instance ID. Run 'terraform apply' first.${NC}"
    exit 1
})

AWS_REGION="eu-west-1"
export AWS_DEFAULT_REGION=$AWS_REGION
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="extractor-results/$TIMESTAMP"
LOG_FILE="extractor-run-$TIMESTAMP.log"

# Configuration
GITHUB_REPO="${GITHUB_REPO:-https://github.com/komapc/ido-esperanto-extractor.git}"
EXTRACTOR_BRANCH="${EXTRACTOR_BRANCH:-master}"
EXTRACTOR_DIR="/tmp/ido-esperanto-extractor"
REMOTE_LOG="/tmp/extraction_${TIMESTAMP}.log"
REMOTE_PID="/tmp/extraction_${TIMESTAMP}.pid"

# Function to log messages
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')]✓${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')]✗${NC} $1" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')]⚠${NC} $1" | tee -a "$LOG_FILE"
}

# Cleanup function (instance stays running)
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Script failed with exit code $exit_code"
    fi
    
    log "Cleaning up..."
    log_warning "Instance left running (not stopped automatically)"
    
    exit $exit_code
}

trap cleanup EXIT INT TERM

# Start instance if not running
log "Checking instance status..."
INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "unknown")

if [ "$INSTANCE_STATE" != "running" ]; then
    log "Starting EC2 instance $INSTANCE_ID..."
    aws ec2 start-instances --instance-ids "$INSTANCE_ID" >/dev/null
    aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
    log_success "Instance started"
    sleep 10  # Give SSH time to start
else
    log_success "Instance already running"
fi

# Get IP address
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

log "Instance IP: $PUBLIC_IP"

# Wait for SSH to be ready
log "Waiting for SSH to be ready..."
for i in {1..30}; do
    if ssh -i ~/.ssh/id_rsa -o ConnectTimeout=5 -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "echo 'SSH ready'" >/dev/null 2>&1; then
        log_success "SSH is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "SSH not ready after 150 seconds"
        exit 1
    fi
    sleep 5
done

# Setup and start extraction in background on EC2
log "Setting up extractor on EC2..."

ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP << 'ENDSSH'
  set -e
  
  echo "=== Setting up extractor ==="
  
  # Install dependencies
  sudo apt-get update -qq
  sudo apt-get install -y python3 python3-pip git wget -qq
  
  # Setup extractor directory
  cd /tmp
  if [ -d "ido-esperanto-extractor" ]; then
    cd ido-esperanto-extractor
    git fetch origin
    git checkout master
    git pull origin master
  else
    git clone https://github.com/komapc/ido-esperanto-extractor.git
    cd ido-esperanto-extractor
  fi
  
  # Install Python dependencies
  if [ -f requirements.txt ]; then
    pip3 install --user -r requirements.txt >/dev/null 2>&1 || true
  fi
  
  # Create symlink for dumps
  if [ -d data/raw ] && [ ! -L dumps ]; then
    rm -rf dumps
    ln -s data/raw dumps
  fi
  
  echo "Setup complete"
ENDSSH

log_success "Setup complete"

# Start extraction in background
log "Starting extraction in background on EC2..."

ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP << ENDSSH
  cd $EXTRACTOR_DIR
  
  # Kill any existing extraction
  pkill -f "python3 scripts/run.py" 2>/dev/null || true
  
  # Start extraction in background
  nohup python3 scripts/run.py > $REMOTE_LOG 2>&1 &
  echo \$! > $REMOTE_PID
  
  echo "Extraction started with PID: \$(cat $REMOTE_PID)"
ENDSSH

log_success "Extraction started in background"

# Poll for completion
log "Monitoring extraction progress..."
log "You can also monitor directly: ssh ubuntu@$PUBLIC_IP 'tail -f $REMOTE_LOG'"
echo ""

POLL_INTERVAL=30
MAX_WAIT=7200  # 2 hours
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    # Check if process is still running
    RUNNING=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
        "ps -p \$(cat $REMOTE_PID 2>/dev/null) >/dev/null 2>&1 && echo 'yes' || echo 'no'" 2>/dev/null || echo "no")
    
    if [ "$RUNNING" = "no" ]; then
        log "Extraction process completed"
        break
    fi
    
    # Show progress
    LAST_LINE=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
        "tail -1 $REMOTE_LOG 2>/dev/null" 2>/dev/null || echo "")
    
    if [ -n "$LAST_LINE" ]; then
        log "Progress: $LAST_LINE"
    fi
    
    sleep $POLL_INTERVAL
    ELAPSED=$((ELAPSED + POLL_INTERVAL))
done

if [ $ELAPSED -ge $MAX_WAIT ]; then
    log_warning "Extraction exceeded maximum wait time (2 hours)"
    log_warning "Process may still be running on EC2"
    log "Check status: ssh ubuntu@$PUBLIC_IP 'tail -50 $REMOTE_LOG'"
    exit 1
fi

# Check exit status
EXIT_CODE=$(ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "tail -100 $REMOTE_LOG | grep -q 'Error\|Failed' && echo 1 || echo 0" 2>/dev/null || echo 1)

if [ "$EXIT_CODE" -ne 0 ]; then
    log_error "Extraction failed"
    log "Check logs: ssh ubuntu@$PUBLIC_IP 'tail -100 $REMOTE_LOG'"
    exit 1
fi

log_success "Extraction completed successfully"

# Copy results back
log "Copying results to local machine..."
mkdir -p "$RESULTS_DIR"

# Copy dist files
if scp -i ~/.ssh/id_rsa -r ubuntu@$PUBLIC_IP:$EXTRACTOR_DIR/dist/* "$RESULTS_DIR/" 2>/dev/null; then
    log_success "Results copied to $RESULTS_DIR"
else
    log_warning "Could not copy results (might be empty or permission issue)"
fi

# Copy reports
log "Copying reports..."
mkdir -p "$RESULTS_DIR/reports"
scp -i ~/.ssh/id_rsa -r ubuntu@$PUBLIC_IP:$EXTRACTOR_DIR/reports/* "$RESULTS_DIR/reports/" 2>/dev/null || true

# Copy logs
log "Copying logs..."
scp -i ~/.ssh/id_rsa ubuntu@$PUBLIC_IP:$REMOTE_LOG "$RESULTS_DIR/extraction.log" 2>/dev/null || true

# Upload to S3 (if bucket exists)
if [ -n "$S3_BUCKET" ]; then
    log "Uploading results to S3..."
    if aws s3 sync "$RESULTS_DIR/" "s3://$S3_BUCKET/$TIMESTAMP/" --no-progress >/dev/null 2>&1; then
        log_success "Results uploaded to S3: s3://$S3_BUCKET/$TIMESTAMP/"
    else
        log_warning "Could not upload to S3 (check AWS credentials)"
    fi
else
    log_warning "S3 bucket not configured, skipping upload"
fi

# Keep instance running
log_warning "Instance left running (not stopped automatically)"
log "To stop manually: ./start_stop.sh stop"

# Summary
echo ""
echo "======================================"
log_success "Extractor run completed successfully!"
echo "======================================"
echo "Results location:"
echo "  Local:  $RESULTS_DIR"
if [ -n "$S3_BUCKET" ]; then
    echo "  S3:     s3://$S3_BUCKET/$TIMESTAMP/"
fi
echo "  Log:    $LOG_FILE"
echo "======================================"

# Disable cleanup trap since we're done
trap - EXIT INT TERM
