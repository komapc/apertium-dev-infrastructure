# Extractor Script Improvements

## Problem

The original `run_extractor.sh` had issues with long-running SSH sessions:
- SSH connection would hang/timeout during long operations
- No way to monitor progress without SSH staying connected
- Difficult to recover from network interruptions

## Solution: `run_extractor_improved.sh`

### Key Improvements

#### 1. Background Execution on EC2
```bash
# Starts extraction in background on EC2
nohup python3 scripts/run.py > /tmp/extraction.log 2>&1 &
```
- Extraction runs independently on EC2
- Not dependent on local SSH connection staying alive
- Can disconnect and reconnect without interrupting

#### 2. Polling Instead of Blocking
```bash
# Polls every 30 seconds to check status
while process_running; do
    show_progress
    sleep 30
done
```
- Local script polls EC2 for status
- Shows progress updates every 30 seconds
- Can handle network interruptions

#### 3. Better Error Handling
- Checks if process is still running
- Detects errors in log output
- Provides clear error messages
- Suggests recovery commands

#### 4. Timeout Protection
- Maximum wait time: 2 hours
- Warns if exceeded but doesn't kill process
- Process continues running on EC2

#### 5. Instance Stays Running
- Never stops instance automatically
- Consistent with your requirement
- Manual stop: `./start_stop.sh stop`

## Usage

### Basic Usage
```bash
cd ~/apertium-dev/terraform
./run_extractor_improved.sh
```

### What It Does
1. ✅ Starts instance (if stopped)
2. ✅ Waits for SSH to be ready
3. ✅ Sets up extractor code
4. ✅ Starts extraction in background on EC2
5. ✅ Polls for completion every 30 seconds
6. ✅ Shows progress updates
7. ✅ Copies results when complete
8. ✅ Leaves instance running

### Monitor Manually
While it runs, you can also monitor directly:
```bash
ssh extractor 'tail -f /tmp/extraction_*.log'
```

### If Script Interrupted
If your local script is interrupted, the extraction continues on EC2:
```bash
# Check if still running
ssh extractor 'ps aux | grep "python3 scripts/run.py"'

# Monitor progress
ssh extractor 'tail -f /tmp/extraction_*.log'

# Copy results when done
scp -r extractor:/tmp/ido-esperanto-extractor/dist/* extractor-results/manual/
```

## Comparison

| Feature | Original | Improved |
|---------|----------|----------|
| **SSH Connection** | Blocking | Non-blocking |
| **Network Issues** | Fails | Resilient |
| **Progress Updates** | None | Every 30s |
| **Timeout Handling** | Hangs | Detects & warns |
| **Recovery** | Difficult | Easy |
| **Instance Control** | Stops | Stays running |

## Technical Details

### Background Execution
```bash
# On EC2
nohup python3 scripts/run.py > /tmp/extraction.log 2>&1 &
echo $! > /tmp/extraction.pid
```
- `nohup`: Continues after SSH disconnect
- `&`: Runs in background
- PID saved for monitoring

### Polling Loop
```bash
while [ $ELAPSED -lt $MAX_WAIT ]; do
    # Check if process still running
    ps -p $(cat /tmp/extraction.pid)
    
    # Show progress
    tail -1 /tmp/extraction.log
    
    sleep 30
done
```
- Checks every 30 seconds
- Shows last log line
- Exits when process completes

### Error Detection
```bash
# Check for errors in log
tail -100 /tmp/extraction.log | grep -q 'Error\|Failed'
```
- Scans log for error keywords
- Reports failure if found
- Provides log location for debugging

## Migration Path

### Option 1: Replace Original
```bash
cd ~/apertium-dev/terraform
mv run_extractor.sh run_extractor_old.sh
mv run_extractor_improved.sh run_extractor.sh
```

### Option 2: Use Both
```bash
# Use improved for long runs
./run_extractor_improved.sh

# Use original for quick tests
./run_extractor_old.sh
```

### Option 3: Test First
```bash
# Test improved version
./run_extractor_improved.sh

# If works well, replace original
```

## Troubleshooting

### Script Says "Extraction Failed"
```bash
# Check logs on EC2
ssh extractor 'tail -100 /tmp/extraction_*.log'

# Check if process still running
ssh extractor 'ps aux | grep python3'
```

### Timeout Exceeded
```bash
# Process may still be running
ssh extractor 'ps aux | grep "python3 scripts/run.py"'

# Monitor progress
ssh extractor 'tail -f /tmp/extraction_*.log'

# Wait for completion, then copy results manually
```

### Network Interruption
```bash
# Script can be restarted
./run_extractor_improved.sh

# It will detect existing process and monitor it
```

## Future Enhancements

Possible improvements:
1. **Resume capability** - Detect and resume existing runs
2. **Progress percentage** - Parse log for completion %
3. **Email notifications** - Alert when complete
4. **Slack/Discord webhooks** - Real-time updates
5. **Web dashboard** - Monitor via browser

## Recommendation

Use `run_extractor_improved.sh` for:
- ✅ Production runs
- ✅ Long extractions (>30 min)
- ✅ Unreliable networks
- ✅ When you need to disconnect

Use original `run_extractor.sh` for:
- Quick tests
- When you want to watch output in real-time
- Debugging

## Summary

The improved script solves the SSH timeout issue by:
1. Running extraction in background on EC2
2. Polling for status instead of blocking
3. Handling network interruptions gracefully
4. Providing clear progress updates
5. Making recovery easy

**Result:** Reliable, resilient extraction that works even with network issues! ✅
