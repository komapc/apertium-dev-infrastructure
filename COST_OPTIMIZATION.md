# Cost Optimization Guide

## Understanding AWS EC2 Billing

### Payment Model

**EC2 is billed PER HOUR that the instance is RUNNING:**
- ✅ Instance running: You pay compute costs (~$0.0208/hour for t3.small)
- ✅ Instance stopped: You DON'T pay compute costs
- ⚠️ Storage (EBS): Always charged (~$2/month for 20GB) - even when stopped
- ✅ Elastic IP: Free when attached to instance (charged if not attached)

### Monthly Cost Scenarios

| Usage Pattern | Compute Hours | Monthly Cost |
|--------------|---------------|--------------|
| Always on | 730 hours | ~$15 compute + $2 storage = **$17/month** |
| 10 hours/month | 10 hours | ~$0.21 compute + $2 storage = **$2.21/month** |
| Weekdays only (8h/day) | ~160 hours | ~$3.33 compute + $2 storage = **$5.33/month** |

## Cost Optimization Strategies

### 1. Stop Instance When Not in Use

**Manual Control:**

```bash
cd terraform

# Stop instance (stops compute billing)
./start_stop.sh stop

# Start instance when needed
./start_stop.sh start

# Check status
./start_stop.sh status
```

**When to Stop:**
- Not actively using translator
- Overnight/weekends
- Vacation periods
- Testing/debugging complete

**What You Still Pay:**
- EBS storage: ~$2/month (unavoidable)
- Elastic IP: Free (free)

**What You DON'T Pay:**
- Compute time: $0 while stopped

### 2. Automated Scheduling

Create scheduled start/stop with AWS EventBridge:

#### Stop Every Night at 2 AM

```bash
aws events put-rule \
  --name apy-server-nightly-stop \
  --schedule-expression "cron(0 2 * * ? *)" \
  --state ENABLED

aws events put-targets \
  --rule apy-server-nightly-stop \
  --targets "Id"="1","Arn"="arn:aws:events:us-east-1::targets/ec2-stop-instance",\
  "Ec2Parameters"="{\"Instances\":[\"$(terraform output -raw instance_id)\"]}"
```

#### Start Every Morning at 8 AM

```bash
aws events put-rule \
  --name apy-server-morning-start \
  --schedule-expression "cron(0 8 * * ? *)" \
  --state ENABLED

aws events put-targets \
  --rule apy-server-morning-start \
  --targets "Id"="1","Arn"="arn:aws:events:us-east-1::targets/ec2-start-instance",\
  "Ec2Parameters"="{\"Instances\":[\"$(terraform output -raw instance_id)\"]}"
```

### 3. Use Smaller Instance for Testing

Create separate testing environment:

```hcl
# In terraform/main.tf, change instance_type
variable "instance_type" {
  default = "t3.micro"  # $7/month instead of $15
}
```

**Note:** t3.micro has only 1GB RAM - may not be sufficient for APy with large dictionaries.

### 4. Right-Size Instance

| Instance Type | RAM | vCPU | Cost/Hour | Best For |
|--------------|-----|------|-----------|----------|
| t3.micro | 1GB | 2 | $0.0104 | Testing only (insufficient RAM) |
| t3.small | 2GB | 2 | $0.0208 | Production (recommended) |
| t3.medium | 4GB | 2 | $0.0416 | Heavy usage |

### 5. Use Reserved Instances (Long-term)

For 1-year commitment, save 40%:

- **On-Demand**: $15/month
- **Reserved 1-year**: $9/month
- **Savings**: $6/month ($72/year)

### 6. Monitoring and Billing Alerts

Set up billing alerts:

```bash
# Create billing alarm at $10/month
aws cloudwatch put-metric-alarm \
  --alarm-name aws-billing-alarm-apy-server \
  --alarm-description "Alert when charges exceed $10" \
  --metric-name EstimatedCharges \
  --namespace AWS/Billing \
  --statistic Maximum \
  --period 86400 \
  --evaluation-periods 1 \
  --threshold 10 \
  --comparison-operator GreaterThanThreshold \
  --alarm-actions "arn:aws:sns:REGION:ACCOUNT-ID:billing-alerts"
```

## Monthly Cost Breakdown

### Always-On Scenario ($17/month)

```
Compute (t3.small):      $15.20/month   (730 hours × $0.0208)
EBS Storage (20GB):     $ 2.00/month   (gp3 storage)
Elastic IP:             $ 0.00/month   (free when attached)
Data Transfer:          $ 0.00/month   (first 100GB free)
─────────────────────────────────────────
Total:                  $17.20/month
```

### 10 Hours/Month Scenario ($2.21/month)

```
Compute (t3.small):      $ 0.21/month   (10 hours × $0.0208)
EBS Storage (20GB):     $ 2.00/month   (gp3 storage)
Elastic IP:             $ 0.00/month   (free when attached)
Data Transfer:          $ 0.00/month   (assumed minimal)
─────────────────────────────────────────
Total:                  $ 2.21/month
```

### Weekdays Only Scenario ($5.33/month)

```
Compute (t3.small):      $ 3.33/month   (160 hours × $0.0208)
EBS Storage (20GB):     $ 2.00/month   (gp3 storage)
Elastic IP:             $ 0.00/month   (free when attached)
Data Transfer:          $ 0.00/month   (assumed minimal)
─────────────────────────────────────────
Total:                  $ 5.33/month
```

## Cost Calculator

Your approximate monthly cost:

```bash
echo "Compute cost: \$ $(echo "scale=2; <hours> * 0.0208" | bc)"
echo "Storage cost: \$ 2.00"
echo "Total: \$ $(echo "scale=2; <hours> * 0.0208 + 2.00" | bc)"
```

Replace `<hours>` with your usage.

## Recommendations

### For Development/Testing
- ✅ Use `start_stop.sh` to stop instance when not needed
- ✅ Target: $2-5/month
- ✅ Start instance only when working on project

### For Production
- ✅ Keep instance running if users depend on it
- ✅ Monitor with CloudWatch
- ✅ Set up billing alerts
- ✅ Target: $15-17/month

### For Personal Use
- ✅ Stop instance when not actively translating
- ✅ Consider automated scheduling (nightly stop)
- ✅ Target: $3-7/month depending on usage

## Questions?

- **Will stopping affect my data?** No, data persists on EBS.
- **Will public IP change?** No, Elastic IP remains the same.
- **Can I automate this?** Yes, use AWS EventBridge scheduled rules.
- **What about Cloudflare Worker?** Worker will fail gracefully when instance is stopped (just show error to users).

