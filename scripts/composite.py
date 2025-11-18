#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont, ImageEnhance
import sys
import os
import re

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

# Brand Colors (darker background for moodier aesthetic)
DARK_NAVY = (2, 3, 8)         # Even darker for moodier aesthetic
PURPLE = (107, 76, 230)        # #6b4ce6
WHITE = (255, 255, 255)
LIGHT_GRAY = (224, 224, 224)   # #e0e0e0
DIVIDER_COLOR = (200, 200, 220)  # Even stronger, highly visible divider lines

# Canvas Dimensions (1x Instagram native resolution - matches 1024x1024 images)
WIDTH = 1080
HEIGHT = 1350

# Layout Configuration - Slides 2-4
IMAGE_Y_OFFSET = -75          # Move image upwards (negative = up)
DIVIDER_Y = 850               # Divider line position (moved down)
IMAGE_FADE_START = 700        # Where fade starts on canvas (before divider)
TITLE_Y = 925                 # Title starting position (moved down)
SUBTITLE_Y_OFFSET = 35        # Gap from title end to subtitle start (tighter spacing)
TEXT_MAX_WIDTH = 950          # Max text width (65px margins on each side)
SWIPE_INDICATOR_Y = 1325      # Y position for "SWIPE >>>" indicator (25px from bottom)

# Layout Configuration - Slide 1 (Hook)
HOOK_TEXT_Y = 575             # 42.5% from top (575/1350) - slight upward tension
HOOK_FONT_SIZE = 95           # Large, impactful hook text
HOOK_MAX_WIDTH = 900          # Slightly narrower for centered text
HOOK_CTA_Y = 1250             # CTA position (100px from bottom)
HOOK_CTA_SIZE = 38            # Large, readable CTA (rounded up from 37.5)
HOOK_IMAGE_DARKEN = 0.7       # Darken image to 70% brightness for more contrast
HOOK_FADE_START = 500         # Start fade earlier for softer transition

# Typography
TITLE_FONT_SIZE = 65          # Halved
TITLE_EMPHASIS_SIZE = 68      # +3px for subtle emphasis on key words (disabled for now)
SUBTITLE_FONT_SIZE = 40       # Halved
DIVIDER_FONT_SIZE = 30        # Halved for visibility
LINE_HEIGHT_RATIO = 1.3       # Spacing between lines (unchanged)

# Font Paths (Modern, Instagram-optimized fonts)
FONT_BOLD = "/data/fonts/Poppins-Bold.ttf"          # Title font (bold, modern, Instagram-proven)
FONT_REGULAR = "/data/fonts/Poppins-Medium.ttf"     # Subtitle font (clean, readable)

# Keywords that might get subtle emphasis (barely perceptible)
EMPHASIS_WORDS = {'why', 'how', 'what', 'when', 'where', 'never', 'always', 'secret', 'truth'}


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def create_base_background():
    """Create solid dark background for entire canvas"""
    return Image.new('RGB', (WIDTH, HEIGHT), DARK_NAVY)


def load_and_resize_image(image_path, target_width):
    """
    Load and resize image to fit width while maintaining aspect ratio.
    NO CROPPING - full image is preserved.
    """
    try:
        img = Image.open(image_path)
        print(f"DEBUG: Original image size: {img.size}")
    except Exception as e:
        print(f"Warning: Could not open image {image_path}: {e}")
        return None

    # Scale to fit width, maintain aspect ratio
    aspect_ratio = img.height / img.width
    new_width = target_width
    new_height = int(target_width * aspect_ratio)

    # Resize with high quality (no cropping)
    img = img.resize((new_width, new_height), Image.Resampling.LANCZOS)

    print(f"DEBUG: Resized to {img.size} (full image, no crop)")

    return img


def apply_fade_to_image(image, fade_start_y_relative):
    """
    Apply gradient fade to bottom of an image.
    fade_start_y_relative is relative to the image itself (not canvas).
    Returns RGBA image with transparency gradient at bottom.
    """
    # Convert to RGBA
    img_rgba = image.convert('RGBA')

    # Create alpha mask - start fully opaque
    alpha_mask = Image.new('L', img_rgba.size, 255)
    mask_draw = ImageDraw.Draw(alpha_mask)

    # Calculate fade zone
    fade_height = img_rgba.height - fade_start_y_relative

    # Draw gradient from opaque to transparent
    for i in range(fade_height):
        y = fade_start_y_relative + i
        # Alpha decreases from 255 to 0
        alpha = int(255 * (1 - i / fade_height))
        mask_draw.line([(0, y), (img_rgba.width, y)], fill=alpha)

    # Apply mask to image
    img_rgba.putalpha(alpha_mask)

    print(f"DEBUG: Applied fade to image from Y={fade_start_y_relative} to bottom of image")
    return img_rgba


