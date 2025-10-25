#!/bin/bash
# Deploy Generated Dictionaries to Repositories
# Usage: ./deploy_dictionaries.sh [results-dir]

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Get results directory
if [ -n "$1" ]; then
    RESULTS_DIR="$1"
else
    RESULTS_DIR=$(ls -td extractor-results/*/ 2>/dev/null | head -1)
fi

if [ -z "$RESULTS_DIR" ] || [ ! -d "$RESULTS_DIR" ]; then
    echo -e "${RED}Error: No results directory found${NC}"
    echo "Usage: $0 [results-dir]"
    echo "Or ensure extractor-results/ contains a subdirectory"
    exit 1
fi

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BRANCH_NAME="dictionary-update-$TIMESTAMP"

echo "======================================"
echo "Dictionary Deployment"
echo "======================================"
echo "Results dir: $RESULTS_DIR"
echo "Branch: $BRANCH_NAME"
echo ""

# Check for required files
if [ ! -f "$RESULTS_DIR/apertium-ido.ido.dix" ]; then
    echo -e "${RED}Error: apertium-ido.ido.dix not found in $RESULTS_DIR${NC}"
    echo "Available files:"
    ls -lh "$RESULTS_DIR"
    exit 1
fi

if [ ! -f "$RESULTS_DIR/apertium-ido-epo.ido-epo.dix" ]; then
    echo -e "${RED}Error: apertium-ido-epo.ido-epo.dix not found in $RESULTS_DIR${NC}"
    echo "Available files:"
    ls -lh "$RESULTS_DIR"
    exit 1
fi

# Check GitHub CLI
if ! command -v gh &> /dev/null; then
    echo -e "${RED}Error: GitHub CLI (gh) not installed${NC}"
    echo "Install: https://cli.github.com/"
    exit 1
fi

# Check authentication
if ! gh auth status &>/dev/null; then
    echo -e "${RED}Error: GitHub CLI not authenticated${NC}"
    echo "Run: gh auth login"
    exit 1
fi

# Create temporary directory
TMP_DIR=$(mktemp -d)
trap "rm -rf $TMP_DIR" EXIT

echo -e "${BLUE}Preparing deployment...${NC}"

# Clone repositories
echo "Cloning apertium-ido..."
git clone https://github.com/komapc/apertium-ido.git "$TMP_DIR/apertium-ido" --depth 1

echo "Cloning apertium-ido-epo..."
git clone https://github.com/komapc/apertium-ido-epo.git "$TMP_DIR/apertium-ido-epo" --depth 1

# Deploy monolingual dictionary
echo ""
echo -e "${BLUE}Deploying monolingual dictionary...${NC}"
cd "$TMP_DIR/apertium-ido"

# Copy dictionary
cp "$SCRIPT_DIR/$RESULTS_DIR/apertium-ido.ido.dix" apertium-ido.ido.dix

# Create branch and commit
git checkout -b "$BRANCH_NAME"
git add apertium-ido.ido.dix
git commit -m "feat: Update Ido monolingual dictionary from extractor

Generated: $(date '+%Y-%m-%d %H:%M:%S')
Source: EC2 on-demand extractor run
Results: $RESULTS_DIR"

# Push and create PR
echo "Pushing branch..."
git push origin "$BRANCH_NAME"

echo "Creating PR..."
PR_URL=$(gh pr create --title "Update Ido Dictionary" \
    --body "Auto-generated dictionary update from EC2 extractor run

Generated: $(date '+%Y-%m-%d %H:%M:%S')
Source: EC2 on-demand extractor run
Results directory: $RESULTS_DIR" \
    --repo komapc/apertium-ido)

echo -e "${GREEN}✅ Monolingual PR: $PR_URL${NC}"

# Deploy bilingual dictionary
echo ""
echo -e "${BLUE}Deploying bilingual dictionary...${NC}"
cd "$TMP_DIR/apertium-ido-epo"

# Copy dictionary
cp "$SCRIPT_DIR/$RESULTS_DIR/apertium-ido-epo.ido-epo.dix" apertium-ido-epo.ido-epo.dix

# Create branch and commit
git checkout -b "$BRANCH_NAME"
git add apertium-ido-epo.ido-epo.dix
git commit -m "feat: Update bilingual dictionary from extractor

Generated: $(date '+%Y-%m-%d %H:%M:%S')
Source: EC2 on-demand extractor run
Results: $RESULTS_DIR"

# Push and create PR
echo "Pushing branch..."
git push origin "$BRANCH_NAME"

echo "Creating PR..."
PR_URL=$(gh pr create --title "Update Bilingual Dictionary" \
    --body "Auto-generated dictionary update from EC2 extractor run

Generated: $(date '+%Y-%m-%d %H:%M:%S')
Source: EC2 on-demand extractor run
Results directory: $RESULTS_DIR" \
    --repo komapc/apertium-ido-epo)

echo -e "${GREEN}✅ Bilingual PR: $PR_URL${NC}"

# Summary
echo ""
echo "======================================"
echo -e "${GREEN}Deployment Complete!${NC}"
echo "======================================"
echo "PRs created in:"
echo "  - komapc/apertium-ido"
echo "  - komapc/apertium-ido-epo"
echo ""
echo "Next steps:"
echo "  1. Review PRs on GitHub"
echo "  2. Run tests if available"
echo "  3. Merge when ready"
echo "======================================"

