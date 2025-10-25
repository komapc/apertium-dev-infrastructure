# AWS EC2 Instance Type Comparison

## Instance Type Options

### T3 Family (General Purpose Burstable)

| Instance Type | vCPU | RAM | Cost/Hour | Cost/Month (24/7) | Use Case |
|--------------|------|-----|-----------|-------------------|----------|
| **t3.nano** | 2 | 0.5GB | $0.0052 | **$3.80** | ❌ Too small - won't work |
| **t3.micro** | 2 | 1GB | $0.0104 | **$7.60** | ⚠️ Marginal - may not work |
| **t3.small** | 2 | 2GB | $0.0208 | **$15.20** | ✅ Recommended |
| **t3.medium** | 2 | 4GB | $0.0416 | **$30.40** | ✅ Overkill for most use |

### Cost Comparison (Always On)

| Instance | Monthly Cost | Savings vs t3.small |
|---------|--------------|---------------------|
| t3.nano | $3.80 | -76% |
| t3.micro | $7.60 | -50% |
| t3.small | $15.20 | Baseline |
| t3.medium | $30.40 | +100% |

### Cost Comparison (10 hours/month)

| Instance | Monthly Cost | Savings vs t3.small |
|---------|--------------|---------------------|
| t3.nano | $2.05 | -7% |
| t3.micro | $2.10 | -5% |
| t3.small | $2.21 | Baseline |
| t3.medium | $2.42 | +9% |

**Note:** When using only 10 hours/month, the cost difference is minimal (~$0.10-$0.30/month).

---

## Can You Use t3.micro? (1GB RAM)

### Analysis

**Apertium APy Server Requirements:**
- Apertium binaries: ~100-200MB
- Dictionary files: ~50-100MB
- System overhead: ~200-300MB
- Docker: ~100-200MB
- **Total Minimum:** ~450-800MB

**t3.micro has 1GB RAM:**
- ✅ **Marginal** - Might work for small dictionaries
- ⚠️ **Risk:** Out of memory errors under load
- ⚠️ **Risk:** Slow swapping to disk
- ❌ **Not recommended** for production

### Testing Recommendation

If you want to try t3.micro:

```bash
# Temporarily change instance type
cd terraform
# Edit terraform.tfvars
instance_type = "t3.micro"

# Apply
terraform apply -replace=aws_instance.apy_server

# Test
ssh ubuntu@<IP>
docker stats  # Monitor memory usage
curl http://localhost:2737/listPairs  # Test APy
```

**If memory errors occur**, upgrade to t3.small immediately.

---

## What About OnDemand vs Reserved vs Spot?

### Instance Pricing Models

#### 1. OnDemand (Current Setup)
- **What:** Pay-as-you-go, hourly
- **Price:** Full price ($0.0208/hour for t3.small)
- **Advantage:** Flexible, no commitment
- **Disadvantage:** Most expensive
- **Best For:** Variable workloads, short-term

**This is what we're using!**

#### 2. Reserved Instances
- **What:** 1-3 year commitment
- **Price:** 40-60% discount (e.g., $0.0125/hour = $9/month)
- **Advantage:** Significant savings
- **Disadvantage:** Must commit for 1-3 years
- **Best For:** Predictable long-term usage

**Example Savings:**
- OnDemand: $15.20/month
- Reserved 1-year: $9.13/month
- **Savings: $6.07/month ($73/year)**

#### 3. Spot Instances
- **What:** Bid on unused capacity
- **Price:** Up to 90% discount ($0.002-0.004/hour)
- **Advantage:** Massive savings
- **Disadvantage:** AWS can terminate with 2-minute warning
- **Best For:** Batch jobs, not production services

**❌ Not suitable for APy server** - AWS will kill your instance!

---

## Recommendation Matrix

### For Different Use Cases

| Use Case | Instance Type | Pricing Model | Cost/Month (24/7) |
|----------|---------------|---------------|-------------------|
| **Production** | t3.small | OnDemand | $15.20 |
| **Production (Long-term)** | t3.small | Reserved 1yr | $9.13 |
| **Development** | t3.micro | OnDemand | $7.60 |
| **Testing** | t3.micro | OnDemand | $7.60 |
| **10 hrs/month** | Any | OnDemand | ~$2 |

