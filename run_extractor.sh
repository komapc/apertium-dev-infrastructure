#!/bin/bash
# Run Extractor on EC2 Instance
# Git Clone Approach with S3 Backup

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

AWS_REGION="eu-west-1"  # From terraform.tfvars
export AWS_DEFAULT_REGION=$AWS_REGION
S3_BUCKET=$(terraform output -raw s3_bucket_name 2>/dev/null || echo "")
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
RESULTS_DIR="extractor-results/$TIMESTAMP"
LOG_FILE="extractor-run-$TIMESTAMP.log"

# Configuration (can be overridden via environment variables)
GITHUB_REPO="${GITHUB_REPO:-https://github.com/komapc/ido-esperanto-extractor.git}"
EXTRACTOR_DIR="${EXTRACTOR_DIR:-ido-esperanto-extractor}"
EXTRACTOR_BRANCH="${EXTRACTOR_BRANCH:-fix/extractor-script-references}"
ENTRY_POINT="${ENTRY_POINT:-regenerate-on-ec2.sh}"
RESULTS_DIR_INSTANCE="${RESULTS_DIR_INSTANCE:-~/ido-esperanto-extractor/dist}"

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

# Trap to ensure instance stops even on error
cleanup() {
    local exit_code=$?
    if [ $exit_code -ne 0 ]; then
        log_error "Script failed with exit code $exit_code"
    fi
    
    log "Cleaning up..."
    
    # Stop instance if it's running
    INSTANCE_STATE=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
        --query 'Reservations[0].Instances[0].State.Name' --output text 2>/dev/null || echo "stopped")
    
    if [ "$INSTANCE_STATE" = "running" ]; then
        log "Stopping instance..."
        aws ec2 stop-instances --instance-ids "$INSTANCE_ID" >/dev/null 2>&1 || true
        aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID" >/dev/null 2>&1 || true
        log_success "Instance stopped"
    fi
    
    exit $exit_code
}

trap cleanup EXIT INT TERM

# Start instance
log "Starting EC2 instance $INSTANCE_ID..."
aws ec2 start-instances --instance-ids "$INSTANCE_ID" >/dev/null
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
log_success "Instance started"

