#!/bin/bash
# Update references from apertium-terraform to apertium-terraform

echo "=== Updating repository references ==="
echo ""

cd ~/apertium-dev/terraform

# Update references in markdown files
echo "Updating *.md files..."
find . -type f -name "*.md" \
    -not -path "./.git/*" \
    -exec sed -i 's|apertium-terraform|apertium-terraform|g' {} +

# Update references in shell scripts
echo "Updating *.sh files..."
find . -type f -name "*.sh" \
    -not -path "./.git/*" \
    -exec sed -i 's|apertium-terraform|apertium-terraform|g' {} +

echo ""
echo "=== Done ==="
echo ""
echo "Review changes with: git diff"
echo "Commit with: git commit -am 'docs: update repo name to apertium-terraform'"