### For 10 Hours/Month Usage

**Recommendation:** Stick with **t3.small + OnDemand**

**Why?**
- Cost difference is minimal ($0.10-0.30/month)
- Better reliability
- Room to grow
- No risk of OOM errors

**Actual Savings with t3.micro:** $0.11/month

Is $0.11/month worth the risk? Probably not!

---

## How to Change Instance Type

### Option 1: Update Terraform Config

```bash
cd terraform

# Edit terraform.tfvars
instance_type = "t3.micro"  # Change from t3.small

# Apply changes
terraform apply
```

### Option 2: Update Existing Instance

```bash
# Edit terraform.tfvars
instance_type = "t3.micro"

# Apply with replace
terraform apply -replace=aws_instance.apy_server
```

**Note:** Changing instance type requires stopping the instance.

---

## Detailed Cost Breakdown

### Scenario: 10 Hours/Month

| Item | t3.nano | t3.micro | t3.small | t3.medium |
|------|---------|----------|----------|------------|
| Compute (10h) | $0.05 | $0.10 | $0.21 | $0.42 |
| Storage (20GB) | $2.00 | $2.00 | $2.00 | $2.00 |
| **Total** | **$2.05** | **$2.10** | **$2.21** | **$2.42** |

**Difference:** Only $0.16/month between cheapest and recommended!

### Scenario: Always On (730 hours/month)

| Item | t3.nano | t3.micro | t3.small | t3.medium |
|------|---------|----------|----------|------------|
| Compute (730h) | $3.80 | $7.60 | $15.20 | $30.40 |
| Storage (20GB) | $2.00 | $2.00 | $2.00 | $2.00 |
| **Total** | **$5.80** | **$9.60** | **$17.20** | **$32.40** |

**Difference:** $7.60/month between t3.micro and t3.small (significant!)

---

## Memory Requirements Analysis

### APy Server Components

```
System (Ubuntu):            ~200MB
Docker:                     ~100MB
Nginx:                      ~20MB
Apertium binaries:          ~100MB
Python runtime:             ~50MB
─────────────────────────────────────
Subtotal:                   ~470MB
Safety margin (30%):        ~150MB
─────────────────────────────────────
Total:                      ~620MB
```

### Dictionary Sizes

| Dictionary | Size | Notes |
|-----------|------|-------|
| ido-epo.automorf.bin | 67KB | Small |
| ido-epo.autobil.bin | 112KB | Small |
| ido-epo.autogen.bin | 1.2MB | Small |
| Large dictionaries | 10-50MB | If expanded |

**Memory needed:** ~700MB minimum

### Conclusion

- **t3.nano (512MB):** ❌ Won't work
- **t3.micro (1GB):** ⚠️ Risky, might work
- **t3.small (2GB):** ✅ Recommended
- **t3.medium (4GB):** ✅ Overkill

---

## Migration Guide

### Current Setup: t3.small

**To downgrade to t3.micro:**

```bash
cd terraform

# 1. Stop instance
./start_stop.sh stop

# 2. Update config
sed -i 's/t3.small/t3.micro/' terraform.tfvars

# 3. Apply
terraform apply

# 4. Test thoroughly
ssh ubuntu@<IP>
docker stats  # Watch memory
```

**To upgrade back:**

```bash
# Same process, reverse
sed -i 's/t3.micro/t3.small/' terraform.tfvars
terraform apply
```

---

## Summary

### For 10 Hours/Month Usage

**Recommendation:** **t3.small** (keep current)

**Reason:** Savings with t3.micro is only $0.11/month, not worth the risk.

### For Always-On Usage

**Option 1:** t3.micro + OnDemand = $9.60/month (risky)
**Option 2:** t3.small + Reserved 1yr = $9.13/month (recommended)
**Option 3:** t3.small + OnDemand = $17.20/month (current)

**Best Value:** Reserved 1-year t3.small = $9.13/month

### Bottom Line

- **OnDemand** = What you're using now (flexible, full price)
- **Reserved** = 40% savings if committed for 1 year
- **Spot** = Not suitable for production services
- **Smaller instance** = Minimal savings for part-time usage

**For your use case (10 hours/month), instance size doesn't matter much!**