# Get IP address
PUBLIC_IP=$(aws ec2 describe-instances --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

log "Instance IP: $PUBLIC_IP"

# Wait for SSH to be ready
log "Waiting for SSH to be ready..."
for i in {1..30}; do
    if ssh -i ~/.ssh/id_rsa -o ConnectTimeout=2 -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP "echo 'SSH ready'" >/dev/null 2>&1; then
        log_success "SSH is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        log_error "SSH not ready after 60 seconds"
        exit 1
    fi
    sleep 2
done

# Run extractor on EC2
log "Starting extractor on EC2 instance..."
log "Repository: $GITHUB_REPO"

ssh -i ~/.ssh/id_rsa -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP << ENDSSH
  set -e
  
  echo "=== Extractor Run Started ==="
  echo "Timestamp: $TIMESTAMP"
  echo "Instance: \$(hostname)"
  echo "======================================"
  
  # Update system
  echo "Updating system packages..."
  sudo apt-get update -qq
  
  # Install git if not present
  if ! command -v git &> /dev/null; then
    echo "Installing git..."
    sudo apt-get install -y git >/dev/null
  fi
  
  # Install dependencies
  echo "Installing dependencies..."
  sudo apt-get install -y python3 python3-pip python3-venv wget >/dev/null
  
  # Use persistent directory in home
  cd ~
  
  # Clone or update repository
  if [ -d "ido-esperanto-extractor" ]; then
    echo "Updating existing repository..."
    cd ido-esperanto-extractor
    git fetch origin
    git checkout $EXTRACTOR_BRANCH
    git pull origin $EXTRACTOR_BRANCH
  else
    echo "Cloning repository..."
    echo "GITHUB_REPO: $GITHUB_REPO"
    echo "BRANCH: $EXTRACTOR_BRANCH"
    git clone --depth 1 --branch $EXTRACTOR_BRANCH $GITHUB_REPO ido-esperanto-extractor 2>&1 | head -20
    cd ido-esperanto-extractor
  fi
  
  # Create dumps directory (extractor expects dumps/ subdirectory)
  mkdir -p dumps
  
  # Install Python dependencies
  echo "Installing Python dependencies..."
  if [ -f requirements.txt ]; then
    pip3 install --user -r requirements.txt >/dev/null 2>&1
  fi
  
  # Download dumps
  echo "Downloading dumps..."
  if [ -f scripts/download_dumps.sh ]; then
    bash scripts/download_dumps.sh
    # Create symlink from data/raw to dumps for compatibility
    echo "Creating symlink from data/raw to dumps..."
    if [ -d data/raw ]; then
      # Remove existing dumps directory if it exists
      if [ -d dumps ]; then
        rm -rf dumps
      fi
      # Create symlink
      ln -s data/raw dumps
      echo "Symlink created: dumps -> data/raw"
      ls -la dumps/ | head -5
    else
      echo "⚠ data/raw directory not found after download"
    fi
  else
    echo "⚠ Download script not found, trying manual download..."
    # Download dumps manually if script doesn't exist
    mkdir -p dumps
    wget -q -O dumps/iowiki-latest-langlinks.sql.gz "https://dumps.wikimedia.org/iowiki/latest/iowiki-latest-langlinks.sql.gz" || true
    wget -q -O dumps/iowiki-latest-pages-articles.xml.bz2 "https://dumps.wikimedia.org/iowiki/latest/iowiki-latest-pages-articles.xml.bz2" || true
    wget -q -O dumps/iowiktionary-latest-pages-articles.xml.bz2 "https://dumps.wikimedia.org/iowiktionary/latest/iowiktionary-latest-pages-articles.xml.bz2" || true
    wget -q -O dumps/eowiktionary-latest-pages-articles.xml.bz2 "https://dumps.wikimedia.org/eowiktionary/latest/eowiktionary-latest-pages-articles.xml.bz2" || true
  fi
  
  # Create results directory
  mkdir -p $RESULTS_DIR_INSTANCE
  
  # Run extractor
  echo "======================================"
  echo "Running extractor..."
  echo "======================================"
  echo "Entry point: $ENTRY_POINT"
  
  # Run the regeneration script
  if [ -f "$ENTRY_POINT" ]; then
    echo "Found: $ENTRY_POINT"
    chmod +x $ENTRY_POINT
    ./$ENTRY_POINT 2>&1 || {
      echo "Extractor failed with exit code \$?"
      exit 1
    }
  elif [ -f "scripts/pipeline_manager.py" ]; then
    echo "Using pipeline manager..."
    python3 scripts/pipeline_manager.py 2>&1 || {
      echo "Extractor failed with exit code \$?"
      exit 1
    }
  else
    echo "⚠ No entry point found!"
    echo "Looked for: $ENTRY_POINT, scripts/pipeline_manager.py"
    echo "Available files:"
    ls -la
    exit 1
  fi
  
  echo "======================================"
  echo "Extractor completed successfully"
  echo "======================================"
  
  # Show results
  echo "Results:"
  ls -lh dist/ 2>/dev/null || echo "No dist directory"
  ls -lh reports/ 2>/dev/null || echo "No reports directory"
  
  # Show statistics
  if [ -f "dist/ido_dictionary.json" ]; then
    IDO_COUNT=\$(python3 -c "import json; print(len(json.load(open('dist/ido_dictionary.json'))))" 2>/dev/null || echo "unknown")
    echo "Ido dictionary: \$IDO_COUNT entries"
  fi
  
  if [ -f "dist/bidix_big.json" ]; then
    BIDIX_COUNT=\$(python3 -c "import json; print(len(json.load(open('dist/bidix_big.json'))))" 2>/dev/null || echo "unknown")
    echo "Bilingual dictionary: \$BIDIX_COUNT entries"
  fi
ENDSSH

EXTRACTOR_EXIT_CODE=$?

if [ $EXTRACTOR_EXIT_CODE -ne 0 ]; then
    log_error "Extractor failed with exit code $EXTRACTOR_EXIT_CODE"
    exit $EXTRACTOR_EXIT_CODE
fi

log_success "Extractor completed"

# Copy results back to local machine
log "Copying results to local machine..."
mkdir -p "$RESULTS_DIR"

# Copy dist files
if scp -i ~/.ssh/id_rsa -r ubuntu@$PUBLIC_IP:~/ido-esperanto-extractor/dist/* "$RESULTS_DIR/" 2>/dev/null; then
    log_success "Results copied to $RESULTS_DIR"
else
    log_warning "Could not copy results (might be empty or permission issue)"
fi

# Copy reports
log "Copying reports..."
mkdir -p "$RESULTS_DIR/reports"
scp -i ~/.ssh/id_rsa -r ubuntu@$PUBLIC_IP:~/ido-esperanto-extractor/reports/* "$RESULTS_DIR/reports/" 2>/dev/null || true

# Copy logs
log "Copying logs..."
scp -i ~/.ssh/id_rsa ubuntu@$PUBLIC_IP:~/ido-esperanto-extractor/logs/*.log "$RESULTS_DIR/" 2>/dev/null || true

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

# Stop instance
log "Stopping instance..."
aws ec2 stop-instances --instance-ids "$INSTANCE_ID" >/dev/null
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID" >/dev/null
log_success "Instance stopped"

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

