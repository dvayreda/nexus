# FactsMind Workflow - Complete Build Resume

## Project Overview
**FactsMind** is an automated content generation system that transforms facts into premium Instagram carousel content. The workflow generates 5-slide carousels with AI-powered images and text overlays.

---

## Architecture & Tech Stack

### Core Technologies
- **n8n** (Self-hosted on RPi in Docker)
  - Groq LLM (Fact generation)
  - Google Gemini (Content + Image generation)
- **Python 3.12** + **Pillow 11.2** (Image composition and text rendering)
- **Figma** (Template design - 2x resolution: 2160x2700px)
- **Docker** (Container for n8n with custom Dockerfile)

### System Design
```
Manual Trigger
    ↓
Groq LLM (Generate Fact)
    ↓
Parse (Clean JSON)
    ↓
Gemini LLM (Generate Carousel Content)
    ↓
Parse (Extract data)
    ↓
Extract Carousel Slides (5 items)
    ↓
Prompt Generator (Build image prompts)
    ↓
Generate_or_Skip_Image (Flag slides 1-4 for image generation)
    ↓
Switch Node (Route: slides 1-4 → image, slide 5 → skip)
    ├─ Gemini Image (Generate image)
    │   ↓
    │   Read/Write Files (Save to /tmp/slide_X.png)
    │   ↓
    │   Extract Slide Number (Rebuild data)
    │
    └─ (Slide 5 skips image generation)
        ↓
    Python Composite Script (/data/scripts/composite.py)
    (Paste image + overlay text on template)
        ↓
Final Output: /tmp/factsmind_final/slide_1_final.png ... slide_5_final.png
```

---

## Key Components & Configurations

### 1. Fact Generation (Groq LLM)
**Node:** Generate Fact
- **Model:** llama-3.3-70b-versatile
- **Input:** Topic (via $json.topic)
- **Output:** JSON with fact, category, source_url, verified, why_it_works

### 2. Content Generation (Gemini LLM)
**Node:** Basic LLM Chain1
- **Model:** Google Gemini
- **Temperature:** 0.7
- **Generates:**
  - Instagram carousel (5 slides with titles, subtitles, types)
  - YouTube Shorts script
  - Catch phrases (4)
  - Visual keywords (4)
  - Hashtags (primary, category, trending)
  - Engagement hooks
  - **Image prompts for each slide** (crucial!)

**Image Prompt Guidelines (in system prompt):**
- Slide 1 (Hook): Visually striking through bold composition, dramatic lighting
- Slides 2-4 (Reveals): Show main concept, comparison, consequences
- Slide 5 (CTA): null (uses template only)
- NO: dreamscapes, arrows, text, brains, people
- YES: Professional, grounded, cinematic, realistic
- Style: Professional sci-fi documentary, not fantasy art

### 3. Carousel Data Extraction
**Node:** Just Slides
- Extracts 5 carousel items from Gemini output
- Attaches image_prompts to each item
- Creates 5 parallel data streams (one per slide)

### 4. Image Prompt Enhancement
**Node:** Prompt Generator
- Takes carousel slide data + image_prompts
- Enhances with FactsMind brand guidelines
- Adds technical requirements (1080x1350, no text, etc.)
- Output: full_prompt for Gemini Image generation

### 5. Conditional Image Generation
**Node:** Generate_or_Skip_Image
```javascript
const slideNum = parseInt(slide.slide_number);
return {
  json: {
    ...slide,
    generate_image: slideNum >= 1 && slideNum <= 4
  }
};
```

### 6. Switch & Route
**Node:** Switch
- **Expression:** {{ $json.generate_image }}
- **Route 1 (true):** Slides 1-4 → Gemini Image
- **Route 2 (false):** Slide 5 → Skip to Python composite

### 7. Image Generation
**Node:** Generate an image (Google Gemini)
- **Model:** gemini-2.5-flash-image
- **Input:** full_prompt (from Prompt Generator)
- **Output:** PNG image (base64 binary)

### 8. File Save
**Node:** Read/Write Files from Disk
- **Operation:** Write
- **File Path:** /data/outputs/slide_{{ $json.slide_number }}.png
- **Input Binary Field:** data
- **Data Type:** Binary

### 9. Data Reconstruction
**Node:** Extract Slide Number (Code)
```javascript
const fileName = $input.item.json.fileName;
const slideNum = parseInt(fileName.match(/slide_(\d+)/)[1]);

return {
  json: {
    ...$input.item.json,
    slide_number: slideNum
  }
};
```
Ensures all carousel data + file path flows to composite script.

### 10. Final Composite (Python)
**Script:** /data/scripts/composite.py
**Command:** python3 /data/scripts/composite.py {{ $json.slide_number }} {{ $json.type }} "{{ $json.title }}" "{{ $json.subtitle }}"

