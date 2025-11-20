# FactsMind Workflow - Complete Build Documentation

## Project Overview
**FactsMind** is an automated content generation system that transforms facts into premium Instagram carousel content. The workflow generates 5-slide carousels + Story backgrounds with AI-powered images and programmatically generated text overlays using the official FactsMind style guide.

**Status:** ✅ **v1.0 LAUNCHED** - Production deployment with Amazon Associates monetization (November 19, 2025)

**Instagram:** [@factsmind](https://instagram.com/factsmind)
**Publishing Schedule:** Daily @ 18:30 CET
**Content Buffer:** 3-day minimum (batched in Telegram)

---

## Architecture & Tech Stack

### Core Technologies
- **n8n** (Self-hosted on Nexus server in Docker)
  - **Gemini 3 Pro Preview** (Content generation with enhanced reasoning)
  - **Imagen 3.0** (AI image generation)
- **Python 3.12** + **Pillow 11.0** (Pure Python image composition - no templates)
- **Montserrat Typography** (Official FactsMind font family)
- **Telegram Bot API** (Content delivery with multipart POST)
- **Amazon Associates** (Monetization via book recommendations)
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
Content Engine (Gemini 3 Pro - Generates full carousel JSON + Amazon product)
    ↓
Image Prompt Optimizer (Code node)
    ↓
[6 Parallel Paths - Slides 1-5 + Story Background]
    ├─ Imagen 3.0 (1) → Write File 1 → Code 1 → Execute Command 1
    ├─ Imagen 3.0 (2) → Write File 2 → Code 2 → Execute Command 2
    ├─ Imagen 3.0 (3) → Write File 3 → Code 3 → Execute Command 3
    ├─ Imagen 3.0 (4) → Write File 4 → Code 4 → Execute Command 4
    ├─ Imagen 3.0 (5) → Write File 5 → Code 5 → Execute Command 5
    └─ Imagen 3.0 (Story) → Write File Story
        ↓
Telegram Delivery (HTTP Request multipart POST)
    ├─ Album: 6 photos (5 carousel + 1 story)
    └─ Caption: Instagram text + Amazon product cheat sheet
        ↓
Final Output: 3-day buffer stored in Telegram
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

## Narrative Structure & Content Rules

### 5-Slide Story Arc (v1.0)
The carousel follows a strict narrative structure optimized for engagement and mobile viewing:

1. **Slide 1 - Hook:** Direct declarative paradox (NO "What if..."). Example: "This blue planet is a lie."
2. **Slide 2 - Reveal:** Phenomenon name + precise definition (avoid inaccurate metaphors)
3. **Slide 3 - Mechanism:** **CRITICAL RULE** - Must show MACRO or MICROSCOPIC visualization (cellular/atomic structures, not fantasy creatures). Prevents AI hallucinations.
4. **Slide 4 - Twist:** Real-world consequence. **THICK, BOLD LINES** in visuals for mobile readability.
5. **Slide 5 - Outro:** Minimalist branding. Text/logo raised 15% vertically to avoid Instagram UI collision.

### Story Background (6th Image)
- **Format:** 9:16 vertical (1080x1920)
- **Style:** Dark, minimalist background for Link Sticker placement
- **Purpose:** Amazon Associates product link delivery

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

### Slides 2-4: Reveal/Mechanism/Twist (Image + Text split layout)
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

### Slide 5: Outro (Minimalist Branding)
```
[Dark navy background with subtle gradient]
  - No image (pure branding slide)
  - Clean, minimalist aesthetic

[Center - Vertical Position Raised 15%]
  - FactsMind logo (large)
  - Tagline: "Question Everything. Learn Endlessly."
  - Social handle: @factsmind
  - IMPORTANT: All elements raised to avoid Instagram UI collision

[Visual Treatment]
  - Subtle purple gradient at bottom
  - Logo with soft glow effect
  - Clean typography hierarchy
```

### Story Background (6th Image - Vertical Format)
```
[1080x1920px vertical canvas]
  - Dark, minimalist background
  - Designed for Link Sticker overlay
  - No text or branding (allows Instagram UI)
  - Purpose: Amazon Associates monetization
```

---

## Key Components & Configurations

### 1. Content Engine (Gemini LLM)
**Node:** Content Engine
- **Model:** gemini-3-pro-preview (migrated from gemini-2.0-flash-exp)
- **Temperature:** 0.4
- **Reason for Migration:** Enhanced logical reasoning and better adherence to negative constraints
- **Structured Output:** Full carousel JSON with:
  - Instagram carousel (5 slides: hook + reveal + mechanism + twist + outro)
  - Image prompts per slide (6 images total including Story background)
  - Visual keywords
  - Hashtags
  - Captions
  - **NEW:** `product_recommendation` field (Amazon Associates book/product)

**Image Prompt Guidelines (v1.0):**
- **Slide 1 (Hook):** Visually striking, dramatic lighting, bold composition
- **Slide 2 (Reveal):** Phenomenon visualization, precise scientific accuracy
- **Slide 3 (Mechanism):** **CRITICAL** - MACRO/MICROSCOPIC view required (cellular, atomic, geological structures). NO fantasy creatures, birds, or hallucinations.
- **Slide 4 (Twist):** Real-world consequence with **THICK, BOLD LINES** for mobile visibility
- **Slide 5 (Outro):** N/A - pure text/branding (no AI image)
- **Story Background:** Dark, vertical (9:16), minimalist for Link Sticker placement
- **Style:** Professional, cinematic, documentary-grade realism (NOT fantasy/dreamscapes)
- **NO:** Text overlays, arrows, diagrams, generic brains, fantasy creatures
- **YES:** Specific subjects, dramatic lighting, professional photography, scientific accuracy

### 2. Image Generation (6 Parallel Paths)
**Node:** Imagen 3.0 (x6)
- **Model:** imagen-3.0-generate-001
- **Input:** Optimized prompts from Image Prompt Optimizer
- **Output:** 1024x1024 PNG images (carousel slides) + 1080x1920 PNG (story background)
- **Save to:** /data/outputs/slide_{1-5}.png + story.png

### 3. Final Composition (Python Script)
**Script:** /data/scripts/composite.py
**Execution:** 5 parallel Execute Command nodes

**Command Pattern (per slide):**
```javascript
// Code node builds command with proper escaping
const carousel = $('Content Engine').first().json.output.instagram_carousel;
const slide = carousel[0];  // Index: 0-4 for slides 1-5

const title = (slide.title || '').replace(/'/g, "'\\''");
const subtitle = (slide.subtitle || '').replace(/'/g, "'\\''");

return [{
  json: {
    command: `python3 /data/scripts/composite.py ${slide.slide_number} ${slide.type} '${title}' '~~~' '${subtitle}'`
  }
}];

// Execute Command node runs: {{ $json.command }}
```

### 4. Telegram Delivery (HTTP Request Node)
**Critical Fix:** Native n8n Telegram node fails with `sendMediaGroup` for albums.

**Solution:** HTTP Request node with manual multipart POST

**Node Configuration:**
- **Method:** POST (Multipart Form Data)
- **URL:** `https://api.telegram.org/bot{TOKEN}/sendMediaGroup`
- **Body Type:** Form-Data (Multipart)
- **Files:** 6 binary attachments (slide_1...slide_5, story)

**JSON Payload Structure:**
```json
{
  "chat_id": "YOUR_CHAT_ID",
  "media": [
    {"type": "photo", "media": "attach://slide_1"},
    {"type": "photo", "media": "attach://slide_2"},
    {"type": "photo", "media": "attach://slide_3"},
    {"type": "photo", "media": "attach://slide_4"},
    {"type": "photo", "media": "attach://slide_5"},
    {"type": "photo", "media": "attach://story"}
  ]
}
```

**Multipart Mapping:**
Each binary file is mapped with the `attach://slide_X` syntax in the media array.

**Caption Message (Separate):**
Second message sent with:
- Instagram caption text
- Hashtags
- **Cheat Sheet:** Amazon product name for quick lookup
- Example: "📚 Book: [Product Name] - Search on Amazon"

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
├── slide_1.png ... slide_5.png (Carousel AI-generated images from Imagen 3.0)
├── story.png (Story background - vertical format)
└── final/
    └── slide_1_final.png ... slide_5_final.png (Final carousel composites)
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
├── slide_1.png ... slide_5.png (Carousel AI images)
├── story.png (Story background - vertical)
└── final/
    └── slide_1_final.png ... slide_5_final.png (Final carousel composites)
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
# Test hook slide (Slide 1)
~/ssh-nexus 'docker exec nexus-n8n python3 /data/scripts/composite.py 1 hook "The Secret Behind Your Dreams" "~~~" ""'

# Test reveal/mechanism/twist slides (Slides 2-4)
~/ssh-nexus 'docker exec nexus-n8n python3 /data/scripts/composite.py 2 reveal "Why Do We Dream?" "~~~" "Scientists have discovered that dreams might serve as a crucial memory consolidation process while we sleep."'

# Test outro slide (Slide 5)
~/ssh-nexus 'docker exec nexus-n8n python3 /data/scripts/composite.py 5 outro "FactsMind" "~~~" "Question Everything. Learn Endlessly."'

# View results via Samba
\\100.122.207.23\nexus-outputs\final\
```

**Note:** Story background is generated raw by Imagen 3.0 (no composite.py processing).

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

## Monetization Strategy (Amazon Associates)

### Overview
**Program:** Amazon Associates (Affiliate ID: `factsmind-21`)
**Method:** Story Bridge Strategy
**Target:** Educational books and science products related to carousel topics

### Content Flow
1. **Feed Carousel** → Attraction & Engagement (5 slides)
2. **Story Post** → Conversion (Link Sticker on Story Background)
3. **Story Highlight** → Persistent Discovery ("📚 Books" collection)

### Implementation

**AI Integration:**
- Gemini 3 Pro generates `product_recommendation` field in JSON schema
- Suggests real Amazon book/product relevant to the topic
- Generates Story text: "Want to learn more? Tap the link 👆"

**Link Generation:**
- **Tool:** Amazon SiteStripe (Desktop view on PC or mobile)
- **Format:** Short links with tracking: `https://amzn.to/XXXXXX?tag=factsmind-21`
- **IMPORTANT:** Always verify the `factsmind-21` tag is present in URLs

**Publishing Workflow:**
1. Post carousel to Feed (attraction)
2. Immediately publish Story with:
   - Dark Story Background (from workflow)
   - Amazon Link Sticker (manually added via Instagram app)
   - Product-specific text generated by AI
3. Save Story to "📚 Books" Highlight (permanent)

### Instagram Bio Setup
**Profile:** [@factsmind](https://instagram.com/factsmind)
**Bio Text:** "The world is stranger than you think. 🧠 Unseen Science & History."
**Link in Bio:** Bento.me configuration
  - **Dark Mode:** Enabled via black background image
  - **Featured Card:** "📚 The Science Library" (curated Amazon book list)
  - **Other Cards:** Latest content, contact, social links

### Best Practices
- Always maintain 3-day content buffer in Telegram before posting
- Use mobile-friendly Link Stickers (not swipe-up, not text links)
- Keep Story text minimal (let the link sticker do the work)
- Update "📚 Books" Highlight regularly with new recommendations
- Track clicks via Amazon Associates dashboard
- **NEVER** use automated comment bots for engagement

### Engagement Strategy
**Time Commitment:** 15 minutes daily
**Method:** Manual interaction with similar accounts
**Focus:** High-value comments on science/education content
**Goal:** Authentic community building (NOT growth hacking)

---

## Publishing Operations

### Daily Schedule
- **Time:** 18:30 CET (Spain timezone)
- **Frequency:** 1 post per day
- **Buffer:** Minimum 3-day backlog maintained in Telegram
- **Safety:** Prevents last-minute technical failures

### Content Batching Workflow
1. Run n8n workflow to generate 3-5 carousels
2. Store all outputs in Telegram (albums of 6 images each)
3. Review and approve before scheduling
4. Post to Instagram Feed at 18:30 CET
5. Immediately create Story with Amazon link
6. Save Story to Highlights

### Quality Control
- All content reviewed before posting
- Images checked for mobile readability
- Amazon products verified for relevance
- Links tested for proper tracking tag

---

## Project Changelog

### November 19, 2025 - v1.0 PRODUCTION LAUNCH 🚀
✅ **5-Slide Carousel Structure**
  - Migrated from 4-slide to 5-slide format
  - Added Slide 5: Minimalist outro/branding (elements raised 15% for Instagram UI)
  - Total 6 images generated: 5 carousel + 1 Story background

✅ **Gemini 3 Pro Migration**
  - Upgraded from gemini-2.0-flash-exp to gemini-3-pro-preview
  - Reason: Enhanced logical reasoning and better negative constraint adherence
  - Improved prompt following for narrative structure rules

✅ **Advanced Narrative Rules**
  - Slide 1: Direct paradox (NO "What if...")
  - Slide 2: Precise definitions (avoid metaphors)
  - Slide 3: **CRITICAL** - MACRO/MICROSCOPIC visualization requirement (prevents AI hallucinations)
  - Slide 4: **THICK, BOLD LINES** for mobile visibility
  - Slide 5: Vertical positioning adjustment for Instagram UI

✅ **Amazon Associates Integration**
  - Added `product_recommendation` field to AI-generated JSON
  - Story Bridge monetization strategy implemented
  - Bento.me dark mode setup with "📚 The Science Library" card
  - Affiliate tag: `factsmind-21`

✅ **Telegram Delivery System**
  - Fixed native n8n Telegram node failure (sendMediaGroup)
  - Implemented HTTP Request multipart POST workaround
  - Album delivery: 6 photos per workflow execution
  - Caption message: Instagram text + Amazon product "cheat sheet"

✅ **Instagram Branding**
  - Profile: @factsmind
  - Bio: "The world is stranger than you think. 🧠 Unseen Science & History."
  - Story Highlights: "📚 Books" collection
  - Publishing schedule: Daily @ 18:30 CET
  - Content buffer: 3-day minimum (safety protocol)

✅ **Story Background Generation**
  - 6th image: Vertical format (1080x1920)
  - Dark, minimalist design
  - Optimized for Link Sticker overlay
  - No branding (allows Instagram UI elements)

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

### Node Summary (v1.0)
1. **Manual Trigger** - Start workflow execution
2. **Get Topic** - Input node for topic selection
3. **Topic Generator** - Parse topic data
4. **Fact Generator** - Gemini generates verified fact
5. **Content Engine** - Gemini 3 Pro creates full carousel JSON + Amazon product (MAIN NODE)
6. **Image Prompt Optimizer** - Enhances prompts with brand guidelines + narrative rules
7. **Imagen 3.0 (x6)** - Generate AI images in parallel (5 slides + 1 story)
8. **Write File 1-5 + Story** - Save images to /data/outputs/
9. **Code 1-5** - Build composite.py commands with proper escaping
10. **Execute Command 1-5** - Run composite.py for carousel slides
11. **HTTP Request (Telegram)** - Send album via multipart POST (6 photos)
12. **HTTP Request (Caption)** - Send Instagram text + Amazon product cheat sheet

### Execution Flow
- 6 parallel image generation paths (5 carousel + 1 story)
- 5 carousel slides processed through composite.py
- Story background sent raw to Telegram
- No merge node needed - Telegram delivery aggregates all outputs
- Final outputs: /data/outputs/final/ + Telegram album

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

### Current Metrics (v1.0)
- **Image Generation Time:** ~8-12 seconds per image (Imagen 3.0)
- **Composition Time:** <1 second per slide (Python)
- **Total Workflow Time:** ~50-60 seconds (6 images in parallel, 5 slides composed)
- **Output Quality:**
  - Carousel: 1080x1350px PNG, ~1.2-1.5MB per slide (5 slides)
  - Story: 1080x1920px PNG, ~800KB-1MB (1 image)
  - Total: ~7-9MB per workflow execution
- **Telegram Delivery:** ~2-3 seconds (album upload)

### Optimization Opportunities
1. **Caching:** Store frequently used image prompts (avoid regeneration)
2. **Scheduled Batching:** Generate 3-5 carousels per batch (implemented in Telegram)
3. **A/B Testing:** Multiple image prompt variations for same topic
4. **Analytics:** Track engagement per visual style, hook types
5. **Amazon Optimization:** Track which product types convert best

---

## Next Steps

### Completed in v1.0 ✅
- [x] 5-slide carousel structure
- [x] Story background generation (vertical format)
- [x] Amazon Associates integration
- [x] Telegram delivery system
- [x] Content batching workflow
- [x] Publishing schedule (18:30 CET)
- [x] Gemini 3 Pro migration

### Immediate (Ready to Implement)
- [ ] Instagram API integration for automated posting (currently manual)
- [ ] Automated Story posting with Link Stickers
- [ ] Hashtag A/B testing based on performance
- [ ] Preview mode with side-by-side comparisons
- [ ] Amazon Associates click tracking dashboard

### Short-term
- [ ] YouTube Shorts video generation (vertical video format)
- [ ] Multi-platform posting (TikTok, LinkedIn carousels)
- [ ] Analytics dashboard (engagement, reach, Amazon clicks)
- [ ] Content calendar with auto-scheduling
- [ ] Automated engagement bot (safe, rule-compliant)

### Long-term
- [ ] Multi-brand support (different style guides per account)
- [ ] A/B testing framework (image styles, hooks, CTAs)
- [ ] Performance analytics with ML insights
- [ ] White-label capability for client accounts
- [ ] Voice-over generation for YouTube Shorts/TikTok

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
| AI carousel images | /data/outputs/slide_1-5.png | /srv/outputs/ | Samba |
| Story background | /data/outputs/story.png | /srv/outputs/ | Samba |
| Final slides | /data/outputs/final/slide_1-5_final.png | /srv/outputs/final/ | Samba |
| n8n workflow | n8n UI | - | Web UI only |
| Telegram delivery | - | - | HTTP Request API |

---

## Contact & Environment

### Technical Infrastructure
- **Server:** Nexus (100.122.207.23)
- **Docker Container:** nexus-n8n
- **Python Version:** 3.12
- **Pillow Version:** 11.0
- **n8n Version:** Latest (self-hosted)
- **OS:** Linux (Raspberry Pi / Ubuntu)

### AI Models
- **Content Engine:** Gemini 3 Pro Preview (gemini-3-pro-preview)
- **Image Generation:** Imagen 3.0 (imagen-3.0-generate-001)
- **Temperature:** 0.4 (balanced creativity/consistency)

### External Integrations
- **Telegram Bot API:** Content delivery & batching
- **Amazon Associates:** Affiliate program (factsmind-21)
- **Instagram:** @factsmind (manual posting via app)
- **Bento.me:** Link-in-bio landing page

---

**Status: ✅ v1.0 LAUNCHED (PRODUCTION)**

FactsMind is now live on Instagram with full monetization via Amazon Associates. The system generates 5-slide carousels + Story backgrounds, delivers content via Telegram for batching, and publishes daily at 18:30 CET. Story Bridge strategy implemented for affiliate conversions.

**Key Achievements:**
- 5-slide narrative structure with advanced AI constraints
- Gemini 3 Pro migration for enhanced reasoning
- Amazon Associates integration with product recommendations
- Telegram delivery via HTTP Request multipart POST
- Mobile-optimized visuals (thick lines, raised branding)
- 3-day content buffer protocol (safety & consistency)

**Current Focus:**
- Daily publishing at 18:30 CET
- Manual engagement (15 min/day)
- Amazon click tracking
- Story Highlights curation ("📚 Books")

**Next Milestone:** Instagram API automation (Q1 2026)

**Last Updated:** November 19, 2025 - v1.0 Production Launch
