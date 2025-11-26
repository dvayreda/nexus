# FactsMind n8n Pipeline Troubleshooting Guide

## Overview
The FactsMind content generation pipeline in n8n orchestrates:
1. **narrator.py** - Generates carousel scripts using Gemini API
2. **composite.py** - Renders carousel images  
3. **generate_and_post.py** - Orchestrates the full pipeline

This guide helps diagnose issues when the n8n flow produces "Unknown error" or "0 slides".

---

## Quick Diagnosis Checklist

### Step 1: Check n8n Output
When n8n flow fails, look for the error message:
```
error
  Command failed: python3 /data/scripts/generate_and_post.py
  [... logs ...]
  ✓ Carousel generated: 0 slides
  2025-11-26 15:31:44 | ERROR | Unknown error
```

**Key sign**: "Carousel generated: 0 slides" means narrator.py ran but returned an empty response.

### Step 2: Run Debug Script on Nexus
SSH into the Pi and run the debug helper:
```bash
# SSH into Nexus (adjust IP as needed)
ssh pi@192.168.1.145

# Run the debug script
docker exec factsmind-renderer python3 /data/scripts/debug_pipeline.py "science"
```

This will show you exactly where the pipeline breaks.

### Step 3: Check Environment Variables
The most common issue is **GEMINI_API_KEY not set** in the n8n Docker container.

```bash
# SSH into Nexus
ssh pi@192.168.1.145

# Check what's actually set inside the container
docker exec factsmind-renderer env | grep -i gemini
```

If empty, you need to add it to the n8n environment.

---

## Common Issues & Solutions

### Issue 1: "Carousel generated: 0 slides"

**Cause**: narrator.py returns empty JSON or fails silently

**Debug**:
```bash
docker exec factsmind-renderer python3 /data/scripts/narrator.py "biology" --script-only
```

If this fails or returns `{}`, check:

#### A) Missing GEMINI_API_KEY
```bash
docker exec factsmind-renderer env | grep GEMINI
```

**Fix**: Add to n8n container environment
1. Go to n8n workflow
2. Check the **Execute Command** node
3. Ensure environment variables are passed:
   ```json
   {
     "env": {
       "GEMINI_API_KEY": "your-key-here"
     }
   }
   ```

#### B) Missing YAML Prompt Files
```bash
docker exec factsmind-renderer ls -la /data/scripts/prompts/
```

Must have:
- `brand_voice.yaml`
- `screenplay.yaml`
- `visual.yaml`

**Fix**: Ensure these files are mounted/copied into the container

#### C) Wrong Working Directory
narrator.py needs to find prompt files relative to the scripts directory.

**Debug**:
```bash
docker exec factsmind-renderer python3 -c "
import os
from pathlib import Path
script_dir = Path('/data/scripts')
prompt_file = script_dir / 'prompts' / 'brand_voice.yaml'
print(f'Prompt file exists: {prompt_file.exists()}')
print(f'Script dir contents: {list(script_dir.iterdir())}')
"
```

### Issue 2: "narrator.py failed: ImportError"

**Cause**: Missing Python dependencies in Docker container

**Debug**:
```bash
docker exec factsmind-renderer python3 -c "
try:
    import google.generativeai
    print('✓ google.generativeai')
except ImportError as e:
    print(f'✗ google.generativeai: {e}')

try:
    import yaml
    print('✓ yaml')
except ImportError as e:
    print(f'✗ yaml: {e}')

try:
    from PIL import Image
    print('✓ PIL')
except ImportError as e:
    print(f'✗ PIL: {e}')
"
```

**Fix**: Install missing packages in container Dockerfile:
```dockerfile
RUN pip install google-generativeai pyyaml pillow python-dotenv
```

### Issue 3: "narrator.py timed out (5+ minutes)"

**Cause**: Gemini API is slow or network issues

**Solutions**:
1. Increase timeout in `generate_and_post.py` line 130 (currently 300 seconds)
2. Check if Gemini API quota is exhausted
3. Check network connectivity: 
   ```bash
   docker exec factsmind-renderer ping -c 3 api.generativeai.google.com
   ```

### Issue 4: "No JSON object found in narrator.py output"

**Cause**: narrator.py is printing error messages before the JSON

**Debug**:
```bash
docker exec factsmind-renderer python3 /data/scripts/narrator.py "test" --script-only 2>&1 | head -100
```

Look for error messages like:
- `WARNING: module X not found`
- `Error: GEMINI_API_KEY not set`

