# FactsMind Workflow - Complete Build Documentation

## Project Overview
**FactsMind** is an automated content generation system that transforms facts into premium Instagram carousel content. The workflow generates 4-slide carousels with AI-powered images and programmatically generated text overlays using the official FactsMind style guide.

**Status:** ✅ **PRODUCTION READY** - All visual improvements complete as of November 2025

---

## Architecture & Tech Stack

### Core Technologies
- **n8n** (Self-hosted on Nexus server in Docker)
  - Google Gemini (Content generation + AI image generation)
- **Python 3.12** + **Pillow 11.0** (Pure Python image composition - no templates)
- **Montserrat Typography** (Official FactsMind font family)
- **Docker** (Container for n8n with Python + Pillow)

### System Design
```
Manual Trigger
    ↓
Get Topic (Input)
    ↓
Topic Generator (Parse)
    ↓
Fact Generator (Gemini)
    ↓
Content Engine (Gemini - Generates full carousel JSON)
    ↓
Image Prompt Optimizer (Code node)
    ↓
[4 Parallel Paths - Slides 1-4]
    ├─ Gemini Image 1 → Write File 1 → Code 1 → Execute Command 1
    ├─ Gemini Image 2 → Write File 2 → Code 2 → Execute Command 2
    ├─ Gemini Image 3 → Write File 3 → Code 3 → Execute Command 3
    └─ Gemini Image 4 → Write File 4 → Code 4 → Execute Command 4
        ↓
Final Output: /data/outputs/final/slide_1_final.png ... slide_4_final.png
```

---

## Visual Design System - FactsMind Official Style Guide

### Brand Colors
```python
ELECTRIC_BLUE = (58, 175, 255)    # #3AAFFF - Primary accent
CYAN_GLOW = (117, 232, 255)       # #75E8FF - Secondary glow
SOFT_WHITE = (232, 232, 232)      # #E8E8E8 - Primary text
NEBULA_PURPLE = (72, 42, 110)     # #482A6E - Background gradient
DARK_NAVY = (2, 3, 8)             # Base background color
```

### Typography
- **Title Font:** Montserrat ExtraBold (65px)
- **Subtitle Font:** Montserrat Regular (40px)
- **Hook Font:** Montserrat ExtraBold (110px)
- **Handle/Branding:** Montserrat SemiBold (30px)
- **Line Height:** 1.3x for natural spacing

