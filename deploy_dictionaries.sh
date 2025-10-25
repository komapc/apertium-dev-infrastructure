#!/bin/bash
# Deploy Generated Dictionaries to Repositories
# Usage: ./deploy_dictionaries.sh [results-dir]
#        If no results-dir provided, uses latest extractor-results/*/

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

# Auto-detect latest if no specific directory provided
if [ -z "$1" ]; then
    echo -e "${BLUE}Auto-detected latest results: $RESULTS_DIR${NC}"
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

# Show dictionary comparison
echo ""
echo "======================================"
echo "Dictionary Comparison"
echo "======================================"

# Function to count entries in .dix file
count_dix_entries() {
    local file="$1"
    if [ -f "$file" ]; then
        grep -c "<e " "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to count entries in JSON file
count_json_entries() {
    local file="$1"
    if [ -f "$file" ]; then
        python3 -c "import json; print(len(json.load(open('$file'))))" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Function to show comparison
show_comparison() {
    local name="$1"
    local old_file="$2"
    local new_file="$3"
    local count_func="$4"
    
    echo -e "${BLUE}$name:${NC}"
    OLD_SIZE=$($count_func "$old_file")
    NEW_SIZE=$($count_func "$new_file")
    
    if [ "$OLD_SIZE" -gt 0 ] && [ "$NEW_SIZE" -gt 0 ]; then
        DIFF=$((NEW_SIZE - OLD_SIZE))
        PERCENT_CHANGE=$(awk "BEGIN {printf \"%.1f\", ($DIFF / $OLD_SIZE) * 100}")
        
        if [ "$DIFF" -gt 0 ]; then
            echo -e "  Current: ${GREEN}$OLD_SIZE entries${NC}"
            echo -e "  New:     ${GREEN}$NEW_SIZE entries${NC}"
            echo -e "  Change:  ${GREEN}+$DIFF (+$PERCENT_CHANGE%)${NC}"
        elif [ "$DIFF" -lt 0 ]; then
            echo -e "  Current: ${YELLOW}$OLD_SIZE entries${NC}"
            echo -e "  New:     ${RED}$NEW_SIZE entries${NC}"
            echo -e "  Change:  ${RED}$DIFF ($PERCENT_CHANGE%)${NC}"
            echo -e "  ${YELLOW}⚠️  Warning: Dictionary size decreased!${NC}"
        else
            echo -e "  Current: $OLD_SIZE entries"
            echo -e "  New:     $NEW_SIZE entries"
            echo -e "  Change:  No change"
        fi
    elif [ "$OLD_SIZE" -eq 0 ] && [ "$NEW_SIZE" -gt 0 ]; then
        echo -e "  Current: No existing dictionary"
        echo -e "  New:     ${GREEN}$NEW_SIZE entries${NC}"
        echo -e "  Change:  ${GREEN}+$NEW_SIZE (new)${NC}"
    elif [ "$OLD_SIZE" -gt 0 ] && [ "$NEW_SIZE" -eq 0 ]; then
        echo -e "  Current: ${YELLOW}$OLD_SIZE entries${NC}"
        echo -e "  New:     No dictionary found"
        echo -e "  Change:  ${RED}-$OLD_SIZE (lost)${NC}"
        echo -e "  ${YELLOW}⚠️  Warning: Dictionary missing!${NC}"
    else
        echo "  Unable to count entries"
    fi
}

# Compare Apertium dictionaries
show_comparison "Monolingual Dictionary (apertium-ido.ido.dix)" \
    "$TMP_DIR/apertium-ido/apertium-ido.ido.dix" \
    "$RESULTS_DIR/apertium-ido.ido.dix" \
    "count_dix_entries"

echo ""
show_comparison "Bilingual Dictionary (apertium-ido-epo.ido-epo.dix)" \
    "$TMP_DIR/apertium-ido-epo/apertium-ido-epo.ido-epo.dix" \
    "$RESULTS_DIR/apertium-ido-epo.ido-epo.dix" \
    "count_dix_entries"

# Compare JSON dictionaries if available
echo ""
echo "======================================"
echo "Source Analysis (JSON dictionaries)"
echo "======================================"

# Check for JSON files in results
if [ -d "$RESULTS_DIR" ]; then
    echo "Available artifacts in results:"
    ls -lh "$RESULTS_DIR" | grep -E "\.(json|dix)$" | head -10
    
    # Compare specific JSON files if they exist
    if [ -f "$RESULTS_DIR/ido_dictionary.json" ]; then
        echo ""
        show_comparison "Ido Monolingual JSON" \
            "$TMP_DIR/apertium-ido/ido_dictionary.json" \
            "$RESULTS_DIR/ido_dictionary.json" \
            "count_json_entries"
    fi
    
    if [ -f "$RESULTS_DIR/bidix_big.json" ]; then
        echo ""
        show_comparison "Bilingual JSON" \
            "$TMP_DIR/apertium-ido-epo/bidix_big.json" \
            "$RESULTS_DIR/bidix_big.json" \
            "count_json_entries"
    fi
fi

echo "======================================"
echo ""
read -p "Proceed with deployment? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled."
    exit 0
fi
echo ""

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

