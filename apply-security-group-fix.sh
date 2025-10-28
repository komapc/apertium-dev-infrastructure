#!/bin/bash
# Apply security group fix to open port 8081

set -e

cd "$(dirname "$0")"

echo "=== Applying Security Group Fix ==="
echo ""
echo "This will add port 8081 to the EC2 security group for webhook access."
echo ""

# Check if terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "Initializing Terraform..."
    terraform init
fi

# Show what will change
echo "Planning changes..."
echo ""
terraform plan -target=aws_security_group.apy_server

echo ""
read -p "Apply these changes? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Apply the changes
echo ""
echo "Applying changes..."
terraform apply -target=aws_security_group.apy_server -auto-approve

echo ""
echo "=== Security Group Updated ==="
echo ""
echo "Port 8081 is now open for webhook access!"
echo ""
echo "Next steps:"
echo "1. Run: cd ~/apertium-dev/projects/translator && ./fix-webhook-properly.sh"
echo "2. Test the web UI at: https://ido-epo-translator.pages.dev"
