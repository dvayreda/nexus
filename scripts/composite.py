#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont
import sys
import os

slide_num = int(sys.argv[1])
slide_type = sys.argv[2]
title = sys.argv[3]
subtitle = sys.argv[4]

template_map = {
    "hook": "template_hook_question.png",
    "reveal": "template_progressive_reveal.png",
    "cta": "template_call_to_action.png"
}

# Load template (from /data/templates inside container)
template_file = template_map.get(slide_type, "template_progressive_reveal.png")
template = Image.open(f"/data/templates/{template_file}")

# Paste generated image (slides 1-4 only)
if slide_num <= 4:
    gen_img_path = f"/data/outputs/slide_{slide_num}.png"
    if os.path.exists(gen_img_path) and os.path.getsize(gen_img_path) > 0:
        try:
            gen_img = Image.open(gen_img_path)
        except Exception as e:
            print(f"Warning: Could not open image {gen_img_path}: {e}")
            print("Continuing with template only...")
            gen_img = None
    else:
        print(f"Warning: Image file missing or empty: {gen_img_path}")
        print("Continuing with template only...")
        gen_img = None

    if gen_img:

        # Target size for image area (leave space for @FactsMind at top)
        target_width = 2160
        target_height = 1760

        # Calculate scaling to cover the area while maintaining aspect ratio
        img_ratio = gen_img.width / gen_img.height
        target_ratio = target_width / target_height

        if img_ratio > target_ratio:
            # Image is wider - scale by height
            new_height = target_height
            new_width = int(new_height * img_ratio)
        else:
            # Image is taller - scale by width
            new_width = target_width
            new_height = int(new_width / img_ratio)

        # Resize with high quality
        gen_img = gen_img.resize((new_width, new_height), Image.Resampling.LANCZOS)

        # Crop to center if needed
        left = (new_width - target_width) // 2
        top = (new_height - target_height) // 2
        right = left + target_width
        bottom = top + target_height
        gen_img = gen_img.crop((left, top, right, bottom))

        # Paste at top of template (0, 0)
        template.paste(gen_img, (0, 0))

# Draw text with much larger fonts
draw = ImageDraw.Draw(template)
try:
    # Increased font sizes for 2160x2700px canvas
    title_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 180)
    subtitle_font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 85)
except:
    title_font = ImageFont.load_default()
    subtitle_font = ImageFont.load_default()

# Draw centered text in the bottom text zone
# Title around Y=1950 (in the 1760-2700 text zone)
# Subtitle around Y=2200
draw.text((1080, 1950), title, fill="white", font=title_font, anchor="mm")
draw.text((1080, 2200), subtitle, fill=(224, 224, 224), font=subtitle_font, anchor="mm")

# Save final output
os.makedirs("/data/outputs/final", exist_ok=True)
template.save(f"/data/outputs/final/slide_{slide_num}_final.png")
print(f"Saved to /data/outputs/final/slide_{slide_num}_final.png")
