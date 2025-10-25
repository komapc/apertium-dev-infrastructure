# Infrastructure Architecture

## Current Setup

### Repository Created
**`apertium-dev-infrastructure`** - AWS EC2 on-demand infrastructure for running extractor

**URL:** https://github.com/komapc/apertium-dev-infrastructure

---

## Coupling Analysis

### 1. Current Coupling Issues

#### Tight Coupling with Extractor Repository

**Problem:** `run_extractor.sh` makes assumptions about:
- Repository URL: `https://github.com/komapc/ido-esperanto-extractor.git`
- Directory structure: `scripts/run.py` or `scripts/pipeline_manager.py`
- Entry point: `python3 run.py`
- Output location: `/tmp/extractor-results`

**Impact:**
- ⚠️ Changes to extractor structure break this script
- ⚠️ Can't easily adapt for other projects
- ⚠️ Hardcoded paths

**Example of coupling:**
```bash
# In run_extractor.sh
cd /tmp/ido-esperanto-extractor
cd scripts
python3 run.py  # Hardcoded assumption
```

---

## Proposed Improvements

### Improvement 1: Make Extractor Configurable

**Add environment variables for flexibility:**

```bash
# In run_extractor.sh
GITHUB_REPO="${GITHUB_REPO:-https://github.com/komapc/ido-esperanto-extractor.git}"
EXTRACTOR_DIR="${EXTRACTOR_DIR:-ido-esperanto-extractor}"
ENTRY_POINT="${ENTRY_POINT:-scripts/run.py}"
```

**Benefits:**
- ✅ Can reuse for other repositories
- ✅ Easy to test with different configurations
- ✅ More flexible deployment

---

### Improvement 2: Support Different Entry Points

**Add detection logic:**

```bash
# Detect entry point automatically
if [ -f "scripts/run.py" ]; then
    ENTRY_POINT="scripts/run.py"
elif [ -f "main.py" ]; then
    ENTRY_POINT="main.py"
elif [ -f "scripts/pipeline_manager.py" ]; then
    ENTRY_POINT="scripts/pipeline_manager.py"
fi
```

---

### Improvement 3: Make Output Location Configurable

```bash
RESULTS_DIR="${RESULTS_DIR:-/tmp/extractor-results}"
# Use it consistently throughout script
```

---

## Relationship to Other Projects

### Extractor (ido-esperanto-extractor)
**Current:** ✅ Uses this infrastructure  
**Coupling:** Tight (hardcoded paths)  
**Should:** Loosen coupling with environment variables

### Translator (ido-epo-translator)
**Current:** ❌ Does NOT use this infrastructure  
**Uses:** Cloudflare Workers + separate EC2 (APy server)  
**Coupling:** None (different use case)

**Why Different:**
- Translator needs **always-on** APy server (translation API)
- Extractor runs **on-demand** for batch processing
- Different infrastructure needs

### Vortaro (Dictionary Viewer)
**Current:** ❌ Does NOT use this infrastructure  
**Uses:** Static hosting (no backend)  
**Coupling:** None (client-side only)

---

## Infrastructure Summary

| Project | Infrastructure | Purpose | Status |
|---------|---------------|---------|--------|
| **Extractor** | EC2 on-demand (this repo) | Run batch extraction | ✅ Configured |
| **Translator** | Cloudflare Workers + EC2 APy | Serve translation API | ⚠️ Different EC2 |
| **Vortaro** | Static hosting | View dictionary | ✅ No backend |

---

## Recommendations

### For This Repository (apertium-dev-infrastructure)

**Short-term improvements:**
1. ✅ Add environment variables for configuration
2. ✅ Improve error handling in monitor script
3. ✅ Document coupling and dependencies
4. ✅ Add support for multiple entry points

**Long-term improvements:**
1. Consider Docker approach for even more flexibility
2. Add support for other projects (e.g., batch jobs)
3. Implement shared infrastructure module
4. Add CI/CD integration

### For Other Projects

**Translator:**
- Has its own EC2 setup (APy server)
- Uses Cloudflare Workers for frontend
- No need to share infrastructure

**Vortaro:**
- Pure client-side
- No infrastructure needed

---

## Current State Assessment

### What's Good ✅
- Infrastructure works
- Instance management scripted
- S3 backup configured
- Cost-optimized (on-demand)

### What Needs Work ⚠️
- Tight coupling with extractor
- Hardcoded paths
- Limited error handling
- No configuration flexibility

### What's Missing ❌
- Environment variable support
- Multiple project support
- Better documentation of coupling
- Test harness

---

## Decoupling Strategy

### Phase 1: Make Configurable (Immediate)
```bash
# Add to run_extractor.sh
export GITHUB_REPO="${GITHUB_REPO:-https://github.com/komapc/ido-esperanto-extractor.git}"
export EXTRACTOR_DIR="${EXTRACTOR_DIR:-ido-esperanto-extractor}"
export ENTRY_POINT="${ENTRY_POINT:-scripts/run.py}"
export RESULTS_DIR="${RESULTS_DIR:-/tmp/extractor-results}"
```

### Phase 2: Support Multiple Projects (Future)
```bash
# Add config file support
cat > config.env <<EOF
GITHUB_REPO=https://github.com/komapc/ido-esperanto-extractor.git
ENTRY_POINT=scripts/run.py
RESULTS_DIR=/tmp/results
EOF

source config.env
```

### Phase 3: Abstract to Generic Job Runner (Future)
```bash
# Support any GitHub repo + entry point
./run_job.sh --repo USER/REPO --entry-point scripts/main.py
```

---

## Summary

**Current State:**
- Coupling exists and is acceptable for current use case
- Documented and can be improved

**Recommended Action:**
- Add environment variable support
- Improve error handling
- Document coupling clearly
- Keep separate from translator/vortaro (different needs)