**Logic:**
1. Load Figma template from /data/templates/ (2x resolution: 2160x2700px)
2. For slides 1-4: Resize generated image to 2160x1760 and paste at (0,0)
3. For slide 5: Use template as-is
4. Draw title at (1080, 1520) centered
5. Draw subtitle at (1080, 1840) centered
6. Save to /data/outputs/final/slide_X_final.png

---

## Templates (Figma)

### Specifications
- **Size:** 2160x2700px (2x Instagram 1080x1350)
- **Color Scheme:**
  - Background: #0a0e27 (dark navy)
  - Secondary: #1a1f3a (lighter navy)
  - Accent: #6b4ce6 (purple)
  - Text Primary: #ffffff (white)
  - Text Secondary: #e0e0e0 (light gray)

### Layout Structure
```
[Top: Image Area 0-1760px]
  - Generated image composites here
  - Blur/fade gradient (750-880px) blends into text zone

[Bottom: Text Zone 1760-2700px]
  - @FactsMind branding (top)
  - Title: Large font, 1520px from top
  - Subtitle: Smaller font, 1840px from top
  - Footer: SWIPE indicator
```

### Templates Required
1. `template_hook_question.png` - Slide 1 (hook)
2. `template_progressive_reveal.png` - Slides 2-4 (reveals)
3. `template_call_to_action.png` - Slide 5 (CTA: "Mind = Blown? 🧠")

---

## File Structure

### Docker Setup
```
/srv/docker/
├── n8n.Dockerfile (Custom Dockerfile with Python3 + Pillow)
└── docker-compose.yml
```

### Container Paths (Inside n8n Docker)
```
/data/scripts/
└── composite.py (Python image composition script)

/data/templates/
├── template_hook_question.png
├── template_progressive_reveal.png
└── template_call_to_action.png

/data/outputs/
├── slide_1.png ... slide_4.png (Generated images from Gemini)
└── final/
    └── slide_1_final.png ... slide_5_final.png (Final composited carousel)
```

### RPi Host Paths (Mounted Volumes)
```
/srv/projects/faceless_prod/
├── scripts/
│   └── composite.py (Mounted to /data/scripts/)
└── templates/
    └── *.png (Mounted to /data/templates/)

/srv/outputs/
├── slide_1.png ... slide_4.png (Mounted to /data/outputs/)
└── final/
    └── slide_X_final.png (Accessible via Samba: \\100.122.207.23\nexus-outputs\final\)
```

---

## Critical Configuration Notes

### Image Generation Challenges Solved
1. **Binary Data Handling:**
   - Gemini outputs image as binary (not base64)
   - Use "Read/Write Files from Disk" node with "data" binary field
   - No custom code needed (n8n handles it)

2. **Data Loss Through Gemini:**
   - Gemini Image replaces all JSON with metadata
   - Solution: Rebuild slide_number from filename before Python script
   - All carousel data preserved through pipeline

3. **File System:**
   - Docker container has isolated filesystem
   - Use volume mounts for persistent data: /data/scripts/, /data/templates/, /data/outputs/
   - Templates mounted from: /srv/projects/faceless_prod/templates/ → /data/templates/
   - Outputs accessible on host: /srv/outputs/ (via Samba at \\100.122.207.23\nexus-outputs)

4. **Image Sizing:**
   - Gemini generates at 1080x (Instagram native)
   - Python resizes to 2160x1760 (2x Figma template)
   - No quality loss, maintains aspect ratio

5. **Text Positioning:**
   - Template is 2160x2700px
   - Image zone: 2160x1760px (Y=0-1760)
   - Title Y-position: 1520px
   - Subtitle Y-position: 1840px
   - Using PIL anchor='mm' for perfect centering

### Python & Pillow in Docker
Custom Dockerfile:
```dockerfile
FROM n8nio/n8n:latest
USER root
RUN apk add --no-cache python3 py3-pip py3-pillow jpeg-dev zlib-dev freetype-dev
USER node
```

Rebuild container:
```bash
cd /srv/docker
docker compose build n8n
docker compose up -d n8n
```

---

## FactsMind Brand Guidelines (In System Prompts)

### Voice & Personality
- Dark, mysterious, authoritative yet approachable
- Short sentences, active voice
- The Sage + The Explorer
- Tagline: "Question Everything. Learn Endlessly."

### Allowed Emojis
🧠 ⚡ 💡 🚀 🌌 💎 🔬 📊

### Content Limits
- Fact: ≤15 words
- Carousel titles: ≤10 words
- Carousel subtitles: ≤25 words
- Catch phrases: ≤12 words
- YouTube Shorts: 120-220 words

