# Troubleshooting Guide

## Common Issues

### 1. Monitor Script Fails When Instance Terminated

**Problem:** `monitor_extractor.sh` crashes when instance doesn't exist.

**Current Behavior:**
```bash
./monitor_extractor.sh
# Crashes with: "SSH failed" or similar
```

**Solution:** Add proper error handling:

```bash
# In monitor_extractor.sh
if [ "$PUBLIC_IP" != "not-found" ]; then
    ssh -i ~/.ssh/id_rsa -o ConnectTimeout=2 ubuntu@$PUBLIC_IP \
        "ps aux | grep 'python3 run.py' | grep -v grep || echo 'Not running'" 2>/dev/null || {
        echo "⚠ Instance may be stopped or SSH unavailable"
    }
else
    echo "Instance not available"
fi
```

---

### 2. Extractor Run Scripts Artifacts Ready?

**Question:** Are these scripts ready to deploy to vortaro/translator?

**Answer:** **NO** - Different use cases:

| Project | Infrastructure | Purpose |
|---------|---------------|---------|
| **Extractor** | EC2 on-demand | Batch extraction runs |
| **Translator** | Cloudflare + EC2 APy | Translation API |
| **Vortaro** | Static hosting | Dictionary viewer |

**What Can Be Reused:**
- ✅ `start_stop.sh` - General instance management
- ✅ Monitoring concepts
- ✅ Cost optimization patterns

**What Cannot Be Reused:**
- ❌ `run_extractor.sh` - Too specific to extractor
- ❌ Git clone approach - Not relevant for APy server
- ❌ Extractor-specific paths

**For Translator:**
- Already has EC2 setup for APy server
- Uses different deployment (Cloudflare Workers)
- Different automation needs

**For Vortaro:**
- No backend infrastructure needed
- Pure client-side app
- Uses static hosting

---

### 3. Coupling Explained

**Current Coupling:**

```
apertium-terraform
    ↓ (hardcoded dependency)
ido-esperanto-extractor
    ↓ (GitHub URL, directory structure, entry point)
```

**Why It Exists:**
- Simplifies initial implementation
- Works for current use case
- Can be improved with configuration

**Is It Acceptable?**
- ✅ For now: Yes (single use case)
- ⚠️ For future: No (needs decoupling)

**Impact:**
- Changes to extractor structure require updating terraform scripts
- Cannot easily adapt for other projects
- Maintainability concerns

---

### 4. Document Updates Needed

**Files to Update:**

1. **Main README.md**
   - Add infrastructure section
   - Link to terraform repository
   - Document different infrastructures

2. **projects/extractor/README.md**
   - Add EC2 on-demand section
   - Link to infrastructure repo
   - Document relationship

3. **terraform/README.md**
   - Document coupling explicitly
   - Add troubleshooting section
   - Clarify use cases

4. **projects/translator/DOCUMENTATION_INDEX.md**
   - Clarify different EC2 setups
   - Document infrastructure separation

---

## Specific Fixes Needed

### Fix 1: Monitor Script Error Handling

**Current:**
```bash
ssh -i ~/.ssh/id_rsa ubuntu@$PUBLIC_IP "ps aux" || echo "SSH failed"
```

**Better:**
```bash
if ssh -i ~/.ssh/id_rsa -o ConnectTimeout=2 ubuntu@$PUBLIC_IP "ps aux" 2>/dev/null; then
    # Success
else
    echo "⚠ Instance stopped or SSH unavailable"
fi
```

### Fix 2: Make Configuration Flexible

**Add config file support:**

```bash
# Create config.env.template
GITHUB_REPO=https://github.com/komapc/ido-esperanto-extractor.git
EXTRACTOR_DIR=ido-esperanto-extractor
ENTRY_POINT=scripts/run.py
RESULTS_DIR=/tmp/extractor-results
```

### Fix 3: Add Better Logging

**Current:** Limited error messages  
**Better:** More context, retry logic, detailed failures

---

## Action Items

### Immediate (Before Next Run)

- [ ] Add environment variable support to `run_extractor.sh`
- [ ] Fix monitor script error handling
- [ ] Add configuration file template
- [ ] Document coupling explicitly

### Short-term

- [ ] Update main README.md
- [ ] Update extractor documentation
- [ ] Add troubleshooting examples
- [ ] Create architecture diagram

### Long-term

- [ ] Consider Docker approach
- [ ] Support multiple projects
- [ ] Add CI/CD integration
- [ ] Create test harness