def apply_hook_effects(image, darken_amount=0.7):
    """
    Apply hook-specific effects: darkening and soft vignette for text contrast.
    darken_amount: 1.0 = original, 0.7 = 70% brightness
    """
    # Convert to RGB
    img = image.convert('RGB')

    # Darken the image
    enhancer = ImageEnhance.Brightness(img)
    img = enhancer.enhance(darken_amount)

    # Create soft vignette overlay
    vignette = Image.new('RGBA', img.size, (0, 0, 0, 0))
    vignette_draw = ImageDraw.Draw(vignette)

    # Draw radial gradient for vignette (darker at edges)
    center_x, center_y = img.width // 2, img.height // 2
    max_radius = int((img.width ** 2 + img.height ** 2) ** 0.5 / 2)

    # Draw concentric circles with increasing opacity
    for radius in range(max_radius, 0, -20):
        # Calculate alpha based on distance from center
        alpha = int(80 * (1 - radius / max_radius))
        if alpha > 0:
            bbox = [
                center_x - radius, center_y - radius,
                center_x + radius, center_y + radius
            ]
            vignette_draw.ellipse(bbox, fill=(0, 0, 0, alpha))

    # Composite vignette over darkened image
    img_rgba = img.convert('RGBA')
    img_rgba = Image.alpha_composite(img_rgba, vignette)

    print(f"DEBUG: Applied hook effects (darken={darken_amount}, vignette)")
    return img_rgba.convert('RGB')


