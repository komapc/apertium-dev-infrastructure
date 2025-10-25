# AWS EventBridge Automation Guide

## What is AWS EventBridge?

**AWS EventBridge** is a serverless event bus that can trigger actions on a schedule or in response to events.

Think of it as: **"Do X at Y time"** or **"When X happens, do Y"**

## How EventBridge Works

```
Schedule Expression → EventBridge Rule → Target Action
     (cron)                                  (start/stop EC2)
```

### Simple Example

```bash
# "Every day at 2 AM, stop the EC2 instance"
Every day at 2:00 AM → EventBridge → Stop EC2 instance

# "Every day at 8 AM, start the EC2 instance"  
Every day at 8:00 AM → EventBridge → Start EC2 instance
```

## Basic Concepts

### 1. Rules
A rule defines **when** something should happen.

### 2. Targets
A target defines **what** should happen (which AWS service/action).

### 3. Schedule Expressions
Cron syntax for timing:
- `cron(0 2 * * ? *)` = Every day at 2:00 AM
- `cron(0 8 * * ? *)` = Every day at 8:00 AM
- `cron(0 18 ? * MON-FRI *)` = Weekdays at 6:00 PM

## Real-World Setup

### Scenario: Stop at Night, Start in Morning

**Goal:** Automatically stop instance at 2 AM, start at 8 AM every day.

**Cost Savings:** ~$0.13/day = ~$4/month saved

---

## Manual Setup (Using AWS CLI)

### Step 1: Get Your Instance ID

```bash
cd terraform
terraform output instance_id
# Output: i-1234567890abcdef0
```

### Step 2: Create Stop Rule (Every Night at 2 AM)

```bash
INSTANCE_ID=$(terraform output -raw instance_id)
AWS_REGION=$(terraform output -raw aws_region)

# Create the rule
aws events put-rule \
  --name apy-server-stop-nightly \
  --schedule-expression "cron(0 2 * * ? *)" \
  --state ENABLED \
  --description "Stop APy server every night at 2 AM"

# Assign EC2 stop permission to EventBridge
aws events put-targets \
  --rule apy-server-stop-nightly \
  --targets "Id"="1","Arn"="arn:aws:events:${AWS_REGION}::targets/ec2-stop-instance","Ec2Parameters"="{\"Instances\":[\"${INSTANCE_ID}\"]}"
```

### Step 3: Create Start Rule (Every Morning at 8 AM)

```bash
# Create the rule
aws events put-rule \
  --name apy-server-start-morning \
  --schedule-expression "cron(0 8 * * ? *)" \
  --state ENABLED \
  --description "Start APy server every morning at 8 AM"

# Assign EC2 start permission to EventBridge
aws events put-targets \
  --rule apy-server-start-morning \
  --targets "Id"="1","Arn"="arn:aws:events:${AWS_REGION}::targets/ec2-start-instance","Ec2Parameters"="{\"Instances\":[\"${INSTANCE_ID}\"]}"
```

### Step 4: Verify Rules Are Active

```bash
# List all rules
aws events list-rules --name-prefix apy-server

# Check targets for stop rule
aws events list-targets-by-rule --rule apy-server-stop-nightly

# Check targets for start rule
aws events list-targets-by-rule --rule apy-server-start-morning
```

---

## Terraform Automated Setup

I'll create a Terraform module to automate this setup.

### Create `modules/automation/main.tf`:

```hcl
variable "instance_id" {
  description = "EC2 instance ID to manage"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

# Stop rule - every night at 2 AM
resource "aws_cloudwatch_event_rule" "stop_nightly" {
  name                = "apy-server-stop-nightly"
  description         = "Stop APy server every night at 2 AM"
  schedule_expression = "cron(0 2 * * ? *)"
  state               = "ENABLED"
}

resource "aws_cloudwatch_event_target" "stop_nightly" {
  rule      = aws_cloudwatch_event_rule.stop_nightly.name
  target_id = "StopAPyServer"
  arn       = "arn:aws:events:${var.aws_region}::targets/ec2-stop-instance"
  
  ec2_target {
    instances = [var.instance_id]
  }
}

# Start rule - every morning at 8 AM
resource "aws_cloudwatch_event_rule" "start_morning" {
  name                = "apy-server-start-morning"
  description         = "Start APy server every morning at 8 AM"
  schedule_expression = "cron(0 8 * * ? *)"
  state               = "ENABLED"
}

resource "aws_cloudwatch_event_target" "start_morning" {
  rule      = aws_cloudwatch_event_rule.start_morning.name
  target_id = "StartAPyServer"
  arn       = "arn:aws:events:${var.aws_region}::targets/ec2-start-instance"
  
  ec2_target {
    instances = [var.instance_id]
  }
}
```

### Add to Main `main.tf`:

```hcl
module "automation" {
  source     = "./modules/automation"
  instance_id = aws_instance.apy_server.id
  aws_region   = var.aws_region
  
  # Optionally enable/disable
  # count = var.enable_automation ? 1 : 0
}
```

---

## Common Schedule Patterns

### Weekdays Only (8 AM - 6 PM)

```bash
# Start weekdays at 8 AM
cron(0 8 ? * MON-FRI *)

# Stop weekdays at 6 PM
cron(0 18 ? * MON-FRI *)
```

### Weekends Only

```bash
# Start weekends at 10 AM
cron(0 10 ? * SAT,SUN *)

# Stop weekends at 11 PM
cron(0 23 ? * SAT,SUN *)
```

### Specific Times

```bash
# Every hour
cron(0 * * * ? *)

# Every 30 minutes
cron(0/30 * * * ? *)

# Twice daily (9 AM and 5 PM)
cron(0 9,17 * * ? *)
```

