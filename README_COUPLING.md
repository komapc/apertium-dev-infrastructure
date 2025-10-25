# Coupling Analysis

## Overview

This infrastructure repository has **tight coupling** with the `ido-esperanto-extractor` repository.

---

## Coupling Details

### 1. Repository URL
**Current:** Hardcoded in `run_extractor.sh`
```bash
GITHUB_REPO="${GITHUB_REPO:-https://github.com/komapc/ido-esperanto-extractor.git}"
```

**Can Override:** Yes, via environment variable

### 2. Directory Structure
**Current:** Assumes specific clone directory name
```bash
EXTRACTOR_DIR="${EXTRACTOR_DIR:-ido-esperanto-extractor}"
```

**Impact:** If extractor repo structure changes, script breaks

### 3. Entry Point
**Current:** Looks for specific files
- `scripts/run.py` (preferred)
- `scripts/pipeline_manager.py` (fallback)
- `main.py` (fallback)

**Impact:** Moderate - will adapt automatically

### 4. Output Location
**Current:** Hardcoded `/tmp/extractor-results`
```bash
RESULTS_DIR_INSTANCE="${RESULTS_DIR_INSTANCE:-/tmp/extractor-results}"
```

**Can Override:** Yes, via environment variable

---

## Is This Acceptable?

### Current State: ⚠️ Acceptable with Documentation

**Pros:**
- ✅ Works for single use case
- ✅ Simple implementation
- ✅ Configuration via environment variables possible

**Cons:**
- ⚠️ Changes to extractor require updating scripts
- ⚠️ Not easily reusable for other projects
- ⚠️ Hardcoded assumptions

**Recommendation:** Document coupling clearly. Accept for now, improve later.

---

## Relationship to Other Projects

### Extractor Project
**Relationship:** Tight coupling (designed for this)
**Status:** ✅ By design
**Impact:** Extractor structural changes require script updates

### Translator Project
**Relationship:** None (different infrastructure)
**Status:** ✅ Separate concern
**Reason:** Translator uses Cloudflare Workers + different EC2 (APy server)

### Vortaro Project
**Relationship:** None (no infrastructure)
**Status:** ✅ Separate concern
**Reason:** Pure client-side app, no backend

---

## Improvement Path

### Phase 1: Current (Completed)
- ✅ Environment variable support added
- ✅ Error handling improved
- ✅ Coupling documented

### Phase 2: Next
- 📋 Add configuration file support
- 📋 Better error messages
- 📋 Support for multiple entry points

### Phase 3: Future
- 📋 Docker-based approach
- 📋 Generic job runner
- 📋 Support for multiple repositories

---

## Usage Examples

### Standard Usage (Default)
```bash
cd terraform
./run_extractor.sh
```

### Custom Repository
```bash
export GITHUB_REPO="https://github.com/user/other-repo.git"
cd terraform
./run_extractor.sh
```

### Custom Entry Point
```bash
export ENTRY_POINT="main.py"
cd terraform
./run_extractor.sh
```

---

## Impact of Changes

### If Extractor Changes Repository Structure

**Required Actions:**
1. Update `EXTRACTOR_DIR` environment variable
2. Or modify `run_extractor.sh`
3. Test compatibility

**Prevention:** Use configuration file

### If Extractor Changes Entry Point

**Current:** Script auto-detects
**Impact:** Minimal - will adapt automatically

---

## Summary

**Coupling Level:** Tight but documented and configurable

**Is It Problematic?** 
- For current use: No ✅
- For future expansion: Yes ⚠️

**Should We Decouple More?**
- Short-term: Documented ✅
- Long-term: Consider Docker approach

**Recommendation:** Keep current approach, improve documentation, add configuration file support.