def draw_divider_with_branding(draw, y_position, text="@factsmind"):
    """
    Draw decorative divider line with integrated branding text.
    Format: ──────── @factsmind ────────
    """
    try:
        font = ImageFont.truetype(FONT_REGULAR, DIVIDER_FONT_SIZE)
    except:
        font = ImageFont.load_default()

    # Get text dimensions
    bbox = draw.textbbox((0, 0), text, font=font)
    text_width = bbox[2] - bbox[0]
    text_height = bbox[3] - bbox[1]

    # Calculate positions
    text_x = WIDTH // 2
    line_margin = 40  # Space between line and text
    line_start_x = line_margin
    line_end_x = WIDTH - line_margin
    line_left_end = text_x - (text_width // 2) - line_margin
    line_right_start = text_x + (text_width // 2) + line_margin

    # Draw left line
    draw.line([(line_start_x, y_position), (line_left_end, y_position)],
              fill=DIVIDER_COLOR, width=1)

    # Draw right line
    draw.line([(line_right_start, y_position), (line_end_x, y_position)],
              fill=DIVIDER_COLOR, width=1)

    # Draw centered text
    draw.text((text_x, y_position), text, fill=LIGHT_GRAY, font=font, anchor="mm")


def get_natural_line_breaks(text, font, max_width):
    """
    Smart text wrapping that breaks at natural points.
    Prevents orphaned words and maintains phrase integrity.
    """
    words = text.split()
    lines = []
    current_line = []

    # Natural break points (after these words, it's okay to break)
    break_words = {'why', 'how', 'what', 'when', 'where', 'the', 'and', 'or', 'but',
                   'in', 'on', 'at', 'to', 'for', 'with', 'from', 'by', 'of'}

    for word in words:
        test_line = ' '.join(current_line + [word])
        bbox = font.getbbox(test_line)
        width = bbox[2] - bbox[0]

        if width <= max_width:
            current_line.append(word)
        else:
            # Line is too long, need to break
            if current_line:
                lines.append(' '.join(current_line))
                current_line = [word]
            else:
                # Single word is too long, force it anyway
                lines.append(word)
                current_line = []

    # Add remaining words
    if current_line:
        lines.append(' '.join(current_line))

    # Prevent orphaned single word on last line by rebalancing
    if len(lines) > 1 and len(lines[-1].split()) == 1:
        # Move one word from second-to-last line to last line
        if len(lines[-2].split()) > 2:
            words_prev = lines[-2].split()
            lines[-2] = ' '.join(words_prev[:-1])
            lines[-1] = words_prev[-1] + ' ' + lines[-1]

    return lines


def apply_subtle_emphasis(text):
    """
    Identify key words that should get subtle emphasis.
    Returns list of (word, is_emphasized) tuples.
    """
    words = text.split()
    emphasized = []

    for word in words:
        # Remove punctuation for checking
        clean_word = re.sub(r'[^\w\s]', '', word.lower())
        is_key = clean_word in EMPHASIS_WORDS or words.index(word) == 0  # First word or key word
        emphasized.append((word, is_key))

    return emphasized


def draw_smart_text(draw, text, y_start, font_size, emphasis_size, max_width, color, font_path, is_bold=True):
    """
    Draw text with smart line breaks, proper spacing, and subtle emphasis.
    Returns tuple: (end_y_position, line_count) for dynamic spacing calculations.
    """
    try:
        base_font = ImageFont.truetype(font_path, font_size)
        emphasis_font = ImageFont.truetype(font_path, emphasis_size)
        print(f"DEBUG: Loaded font {font_path} at size {font_size}")
    except Exception as e:
        print(f"ERROR: Failed to load font {font_path}: {e}")
        print("ERROR: Falling back to default font (will be tiny!)")
        base_font = ImageFont.load_default()
        emphasis_font = ImageFont.load_default()

    # Get natural line breaks
    lines = get_natural_line_breaks(text, base_font, max_width)
    line_count = len(lines)

    # Debug: print what lines we got
    print(f"DEBUG: Rendering text '{text[:30]}...' in {line_count} lines: {lines}")

    current_y = y_start

    for line in lines:
        # Check if line has emphasized words
        word_data = apply_subtle_emphasis(line)

        # For simplicity, if any word is emphasized, we'll draw word by word
        # Otherwise, draw the whole line at once
        has_emphasis = any(is_key for _, is_key in word_data)

        # Always draw entire line centered (emphasis disabled - was causing text jumping)
        draw.text((WIDTH // 2, current_y), line, fill=color, font=base_font, anchor="mt")

        # Move to next line
        current_y += int(font_size * LINE_HEIGHT_RATIO)

    return (current_y, line_count)


# ============================================================================
# MAIN COMPOSITION LOGIC
# ============================================================================

def main():
    # Debug: print all arguments
    print(f"DEBUG: Received {len(sys.argv)} arguments: {sys.argv}")

    # Parse command line arguments
    slide_num = int(sys.argv[1])
    slide_type = sys.argv[2]

    # Join all remaining arguments - they got split by docker exec
    # Use "~~~" as separator between title and subtitle
    all_text = ' '.join(sys.argv[3:])

    print(f"DEBUG: Joined text: '{all_text}'")

    if '~~~' in all_text:
        # Separator found - split on it
        title, subtitle = all_text.split('~~~', 1)
        title = title.strip()
        subtitle = subtitle.strip()
    else:
        # No separator - treat everything as title
        title = all_text
        subtitle = ""

    print(f"DEBUG: Title='{title}' ({len(title.split())} words)")
    print(f"DEBUG: Subtitle='{subtitle}' ({len(subtitle.split())} words)")

    # Slide 5 (CTA) uses template - keep legacy behavior
    if slide_num == 5:
        template_map = {
            "cta": "template_call_to_action.png"
        }
        template_file = template_map.get(slide_type, "template_call_to_action.png")
        template = Image.open(f"/data/templates/{template_file}")

        # For CTA, just add text to template (no image)
        draw = ImageDraw.Draw(template)
        try:
            title_font = ImageFont.truetype(FONT_BOLD, 90)
            subtitle_font = ImageFont.truetype(FONT_REGULAR, 43)
        except:
            title_font = ImageFont.load_default()
            subtitle_font = ImageFont.load_default()

        draw.text((540, 975), title, fill=WHITE, font=title_font, anchor="mm")
        draw.text((540, 1100), subtitle, fill=LIGHT_GRAY, font=subtitle_font, anchor="mm")

        # Save final output
        os.makedirs("/data/outputs/final", exist_ok=True)
        template.save(f"/data/outputs/final/slide_{slide_num}_final.png")
        print(f"Saved to /data/outputs/final/slide_{slide_num}_final.png")
        return

    # ========================================================================
    # SLIDE 1: HOOK (Special layout - centered text, no divider/branding)
    # ========================================================================
    if slide_num == 1:
        # Step 1: Create dark background
        canvas = create_base_background()

        # Step 2: Load and process hook image
        gen_img_path = f"/data/outputs/slide_{slide_num}.png"
        print(f"DEBUG: Looking for hook image at: {gen_img_path}")

        if os.path.exists(gen_img_path) and os.path.getsize(gen_img_path) > 0:
            print(f"DEBUG: Hook image found, size: {os.path.getsize(gen_img_path)} bytes")

            # For hook: resize to fill entire canvas (not just width)
            ai_image = Image.open(gen_img_path)
            print(f"DEBUG: Original hook image size: {ai_image.size}")

            # Calculate scale to cover entire canvas (use larger dimension)
            scale_x = WIDTH / ai_image.width
            scale_y = HEIGHT / ai_image.height
            scale = max(scale_x, scale_y)  # Use max to ensure full coverage

            new_width = int(ai_image.width * scale)
            new_height = int(ai_image.height * scale)
            ai_image = ai_image.resize((new_width, new_height), Image.Resampling.LANCZOS)

            # Center crop to exact canvas size
            left = (new_width - WIDTH) // 2
            top = (new_height - HEIGHT) // 2
            ai_image = ai_image.crop((left, top, left + WIDTH, top + HEIGHT))

            print(f"DEBUG: Hook image scaled and cropped to: {ai_image.size}")

            # Apply hook-specific effects (darken + vignette)
            ai_image = apply_hook_effects(ai_image, HOOK_IMAGE_DARKEN)

            # Apply fade starting from HOOK_FADE_START
            ai_image_faded = apply_fade_to_image(ai_image, HOOK_FADE_START)

            # Paste at 0,0 (full canvas coverage)
            canvas_rgba = canvas.convert('RGBA')
            canvas_rgba.paste(ai_image_faded, (0, 0), ai_image_faded)
            canvas = canvas_rgba.convert('RGB')
            print(f"DEBUG: Hook image pasted with effects at (0, 0) - FULL CANVAS")
        else:
            print(f"Warning: Hook image missing: {gen_img_path}")

        # Step 3: Draw centered hook text (no divider, no branding)
        draw = ImageDraw.Draw(canvas)

        try:
            hook_font = ImageFont.truetype(FONT_BOLD, HOOK_FONT_SIZE)
        except:
            hook_font = ImageFont.load_default()

        # Get natural line breaks for hook text
        lines = get_natural_line_breaks(title, hook_font, HOOK_MAX_WIDTH)
        print(f"DEBUG: Hook text in {len(lines)} lines: {lines}")

        # Draw centered hook text
        current_y = HOOK_TEXT_Y
        for line in lines:
            draw.text((WIDTH // 2, current_y), line, fill=WHITE, font=hook_font, anchor="mm")
            current_y += int(HOOK_FONT_SIZE * 1.2)  # Tighter line spacing

        # Step 4: Draw CTA at bottom center
        try:
            cta_font = ImageFont.truetype(FONT_REGULAR, HOOK_CTA_SIZE)
        except:
            cta_font = ImageFont.load_default()

        cta_text = "TAP TO DISCOVER →"
        draw.text((WIDTH // 2, HOOK_CTA_Y), cta_text,
                  fill=(180, 180, 180), font=cta_font, anchor="mm")

        # Step 5: Save hook slide
        os.makedirs("/data/outputs/final", exist_ok=True)
        canvas.save(f"/data/outputs/final/slide_{slide_num}_final.png")
        print(f"Saved hook slide to /data/outputs/final/slide_{slide_num}_final.png")
        return

    # ========================================================================
    # SLIDES 2-4: REVEAL (Standard layout with divider + branding)
    # ========================================================================

    # Step 1: Create dark background
    canvas = create_base_background()

    # Step 2: Load and paste AI-generated image (if exists)
    gen_img_path = f"/data/outputs/slide_{slide_num}.png"
    print(f"DEBUG: Looking for image at: {gen_img_path}")

    if os.path.exists(gen_img_path) and os.path.getsize(gen_img_path) > 0:
        print(f"DEBUG: Image found, size: {os.path.getsize(gen_img_path)} bytes")
        ai_image = load_and_resize_image(gen_img_path, WIDTH)
        if ai_image:
            print(f"DEBUG: AI image loaded and resized to: {ai_image.size}")

            # Calculate where fade should start on the image itself
            # Image is pasted at IMAGE_Y_OFFSET (-150), fade starts at IMAGE_FADE_START (1400)
            # So fade starts at: IMAGE_FADE_START - IMAGE_Y_OFFSET = 1400 - (-150) = 1550 pixels from top of image
            fade_start_on_image = IMAGE_FADE_START - IMAGE_Y_OFFSET

            # Apply fade to the image BEFORE pasting it
            ai_image_faded = apply_fade_to_image(ai_image, fade_start_on_image)

            print(f"DEBUG: Canvas size before paste: {canvas.size}")
            # Paste faded image with Y offset (move upwards)
            # Need to use RGBA canvas temporarily for transparency
            canvas_rgba = canvas.convert('RGBA')
            canvas_rgba.paste(ai_image_faded, (0, IMAGE_Y_OFFSET), ai_image_faded)  # Use image as mask
            canvas = canvas_rgba.convert('RGB')
            print(f"DEBUG: Faded image pasted at (0, {IMAGE_Y_OFFSET})")
        else:
            print(f"WARNING: Failed to load/resize image")
    else:
        print(f"Warning: Image file missing or empty: {gen_img_path}")
        print("Continuing with background only...")

    # Step 3: Draw divider line with @factsmind branding
    draw = ImageDraw.Draw(canvas)
    draw_divider_with_branding(draw, DIVIDER_Y)

    # Step 4: Draw title with smart text rendering
    title_end_y, title_lines = draw_smart_text(
        draw,
        title,
        TITLE_Y,
        TITLE_FONT_SIZE,
        TITLE_EMPHASIS_SIZE,
        TEXT_MAX_WIDTH,
        WHITE,
        FONT_BOLD,
        is_bold=True
    )

    print(f"DEBUG: Title has {title_lines} lines, ends at Y={title_end_y}")

    # Step 5: Calculate dynamic subtitle offset based on line count
    # We need to check subtitle line count BEFORE rendering to position it correctly
    # So we pre-calculate the line count
    try:
        temp_font = ImageFont.truetype(FONT_REGULAR, SUBTITLE_FONT_SIZE)
    except:
        temp_font = ImageFont.load_default()

    subtitle_lines_preview = len(get_natural_line_breaks(subtitle, temp_font, TEXT_MAX_WIDTH))

    # Dynamic spacing based on subtitle line count
    if subtitle_lines_preview <= 2:
        dynamic_offset = 50   # More space for short subtitles
    elif subtitle_lines_preview == 3:
        dynamic_offset = 35   # Perfect spacing (current setting)
    elif subtitle_lines_preview == 4:
        dynamic_offset = 25   # Closer for 4 lines (target length)
    else:  # 5+ lines
        dynamic_offset = 20   # Very tight for edge cases

    print(f"DEBUG: Subtitle preview: {subtitle_lines_preview} lines -> using offset {dynamic_offset}px")

    subtitle_y = title_end_y + dynamic_offset

    # Step 6: Draw subtitle with dynamic spacing
    subtitle_end_y, subtitle_lines = draw_smart_text(
        draw,
        subtitle,
        subtitle_y,
        SUBTITLE_FONT_SIZE,
        SUBTITLE_FONT_SIZE,  # No emphasis for subtitle
        TEXT_MAX_WIDTH,
        LIGHT_GRAY,
        FONT_REGULAR,
        is_bold=False
    )

    print(f"DEBUG: Subtitle has {subtitle_lines} lines, ends at Y={subtitle_end_y}")

    # Step 7: Add "SWIPE >>>" indicator in bottom right
    try:
        swipe_font = ImageFont.truetype(FONT_REGULAR, 20)  # Small font
    except:
        swipe_font = ImageFont.load_default()

    swipe_text = "SWIPE >>>"
    # Position in bottom right corner (50px from right edge)
    draw.text((WIDTH - 50, SWIPE_INDICATOR_Y), swipe_text,
              fill=(150, 150, 150), font=swipe_font, anchor="rm")

    # Step 8: Save final output
    os.makedirs("/data/outputs/final", exist_ok=True)
    canvas.save(f"/data/outputs/final/slide_{slide_num}_final.png")
    print(f"Saved to /data/outputs/final/slide_{slide_num}_final.png")


if __name__ == "__main__":
    main()