### Cost-Based Schedule

Stop during expensive hours:

```bash
# Stop during peak hours (8 AM - 6 PM weekdays)
# Start at 6 PM
cron(0 18 ? * MON-FRI *)

# Stop at 8 AM (reverse - cheaper at night)
cron(0 8 ? * MON-FRI *)
```

---

## Cron Syntax Reference

```
┌───────────── minute (0 - 59)
│ ┌───────────── hour (0 - 23)
│ │ ┌───────────── day of month (1 - 31)
│ │ │ ┌───────────── month (1 - 12)
│ │ │ │ ┌───────────── day of week (SUN - SAT)
│ │ │ │ │
* * * * ? *
```

### Examples

| Expression | Meaning |
|-----------|---------|
| `cron(0 2 * * ? *)` | Daily at 2:00 AM |
| `cron(0 8 ? * MON-FRI *)` | Weekdays at 8:00 AM |
| `cron(0 9 ? * * *)` | Daily at 9:00 AM |
| `cron(0 0 1 * ? *)` | First day of month at midnight |
| `cron(0/15 * * * ? *)` | Every 15 minutes |

---

## Cost Analysis: Is Automation Worth It?

### Manual vs Automated

| Scenario | Manual Control | Automated Schedule |
|----------|----------------|-------------------|
| **Effort** | Stop/start manually | Set once, forget |
| **Reliability** | Might forget | Always runs |
| **Cost** | Varies | Predictable |
| **Best For** | Irregular usage | Regular patterns |

### Example: Nightly Automation

**Setup:** Stop at 2 AM, start at 8 AM

**Hours Saved:** 6 hours/day = 180 hours/month

**Cost Savings:** 180 × $0.0208 = **$3.74/month**

**Effort:** ~10 minutes to set up → saves manual effort forever

**Conclusion:** ✅ Worth it for regular usage patterns

---

## Managing Rules

### List All Rules

```bash
aws events list-rules --name-prefix apy-server
```

### Disable a Rule

```bash
aws events disable-rule --name apy-server-stop-nightly
```

### Enable a Rule

```bash
aws events enable-rule --name apy-server-stop-nightly
```

### Delete a Rule

```bash
# Remove targets first
aws events remove-targets \
  --rule apy-server-stop-nightly \
  --ids "1"

# Then delete rule
aws events delete-rule --name apy-server-stop-nightly
```

---

## Advanced: Multi-Region Automation

If you have instances in multiple regions:

```bash
for REGION in us-east-1 eu-west-1 ap-southeast-1; do
  aws events put-rule \
    --name apy-server-stop-${REGION} \
    --schedule-expression "cron(0 2 * * ? *)" \
    --region ${REGION}
done
```

---

## Monitoring and Troubleshooting

### Check Rule Execution

```bash
# View CloudWatch Logs for EventBridge
aws logs describe-log-groups --log-group-name-prefix /aws/events
```

### Test Rule Immediately

```bash
# Trigger rule manually
aws events put-rule \
  --name apy-server-test \
  --schedule-expression "rate(5 minutes)"

# Run target immediately
aws events put-targets \
  --rule apy-server-test \
  --targets "Id"="1","Arn"="arn:aws:events:...","Ec2Parameters"="..."

# Check result
aws ec2 describe-instance-status --instance-ids i-xxx
```

---

## Best Practices

### 1. Use UTC Times

AWS schedules are in UTC. Convert your local time:

- **EST 2 AM** = UTC 7 AM (add 5 hours)
- **PST 8 AM** = UTC 4 PM (add 8 hours)

### 2. Test First

Create a test rule with short interval:

```bash
# Test every 5 minutes
schedule-expression "rate(5 minutes)"
```

### 3. Set Up Monitoring

```bash
# Create CloudWatch alarm for failed rules
aws cloudwatch put-metric-alarm \
  --alarm-name eventbridge-rule-failed \
  --alarm-description "Alert if rule fails" \
  --metric-name FailedInvocations \
  --namespace AWS/Events \
  --statistic Sum \
  --period 300 \
  --threshold 1 \
  --comparison-operator GreaterThanThreshold
```

### 4. Document Your Schedule

Keep a record of when rules fire:

```
apy-server-stop-nightly:  Daily at 2:00 AM UTC
apy-server-start-morning: Daily at 8:00 AM UTC
```

---

## Quick Reference Commands

```bash
# Get instance ID
terraform output instance_id

# Create stop rule (2 AM)
aws events put-rule --name apy-stop --schedule-expression "cron(0 2 * * ? *)" --state ENABLED

# Create start rule (8 AM)
aws events put-rule --name apy-start --schedule-expression "cron(0 8 * * ? *)" --state ENABLED

# List rules
aws events list-rules --name-prefix apy

# Check status
./start_stop.sh status
```

---

## Troubleshooting

### Rule Not Firing?

1. **Check rule state:**
   ```bash
   aws events describe-rule --name apy-server-stop-nightly
   ```
   Should show `State: ENABLED`

2. **Check targets:**
   ```bash
   aws events list-targets-by-rule --rule apy-server-stop-nightly
   ```

3. **Check instance state:**
   ```bash
   aws ec2 describe-instance-status --instance-ids i-xxx
   ```

### Wrong Time Zone?

All EventBridge schedules are in **UTC**. Convert your local time:

- **EST = UTC-5**
- **PST = UTC-8**
- **UTC = UTC+0**

Example: Stop at 10 PM EST = Stop at 3 AM UTC

---

## Cost of EventBridge

**Free:** EventBridge is FREE (no charges)

You only pay for:
- EC2 compute time (when running)
- EBS storage (always)

**Automation adds zero cost!**

