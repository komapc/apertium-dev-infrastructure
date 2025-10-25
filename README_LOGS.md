# Monitoring Extractor Progress

## Quick Commands

### Check Latest Log (RECOMMENDED)
```bash
cd terraform
tail -20 $(ls -t extractor-run-*.log | head -1)
```

### Watch Logs Live
```bash
cd terraform
tail -f $(ls -t extractor-run-*.log | head -1)
```

### Use Monitor Script (EASIEST)
```bash
cd terraform
./monitor_extractor.sh
```

## Why `tail -20 extractor-run-*.log` Doesn't Work

When you use a glob pattern with `tail`, it processes **all matching files**, not just the latest one. 

**Wrong:**
```bash
tail -20 extractor-run-*.log  # Shows last 20 lines from ALL log files mixed together
```

**Correct:**
```bash
tail -20 $(ls -t extractor-run-*.log | head -1)  # Shows last 20 lines from latest file only
```

## Alternative Commands

### See all log files
```bash
cd terraform
ls -lh extractor-run-*.log
```

### Check specific log file
```bash
cd terraform
tail -20 extractor-run-20251025-182612.log
```

### Search for specific content
```bash
cd terraform
grep -i "error\|failed" extractor-run-*.log
```

### Count lines in latest log
```bash
cd terraform
wc -l $(ls -t extractor-run-*.log | head -1)
```

## Monitor Script Features

The `monitor_extractor.sh` script provides:
- ✅ Instance status (running/stopped)
- ✅ Process status (is extractor running?)
- ✅ Recent log output (filtered for key events)
- ✅ File generation progress
- ✅ Error detection
- ✅ Time elapsed

## Example Output

```
======================================
Extractor Progress Monitor
======================================

Instance Status:
running

Extractor Process:
python3 run.py

Recent Log Output:
Downloading... 99% complete

Generated Files:
JSON files created: 5
dictionary_merged.json (2.5M)

Time Elapsed: 45m 32s
```