**Fix**: Resolve the underlying error (usually environment variable or import issue)

---

## Full Diagnostic Flow

Run this on Nexus to get complete diagnostics:

```bash
# 1. Enter the container
docker exec -it factsmind-renderer bash

# 2. Check environment
echo "=== Environment ===" 
env | grep -E "(GEMINI|DATA|HOME|PATH)" | head -20

# 3. Check file structure
echo -e "\n=== File Structure ===" 
ls -la /data/scripts/*.py | head -10
ls -la /data/scripts/prompts/

# 4. Check Python dependencies
echo -e "\n=== Python Imports ===" 
python3 -c "
import sys
for mod in ['google.generativeai', 'yaml', 'PIL', 'pathlib']:
    try:
        __import__(mod)
        print(f'✓ {mod}')
    except Exception as e:
        print(f'✗ {mod}: {e}')
"

# 5. Test narrator.py
echo -e "\n=== Narrator Test ===" 
cd /data/factsmind
python3 /data/scripts/narrator.py "science" --script-only --hook-style statement 2>&1 | tail -50

# 6. Test full pipeline
echo -e "\n=== Full Pipeline Test ===" 
python3 /data/scripts/generate_and_post.py --topic "biology" --dry-run
```

---

## Docker Container Information

The FactsMind renderer runs in: **factsmind-renderer** Docker container

Check if it's running:
```bash
docker ps | grep factsmind-renderer
```

View logs:
```bash
docker logs -f factsmind-renderer
```

Restart container:
```bash
docker restart factsmind-renderer
```

---

## Environment Variable Setup

Required in n8n or Docker compose:

```bash
# Gemini API key (REQUIRED)
GEMINI_API_KEY=<your-key>

# Instagram (optional, for posting)
INSTAGRAM_ACCESS_TOKEN=<token>

# Paths (usually automatic)
DATA_DIR=/data
FACTSMIND_ROOT=/data/factsmind
```

### Where to Set Variables

**Option A: In n8n Execute Command Node**
```json
{
  "environmentVariables": {
    "GEMINI_API_KEY": "{{ $env['GEMINI_API_KEY'] }}"
  }
}
```

**Option B: In Docker Compose**
```yaml
services:
  n8n:
    environment:
      - GEMINI_API_KEY=your-key
  
  factsmind-renderer:
    environment:
      - GEMINI_API_KEY=your-key
```

**Option C: In .env file**
```bash
GEMINI_API_KEY=your-key
```
Then load in container startup

---

## Manual Testing

Test each component manually:

### Test 1: Narrator Script Only
```bash
docker exec factsmind-renderer python3 /data/scripts/narrator.py "biology" --script-only
# Should output JSON with 6 slides
```

### Test 2: Full Pipeline (dry run)
```bash
docker exec factsmind-renderer python3 /data/scripts/generate_and_post.py --dry-run
# Should complete without errors
```

### Test 3: Validate Setup
```bash
docker exec factsmind-renderer python3 /data/scripts/validate_setup.py
# Should show all checks passing
```

### Test 4: Debug Output
```bash
docker exec factsmind-renderer python3 /data/scripts/debug_pipeline.py "science"
# Shows detailed debug logs of every step
```

---

## Logs & Output Files

Check where output files are being saved:

```bash
# On the Pi
ls -la /data/outputs/
ls -la /data/outputs/final/

# Check file sizes and timestamps
find /data/outputs -type f -mmin -10  # Last 10 minutes
```

---

## Common Solutions Quick Reference

| Error | Solution |
|-------|----------|
| 0 slides | Run debug script, check GEMINI_API_KEY |
| ImportError | Install dependencies in Dockerfile |
| Timeout | Increase timeout or check network |
| No JSON found | Check narrator.py stderr for errors |
| "Unknown error" at end | Check error logs for actual failure |
| File not found | Verify /data/scripts mounts correctly |

---

## Getting Help

If issues persist:

1. Capture full error output:
   ```bash
   docker exec factsmind-renderer python3 /data/scripts/debug_pipeline.py "test" > debug_output.log 2>&1
   ```

2. Share the full debug output with context

3. Check recent changes to:
   - Dockerfile
   - Environment variables
   - Script paths
   - API keys or credentials

---

## Related Documentation

- [Nexus Architecture](../architecture/system-reference.md)
- [Docker Setup](../../infra/docker-compose.yml)
- [n8n MCP Setup](./n8n-mcp-setup.md)
- [FactsMind Narrator](../../factsmind/scripts/narrator.py)
