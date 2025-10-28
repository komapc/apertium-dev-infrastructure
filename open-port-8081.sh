#!/bin/bash
# Manually open port 8081 in EC2 security group using AWS CLI

set -e

echo "=== Opening Port 8081 in Security Group ==="
echo ""

# Get instance ID
echo "1. Getting instance ID..."
INSTANCE_ID=$(ssh ec2-translator "ec2-metadata --instance-id 2>/dev/null | cut -d ' ' -f 2" || echo "")

if [ -z "$INSTANCE_ID" ]; then
    echo "⚠️  Could not get instance ID from EC2 metadata"
    echo "Please enter your EC2 instance ID (e.g., i-0123456789abcdef0):"
    read -p "Instance ID: " INSTANCE_ID
fi

echo "Instance ID: $INSTANCE_ID"

# Get security group ID
echo ""
echo "2. Getting security group ID..."
SG_ID=$(aws ec2 describe-instances \
    --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' \
    --output text)

echo "Security Group ID: $SG_ID"

# Check if port 8081 is already open
echo ""
echo "3. Checking current rules..."
EXISTING=$(aws ec2 describe-security-groups \
    --group-ids $SG_ID \
    --query "SecurityGroups[0].IpPermissions[?FromPort==\`8081\`]" \
    --output text)

if [ -n "$EXISTING" ]; then
    echo "✅ Port 8081 is already in the security group!"
    echo "But it might not be configured correctly. Let's check..."
    aws ec2 describe-security-groups \
        --group-ids $SG_ID \
        --query "SecurityGroups[0].IpPermissions[?FromPort==\`8081\`]" \
        --output json
else
    echo "Port 8081 is NOT in the security group. Adding it..."
    
    # Add the rule
    aws ec2 authorize-security-group-ingress \
        --group-id $SG_ID \
        --protocol tcp \
        --port 8081 \
        --cidr 0.0.0.0/0 \
        --description "Webhook server for dictionary updates"
    
    echo "✅ Port 8081 added to security group!"
fi

# Verify
echo ""
echo "4. Verifying all open ports..."
aws ec2 describe-security-groups \
    --group-ids $SG_ID \
    --query 'SecurityGroups[0].IpPermissions[*].[FromPort,ToPort,IpProtocol,IpRanges[0].CidrIp]' \
    --output table

# Test connectivity
echo ""
echo "5. Testing port connectivity (wait 10 seconds for AWS to apply)..."
sleep 10

timeout 5 bash -c "</dev/tcp/ec2-52-211-137-158.eu-west-1.compute.amazonaws.com/8081" 2>/dev/null && \
    echo "✅ Port 8081 is now OPEN!" || \
    echo "⚠️  Port 8081 still appears closed. Wait a minute and try again."

echo ""
echo "=== Complete ==="
echo ""
echo "Next steps:"
echo "1. Wait 1-2 minutes for AWS changes to propagate"
echo "2. Test: cd ~/apertium-dev/projects/translator && ./full-diagnostic.sh"
echo "3. Try the web UI: https://ido-epo-translator.pages.dev"