### Content Pillars
Science | Psychology | Technology | History | Space

---

## Lessons Learned & Best Practices

### ✅ What Worked
1. **Separating image generation from composition** - Gemini for creativity, Python for precision
2. **Using Figma templates at 2x resolution** - Cleaner output, easier font sizing
3. **Explicit brand guidelines in LLM prompts** - Consistent output quality
4. **Python + Pillow for image composition** - Reliable, maintainable, proper aspect ratio handling
5. **Docker volume mounts (/data/*)** - Persistent, accessible from host via Samba, survives restarts

### ❌ What Didn't Work
1. **ImageMagick approach** - Shell command escaping issues, inconsistent results (removed in favor of Python)
2. **n8n Code Node for file operations** - Sandbox restrictions (no fs module)
3. **Complex shell scripts with conditionals** - Escaping nightmares
4. **Using /tmp/ without volume mounts** - Files lost on container restart, not accessible from host
5. **Direct resize without aspect ratio** - Caused image distortion (fixed with smart crop/scale)

### ⚠️ Important Gotchas
1. **Docker container filesystem is isolated** - Use volume mounts (/data/*) for persistent access
2. **n8n Code Nodes run in VM2 sandbox** - No child_process, fs, or external modules
3. **Execute Command execution mode** - Must be "Run Once for Each Item" for 5 slides
4. **Gemini Image binary output** - Must use Read/Write Files node, not custom code
5. **Text positioning is absolute** - PIL anchor='mm' ensures pixel-perfect centering
6. **Volume mount paths** - Container /data/* maps to host /srv/projects/ and /srv/outputs/

---

## Testing Checklist

- [x] Groq generates valid facts
- [x] Gemini creates carousel JSON with all fields
- [x] Image prompts are unique per slide
- [x] Gemini generates 5 images (1 per slide)
- [x] Images save correctly to /tmp
- [x] Python script receives all data
- [x] Final images composite correctly
- [x] Text is readable and positioned correctly
- [x] No template placeholder text showing
- [x] Slide 5 CTA displays correctly
- [ ] Instagram carousel uploads successfully
- [ ] All 5 slides display properly

---

## Next Steps / Future Work

1. **Instagram Upload:**
   - Add Instagram API node after Python composite
   - Send 5 final images as carousel
   - Add caption from carousel metadata

2. **Optimization:**
   - Implement caching for frequently used facts
   - Add scheduling for daily post generation
   - Build dashboard to view past carousels

3. **Enhancement:**
   - Add video/Shorts generation
   - Implement A/B testing for image prompts
   - Create analytics integration

4. **Scaling:**
   - Multi-topic support
   - Custom brand variations
   - White-label capability

---

## Support & Debugging

### Common Issues

**"Command failed: python3 not found"**
- Install in container: `docker exec <container_id> apt-get install -y python3 python3-pil`

**"PIL module not found"**
- Install Pillow: `docker exec <container_id> apt-get install -y python3-pil`

**"File not found" errors**
- Check volume mounts in docker-compose.yml are correct
- Verify templates exist on host: `ls -lh /srv/projects/faceless_prod/templates/`
- Check inside container: `docker exec nexus-n8n ls -lh /data/templates/`

**Images look distorted**
- Check Python resize dimensions match template size
- Verify template is actually 2160x2700px (check file properties)

**Text not visible**
- Verify font file exists: `/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf`
- Check text color (#ffffff for title, #e0e0e0 for subtitle)
- Verify Y-coordinates match template layout

---

## File Locations Summary

| Item | Container Path | Host Path | Purpose |
|------|----------------|-----------|---------|
| n8n workflow | n8n UI | /home/dvayr/Projects_linux/nexus/factsmind_workflow.json | Main workflow orchestration |
| Python script | /data/scripts/composite.py | /srv/projects/faceless_prod/scripts/composite.py | Final image composition |
| Figma templates | /data/templates/*.png | /srv/projects/faceless_prod/templates/*.png | Design + layout |
| Generated images | /data/outputs/slide_X.png | /srv/outputs/slide_X.png | Intermediate (slides 1-4 only) |
| Final carousel | /data/outputs/final/*.png | /srv/outputs/final/*.png | Ready for Instagram upload |
| Samba access | - | \\100.122.207.23\nexus-outputs\final\ | Remote file access |

---

## Contact & Notes

- **Docker Container ID:** Check with `docker ps | grep n8n`
- **n8n Access:** http://localhost:5678 or http://100.122.207.23:5678
- **Python Version:** 3.12.12
- **Pillow Version:** 11.2.1

---

**Status: COMPLETE & TESTED** ✅

All 5 carousel slides generate successfully with images and text overlays. Ready for Instagram integration.

Last Updated: November 18, 2025
