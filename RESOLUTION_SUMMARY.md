# Resolution Summary

## Your Questions Answered

### 1. Coupling Between New Repo and Extractor

**Current State:** ✅ **Tight coupling exists and is documented**

**Coupling Points:**
- Repository URL (hardcoded, can override)
- Directory structure assumptions
- Entry point detection (auto-detects now)
- Output location (configurable)

**Is It Acceptable?**
- ✅ For now: Yes (single use case, documented)
- ⚠️ For future: Could be looser

**Improvements Made:**
- ✅ Added environment variable support
- ✅ Created `config.env.example`
- ✅ Added multiple entry point detection
- ✅ Documented coupling in `README_COUPLING.md`
- ✅ Explained relationship in `ARCHITECTURE.md`

**Future Improvements:**
- Consider Docker approach
- Add config file support
- Generic job runner pattern

---

### 2. Script Artifacts Ready for Vortaro/Translator?

**Answer:** ❌ **NO - Different use cases**

| Project | Infrastructure | Can Use These Scripts? |
|---------|---------------|------------------------|
| **Extractor** | EC2 on-demand | ✅ Yes - Designed for this |
| **Translator** | Cloudflare + EC2 APy | ❌ No - Different EC2 setup |
| **Vortaro** | Static hosting | ❌ No - No backend needed |

**Why Different:**

**Translator:**
- Uses Cloudflare Workers for frontend
- Separate EC2 for APy server (always-on)
- Different deployment pipeline
- Already has its own infrastructure

**Vortaro:**
- Pure client-side JavaScript
- No backend infrastructure
- Runs locally or on static hosting
- No EC2 needed

**What Can Be Reused:**
- ✅ Cost optimization patterns (`COST_OPTIMIZATION.md`)
- ✅ Start/stop concepts (`start_stop.sh`)
- ✅ Monitoring approaches (`monitor_extractor.sh`)
- ❌ NOT the extractor-specific scripts

---

### 3. Monitor Script When EC2 Terminated

**Problem:** ✅ **FIXED**

**Before:**
```bash
./monitor_extractor.sh
# Crashed: "SSH failed"
```

**After:**
```bash
./monitor_extractor.sh
# Shows: "⚠ Instance stopped"
# Or: "❌ Instance terminated"
# Gracefully handles missing instance
```

**Changes Made:**
- ✅ Check instance state before SSH
- ✅ Handle stopped/terminated states
- ✅ Better error messages
- ✅ No crashes on terminated instances

**New Behavior:**
```bash
Instance Status: stopped
Extractor Process: ⚠ Instance stopped
Generated Files: Instance stopped - cannot check files
```

---

### 4. Document Updates

**Updated Documents:**

#### New Files Created:
1. ✅ `ARCHITECTURE.md` - Architecture analysis and coupling
2. ✅ `TROUBLESHOOTING.md` - Common issues and solutions
3. ✅ `README_COUPLING.md` - Coupling documentation
4. ✅ `config.env.example` - Configuration template
5. ✅ `RESOLUTION_SUMMARY.md` - This file

#### Files Modified:
1. ✅ `run_extractor.sh` - Added environment variables
2. ✅ `monitor_extractor.sh` - Fixed error handling
3. ✅ `.gitignore` - Added log files

#### Files Still to Update (Recommended):
1. ⏳ Main `README.md` - Add infrastructure section
2. ⏳ `projects/extractor/README.md` - Add EC2 on-demand info
3. ⏳ `projects/translator/README.md` - Clarify different EC2

---

## Summary

### ✅ What Was Done

1. **Created infrastructure:** EC2 + S3 for on-demand extractor runs
2. **Created repository:** https://github.com/komapc/apertium-dev-infrastructure
3. **Improved scripts:** Added configuration, better error handling
4. **Documented coupling:** Clear explanation of dependencies
5. **Fixed monitor:** Handles terminated instances gracefully
6. **Clarified relationships:** Documented why vortaro/translator are separate

### ⚠️ Extractor Run Status

**Failed due to:** Path configuration issue in extractor
- Downloaded dumps successfully
- Failed on parsing step
- Cost: ~$0.03 (still cost-effective)

**Next:** Need to fix extractor configuration, then retry

### 📝 Key Takeaways

1. **Coupling:** Exists, documented, configurable
2. **Reusability:** NOT suitable for vortaro/translator (different needs)
3. **Error Handling:** ✅ Fixed
4. **Documentation:** ✅ Complete

---

## Repository Links

- **Infrastructure:** https://github.com/komapc/apertium-dev-infrastructure
- **Extractor:** https://github.com/komapc/ido-esperanto-extractor
- **Translator:** https://github.com/komapc/ido-epo-translator

---

## Next Steps

1. ✅ Repository created and pushed
2. ⏳ Fix extractor configuration issue
3. ⏳ Retry extractor run
4. ⏳ Update main project README (optional)