### Canvas Specifications
- **Dimensions:** 1080x1350px (Instagram native resolution)
- **Background:** Dark navy (#020308) with subtle purple gradient at bottom 20%
- **Layout:** Programmatically generated (no templates)

### Visual Effects
- **Text Shadows:** Black 70% opacity, 3px offset, 12px blur - on ALL text
- **Image Vignette:** Subtle edge darkening (30% strength) for professional look
- **Image Fade:** Gradient transparency from Y=700 to divider line
- **Logo Halo:** 80px spherical black gradient around FactsMind logo
- **SWIPE Indicator:** Cyan glow, 32px, bottom-right corner

---

## Slide Layouts

### Slide 1: Hook (Full-screen dramatic opener)
```
[0-1350px: Full canvas AI-generated image]
  - Scaled to cover entire canvas (1080x1350)
  - Darkened to 70% brightness for text contrast
  - Soft vignette overlay
  - Fade starts at Y=500

[Centered Hook Text - Y=575]
  - Montserrat ExtraBold 110px
  - Soft White (#E8E8E8)
  - Text shadows for readability
  - Smart line breaks with orphan prevention

[Bottom CTA - Y=1250]
  - "TAP TO DISCOVER →"
  - Montserrat Regular 50px
  - Cyan Glow (#75E8FF)
  - Text shadows
```

### Slides 2-4: Reveal (Image + Text split layout)
```
[0-850px: AI-generated image with offset]
  - Image positioned at Y=-75 (moves upward)
  - Vignette applied (30% strength)
  - Fade starts at Y=700 (before divider)
  - Full width 1080px, maintains aspect ratio

[Y=850: Divider with Logo]
  - Cyan glow horizontal lines (#75E8FF)
  - FactsMind logo centered (50px height)
  - 80px spherical black gradient halo behind logo

[Y=925: Title Text]
  - Montserrat ExtraBold 65px
  - Soft White (#E8E8E8)
  - Centered, max width 950px
  - Text shadows (3px offset, 12px blur)
  - Smart line breaks

[Dynamic Subtitle Position]
  - Montserrat Regular 40px
  - Offset from title based on line count:
    - 2 lines: +50px spacing
    - 3 lines: +35px spacing (optimal)
    - 4 lines: +25px spacing
    - 5+ lines: +20px spacing
  - Text shadows for readability

[Bottom Right - Y=1325]
  - "SWIPE >>>"
  - Montserrat Regular 32px
  - Cyan Glow (#75E8FF)
  - Text shadows
```

---

## Key Components & Configurations

### 1. Content Engine (Gemini LLM)
**Node:** Content Engine
- **Model:** gemini-2.0-flash-exp
- **Temperature:** 0.4
- **Structured Output:** Full carousel JSON with:
  - Instagram carousel (4 slides: hook + 3 reveals)
  - Image prompts per slide
  - Visual keywords
  - Hashtags
  - Captions

**Image Prompt Guidelines:**
- Slide 1 (Hook): Visually striking, dramatic lighting, bold composition
- Slides 2-4 (Reveals): Concept illustration, comparisons, consequences
- Style: Professional, cinematic, realistic (NOT fantasy/dreamscapes)
- NO: Text overlays, arrows, diagrams, generic brains
- YES: Specific subjects, dramatic lighting, professional photography

### 2. Image Generation (4 Parallel Paths)
**Node:** Gemini Image (x4)
- **Model:** imagen-3.0-generate-001
- **Input:** Optimized prompts from Image Prompt Optimizer
- **Output:** 1024x1024 PNG images
- **Save to:** /data/outputs/slide_{1-4}.png

### 3. Final Composition (Python Script)
**Script:** /data/scripts/composite.py
**Execution:** 4 parallel Execute Command nodes

**Command Pattern (per slide):**
```javascript
// Code node builds command with proper escaping
const carousel = $('Content Engine').first().json.output.instagram_carousel;
const slide = carousel[0];  // Index: 0-3 for slides 1-4

const title = (slide.title || '').replace(/'/g, "'\\''");
const subtitle = (slide.subtitle || '').replace(/'/g, "'\\''");

return [{
  json: {
    command: `python3 /data/scripts/composite.py ${slide.slide_number} ${slide.type} '${title}' '~~~' '${subtitle}'`
  }
}];

// Execute Command node runs: {{ $json.command }}
```

**Python Script Features:**
- Pure Python generation (no templates)
- Dynamic background with subtle gradient
- Smart text wrapping with natural line breaks
- Orphan word prevention (no single-word last lines)
- Aspect-ratio preserving image scaling
- Professional visual effects (vignette, fade, shadows, halo)
- Montserrat font family integration

---

## File Structure

### Docker Setup
```
/srv/docker/
├── n8n.Dockerfile (Custom: Python3 + Pillow + fonts)
└── docker-compose.yml (Volume mounts for scripts/fonts/outputs)
```

### Container Paths (Inside n8n Docker)
```
/data/scripts/
├── composite.py (Main image composition script)
└── factsmind_logo.png (Official logo)

/data/fonts/
├── Montserrat-ExtraBold.ttf (Titles, hooks)
├── Montserrat-Regular.ttf (Body text, subtitles)
└── Montserrat-SemiBold.ttf (Branding, handle)

/data/outputs/
├── slide_1.png ... slide_4.png (AI-generated images from Gemini)
└── final/
    └── slide_1_final.png ... slide_4_final.png (Final composites)
```

### Host Paths (Volume Mounts)
```
/srv/projects/faceless_prod/
├── scripts/
│   ├── composite.py (Mounted to /data/scripts/)
│   └── factsmind_logo.png (Logo file)
└── fonts/
    └── Montserrat-*.ttf (Mounted to /data/fonts/)

/srv/outputs/
├── slide_*.png (Intermediate AI images)
└── final/
    └── slide_*_final.png (Final carousel slides)
```

### Samba Access (Windows/WSL2)
```
\\100.122.207.23\nexus-outputs\final\
  - Direct file access for previewing/downloading slides
  - Read/write access from Windows or WSL2
```

---

## Critical Configuration Notes

### Image Transfer & 400 Error Fix
**IMPORTANT:** Never use `cat` over SSH for binary image files!

❌ **Wrong (corrupts images):**
```bash
ssh server 'cat /srv/outputs/slide.png > /tmp/slide.png'
# Causes: "Could not process image" API 400 error
```

✅ **Correct (preserves binary data):**
```bash
scp didac@100.122.207.23:/srv/outputs/slide.png /tmp/slide.png
# Or access via Samba: \\100.122.207.23\nexus-outputs\
```

### Volume Mounts in docker-compose.yml
```yaml
volumes:
  - /srv/outputs:/data/outputs                           # AI images + finals
  - /srv/projects/faceless_prod/scripts:/data/scripts   # Python scripts
  - /srv/projects/faceless_prod/fonts:/data/fonts       # Montserrat fonts
```

### Font Installation
Fonts installed via Samba share:
1. Download Montserrat from Google Fonts
2. Copy to: `\\100.122.207.23\nexus-projects\faceless_prod\fonts\`
3. Required files:
   - Montserrat-ExtraBold.ttf
   - Montserrat-Regular.ttf
   - Montserrat-SemiBold.ttf

### Command-Line Escaping
**Problem:** Shell parsing splits arguments on spaces and breaks quotes

**Solution:** Use Code node to build complete command string with proper escaping:
```javascript
const title = (slide.title || '').replace(/'/g, "'\\''");
const subtitle = (slide.subtitle || '').replace(/'/g, "'\\''");
```

---

## Testing & Debugging

### Manual Testing (Avoiding Workflow)
Generate individual slides for testing without triggering n8n:

```bash
# Test reveal slide (slides 2-4)
~/ssh-nexus 'docker exec nexus-n8n python3 /data/scripts/composite.py 2 reveal "Why Do We Dream?" "~~~" "Scientists have discovered that dreams might serve as a crucial memory consolidation process while we sleep."'

# Test hook slide
~/ssh-nexus 'docker exec nexus-n8n python3 /data/scripts/composite.py 1 hook "The Secret Behind Your Dreams" "~~~" ""'

# View results via Samba
\\100.122.207.23\nexus-outputs\final\
```

### Deploy Script Updates
```bash
# Copy updated composite.py to server
scp /home/dvayr/Projects_linux/nexus/scripts/composite.py didac@100.122.207.23:/srv/projects/faceless_prod/scripts/composite.py

# Verify deployment
~/ssh-nexus 'ls -lh /srv/projects/faceless_prod/scripts/composite.py'

# No container restart needed - script is read on each execution
```

### Common Issues

**"Font not found" errors**
- Verify fonts exist: `~/ssh-nexus 'docker exec nexus-n8n ls -lh /data/fonts/'`
- Check volume mount in docker-compose.yml
- Restart container if fonts were just added: `docker-compose restart n8n`

**"Logo not found" errors**
- Check logo location: `/srv/projects/faceless_prod/scripts/factsmind_logo.png`
- Verify accessible in container: `docker exec nexus-n8n ls -lh /data/scripts/factsmind_logo.png`

**Images look corrupted/wrong colors**
- Always use `scp` for image transfer (not `cat` over SSH)
- Verify PNG integrity: `file /tmp/slide.png` should show "PNG image data"

**Text shadows not visible**
- Verify `draw_text_with_shadow()` is used for all text rendering
- Check `TEXT_SHADOW_COLOR = (0, 0, 0, 180)` in composite.py constants

**Workflow returns 400 error**
- Don't read workflow JSON files - triggers n8n API
- Manage workflows only through n8n UI at http://100.122.207.23:5678
- Use manual trigger, avoid auto-execution

---

## Visual Improvements Changelog

### November 2025 - Complete Visual Polish
✅ **Text Shadows** - All text now has drop shadows for readability
  - Black 70% opacity, 3px offset, 12px blur
  - Applied to: titles, subtitles, hook text, CTA, SWIPE indicator

✅ **Image Vignette** - Subtle edge darkening for professional look
  - 30% strength radial gradient
  - Applied to slides 2-4 images

✅ **Logo Halo** - Spherical black gradient around FactsMind logo
  - 80px radius, prevents logo from competing with images
  - Smooth fade from black center to transparent edge

✅ **Larger SWIPE Indicator**
  - Increased from 20px → 32px (60% increase)
  - Changed to cyan glow color for visibility
  - Positioned bottom-right with shadows

✅ **Enhanced Hook Slide**
  - Hook text: 95px → 110px (15% increase)
  - CTA text: 38px → 50px (31% increase)
  - CTA color: Gray → Cyan Glow

✅ **Background Refinement**
  - Dark navy (#020308) base
  - Subtle purple gradient at bottom 20% only (15% max opacity)
  - "Best of both worlds" approach - professional yet branded

### Previous Iterations
- Switched from 2x Figma templates to pure Python generation
- Migrated from DejaVu/Arial to Montserrat typography
- Implemented dynamic subtitle spacing (2-5 line support)
- Added smart text wrapping with orphan prevention
- Integrated official FactsMind style guide
- Changed canvas from 2160x2700 → 1080x1350 (Instagram native)

---

## n8n Workflow Structure

### Active Workflow
**File:** `FactsMindFlow from gpt.json`
**Location:** Managed through n8n UI only (don't edit JSON directly)

### Node Summary
1. **Manual Trigger** - Start workflow execution
2. **Get Topic** - Input node for topic selection
3. **Topic Generator** - Parse topic data
4. **Fact Generator** - Gemini generates verified fact
5. **Content Engine** - Gemini creates full carousel JSON (MAIN NODE)
6. **Image Prompt Optimizer** - Enhances prompts with brand guidelines
7. **Gemini Image 1-4** - Generate AI images in parallel
8. **Write File 1-4** - Save images to /data/outputs/
9. **Code 1-4** - Build composite.py commands with proper escaping
10. **Execute Command 1-4** - Run composite.py for each slide

### Execution Flow
- 4 parallel paths (no merge node)
- Each path processes one slide independently
- No synchronization needed - slides can complete in any order
- Final outputs appear in /data/outputs/final/ as they complete

---

## FactsMind Brand Guidelines

### Voice & Personality
- Dark, mysterious, authoritative yet approachable
- Short sentences, active voice
- The Sage + The Explorer archetype
- Tagline: "Question Everything. Learn Endlessly."

### Content Limits
- Hook: ≤12 words (punchy, curiosity-driven)
- Reveal titles: ≤8 words
- Reveal subtitles: ≤20 words (target 4 lines at 40px font)
- CTA: Clear action ("TAP TO DISCOVER →")

### Content Pillars
Science | Psychology | Technology | History | Space | Nature

### Allowed Emojis (use sparingly)
🧠 ⚡ 💡 🚀 🌌 💎 🔬 📊

---

## Performance & Scaling

### Current Metrics
- **Image Generation Time:** ~8-12 seconds per slide (Gemini)
- **Composition Time:** <1 second per slide (Python)
- **Total Workflow Time:** ~30-40 seconds (4 slides in parallel)
- **Output Quality:** 1080x1350px PNG, ~1.2-1.5MB per slide

### Optimization Opportunities
1. **Caching:** Store frequently used image prompts
2. **Scheduling:** Daily automated generation with cron
3. **A/B Testing:** Multiple image prompt variations
4. **Analytics:** Track engagement per visual style

---

## Next Steps

### Immediate (Ready to Implement)
- [ ] Instagram API integration for automated posting
- [ ] Caption generation from carousel metadata
- [ ] Hashtag optimization based on performance
- [ ] Preview mode before posting

### Short-term
- [ ] YouTube Shorts video generation
- [ ] Multi-platform posting (TikTok, LinkedIn)
- [ ] Analytics dashboard
- [ ] Content calendar scheduling

### Long-term
- [ ] Multi-brand support (different style guides)
- [ ] A/B testing framework
- [ ] Performance analytics integration
- [ ] White-label capability

---

## Support & Troubleshooting

### Docker Container Access
```bash
# SSH to Nexus server
~/ssh-nexus

# Check n8n container status
docker ps | grep nexus-n8n

# Access n8n logs
docker logs nexus-n8n --tail 100

# Execute commands in container
docker exec nexus-n8n python3 /data/scripts/composite.py --help
```

### n8n UI Access
- **URL:** http://100.122.207.23:5678
- **Container:** nexus-n8n
- **Workflows:** Managed via UI only

### File Access
- **SSH:** `~/ssh-nexus` wrapper script
- **Samba:** `\\100.122.207.23\nexus-outputs\`
- **Scripts:** `/srv/projects/faceless_prod/scripts/`
- **Outputs:** `/srv/outputs/final/`

---

## File Locations Reference

| Item | Container Path | Host Path | Access Method |
|------|----------------|-----------|---------------|
| Python script | /data/scripts/composite.py | /srv/projects/faceless_prod/scripts/ | SSH + scp |
| Logo file | /data/scripts/factsmind_logo.png | /srv/projects/faceless_prod/scripts/ | SSH + scp |
| Fonts | /data/fonts/*.ttf | /srv/projects/faceless_prod/fonts/ | Samba |
| AI images | /data/outputs/slide_*.png | /srv/outputs/ | Samba |
| Final slides | /data/outputs/final/*.png | /srv/outputs/final/ | Samba |
| n8n workflow | n8n UI | - | Web UI only |

---

## Contact & Environment

- **Server:** Nexus (100.122.207.23)
- **Docker Container:** nexus-n8n
- **Python Version:** 3.12
- **Pillow Version:** 11.0
- **n8n Version:** Latest (self-hosted)
- **OS:** Linux (Raspberry Pi / Ubuntu)

---

**Status: ✅ PRODUCTION READY**

All visual improvements complete. Workflow generates professional Instagram carousels with proper branding, typography, and visual effects. Ready for Instagram API integration.

**Last Updated:** November 19, 2025
