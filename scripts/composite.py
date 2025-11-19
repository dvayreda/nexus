#!/usr/bin/env python3
from PIL import Image, ImageDraw, ImageFont, ImageEnhance
import sys
import os
import re

# ============================================================================
# CONFIGURATION & CONSTANTS
# ============================================================================

# Brand Colors - FactsMind Official Style Guide
ELECTRIC_BLUE = (58, 175, 255)    # #3AAFFF - Primary accent
CYAN_GLOW = (117, 232, 255)       # #75E8FF - Secondary glow
SOFT_WHITE = (232, 232, 232)      # #E8E8E8 - Primary text
NEBULA_PURPLE = (72, 42, 110)     # #482A6E - Background gradient
DIVIDER_COLOR = SOFT_WHITE        # Use soft white to match text

# Canvas Dimensions (1x Instagram native resolution - matches 1024x1024 images)
WIDTH = 1080
HEIGHT = 1350

# Layout Configuration - Slides 2-4
IMAGE_Y_OFFSET = -75          # Move image upwards (negative = up)
DIVIDER_Y = 800               # Divider line position (moved up 50px for tighter layout)
IMAGE_FADE_START = 650        # Where fade starts on canvas (moved up 50px)
TITLE_Y = 875                 # Title starting position (moved up 50px)
SUBTITLE_Y_OFFSET = 35        # Gap from title end to subtitle start (tighter spacing)
TEXT_MAX_WIDTH = 950          # Max text width (65px margins on each side)
SWIPE_INDICATOR_Y = 1300      # Y position for "SWIPE >>>" indicator (50px from bottom) - more cornered

# Layout Configuration - Slide 1 (Hook)
HOOK_TEXT_Y = 575             # 42.5% from top (575/1350) - slight upward tension
HOOK_FONT_SIZE = 110          # Large, impactful hook text (increased from 95)
HOOK_MAX_WIDTH = 900          # Slightly narrower for centered text
HOOK_CTA_Y = 1250             # CTA position (100px from bottom)
HOOK_CTA_SIZE = 50            # Large, readable CTA (increased from 38)
HOOK_IMAGE_DARKEN = 0.7       # Darken image to 70% brightness for more contrast
HOOK_FADE_START = 500         # Start fade earlier for softer transition

# Typography
TITLE_FONT_SIZE = 65          # Halved
TITLE_EMPHASIS_SIZE = 68      # +3px for subtle emphasis on key words (disabled for now)
SUBTITLE_FONT_SIZE = 40       # Halved
DIVIDER_FONT_SIZE = 30        # Halved for visibility
SWIPE_FONT_SIZE = 24          # Reduced from 28 for subtlety
LINE_HEIGHT_RATIO = 1.3       # Spacing between lines (unchanged)

# Visual Effects
TEXT_SHADOW_COLOR = (0, 0, 0, 180)      # Black with 70% opacity (180/255)
TEXT_SHADOW_OFFSET = (3, 3)             # 3px offset
TEXT_SHADOW_BLUR = 12                    # 12px blur radius
LOGO_HALO_SIZE = 40                      # Halo radius around logo (reduced for subtlety)
LOGO_HALO_MAX_ALPHA = 80                 # Max halo opacity (reduced from 200 for subtlety)
LOGO_OPACITY = 0.6                       # Logo opacity on slides 2-4 (0.6 = 60% to reduce competition with title)
VIGNETTE_STRENGTH = 0.3                  # Vignette darkness for images (0-1)
FINAL_VIGNETTE_STRENGTH = 0.2            # Final canvas vignette for focal effect (lighter than image vignette)
SLIDE_5_BLUR_RADIUS = 8                  # Gaussian blur radius for slide 5 background (text readability) - DISABLED
SLIDE_5_LINE1_SIZE = 55                  # "This is just" - smaller intro
SLIDE_5_LINE2_SIZE = 95                  # "THE BEGINNING" - large emphasis
SLIDE_5_LINE3_SIZE = 65                  # "Follow @factsmind" - CTA (same as title size)
SLIDE_5_LINE4_SIZE = 48                  # "Endless discoveries await" - supporting text (bigger)
SLIDE_5_TEXT_Y_START = 510               # Starting Y position for lines 1-2 (moved 15% up from 600)
SLIDE_5_LINE3_Y = 808                    # Y position for line 3 (moved 15% up from 950)

# Font Paths - FactsMind Official Typography (Montserrat)
FONT_TITLE = "/data/fonts/Montserrat-ExtraBold.ttf"    # Titles: Montserrat ExtraBold
FONT_BODY = "/data/fonts/Montserrat-Regular.ttf"       # Body text: Montserrat Regular
FONT_HANDLE = "/data/fonts/Montserrat-SemiBold.ttf"    # Handle/branding: Montserrat SemiBold

# Keywords that might get subtle emphasis (barely perceptible)
EMPHASIS_WORDS = {'why', 'how', 'what', 'when', 'where', 'never', 'always', 'secret', 'truth'}


# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

def create_base_background():
    """Create dark background with subtle purple gradient at bottom"""
    # Start with dark navy base
    DARK_NAVY = (2, 3, 8)
    background = Image.new('RGB', (WIDTH, HEIGHT), DARK_NAVY)
    draw = ImageDraw.Draw(background)

    # Add VERY subtle purple gradient at bottom 20%
    gradient_start_y = int(HEIGHT * 0.8)  # Start at 80% down
    gradient_height = HEIGHT - gradient_start_y

    for i in range(gradient_height):
        y = gradient_start_y + i
        # Very subtle blend (max 15% opacity of purple)
        ratio = (i / gradient_height) * 0.15

        r = int(DARK_NAVY[0] + (NEBULA_PURPLE[0] - DARK_NAVY[0]) * ratio)
        g = int(DARK_NAVY[1] + (NEBULA_PURPLE[1] - DARK_NAVY[1]) * ratio)
        b = int(DARK_NAVY[2] + (NEBULA_PURPLE[2] - DARK_NAVY[2]) * ratio)

        draw.line([(0, y), (WIDTH, y)], fill=(r, g, b))

    return background


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


def apply_vignette(image, strength=VIGNETTE_STRENGTH):
    """Add subtle vignette (darkened edges) to image for professional look"""
    # Create radial gradient mask
    width, height = image.size
    vignette = Image.new('L', (width, height), 0)
    draw = ImageDraw.Draw(vignette)

    # Create radial gradient from center
    center_x, center_y = width // 2, height // 2
    max_radius = max(width, height) // 2

    for y in range(height):
        for x in range(width):
            # Distance from center
            dist = ((x - center_x)**2 + (y - center_y)**2)**0.5
            # Normalize distance (0 at center, 1 at edges)
            norm_dist = min(dist / max_radius, 1.0)
            # Apply strength curve (power of 2 for smooth falloff)
            alpha = int(255 * (1 - strength * (norm_dist ** 2)))
            vignette.putpixel((x, y), alpha)

    # Apply vignette as overlay
    darkened = ImageEnhance.Brightness(image).enhance(1.0)
    result = Image.composite(image, ImageEnhance.Brightness(image).enhance(1 - strength), vignette)

    return result


def apply_final_vignette(canvas, strength=FINAL_VIGNETTE_STRENGTH):
    """
    Apply subtle vignette to entire final canvas for more focal view.
    Creates radial gradient overlay that darkens edges while keeping center bright.
    """
    # Create RGBA overlay with transparent center
    overlay = Image.new('RGBA', (WIDTH, HEIGHT), (0, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)

    center_x, center_y = WIDTH // 2, HEIGHT // 2
    max_radius = int((WIDTH ** 2 + HEIGHT ** 2) ** 0.5 / 2)

    # Draw radial gradient (darker at edges, transparent at center)
    for radius in range(max_radius, 0, -20):
        # Alpha increases as we move away from center (transparent center, dark edges)
        # Using power of 2 for smooth falloff
        norm_dist = 1 - (radius / max_radius)
        alpha = int(255 * strength * (norm_dist ** 2))
        if alpha > 0:
            bbox = [
                center_x - radius, center_y - radius,
                center_x + radius, center_y + radius
            ]
            draw.ellipse(bbox, fill=(0, 0, 0, alpha))

    # Composite overlay onto canvas
    canvas_rgba = canvas.convert('RGBA')
    result = Image.alpha_composite(canvas_rgba, overlay)

    print(f"DEBUG: Applied final canvas vignette (strength={strength})")
    return result.convert('RGB')


def draw_text_with_shadow(draw, position, text, font, fill, shadow=True):
    """Draw text with drop shadow for better readability"""
    if shadow:
        # Draw shadow (offset multiple times for blur effect)
        shadow_x, shadow_y = TEXT_SHADOW_OFFSET
        for offset in range(TEXT_SHADOW_BLUR // 3):
            draw.text(
                (position[0] + shadow_x, position[1] + shadow_y),
                text,
                font=font,
                fill=TEXT_SHADOW_COLOR,
                anchor=position[2] if len(position) > 2 else None
            )

    # Draw main text
    draw.text(position, text, font=font, fill=fill, anchor=position[2] if len(position) > 2 else None)


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


def draw_divider_with_branding(canvas, y_position):
    """
    Draw decorative divider line with integrated FactsMind logo.
    Format: ──────── [LOGO] ────────
    """
    draw = ImageDraw.Draw(canvas)

    # Load and resize logo
    logo_path = "/data/scripts/factsmind_logo.png"
    logo_height = 70  # Target height in pixels (increased from 60 for better visibility)

    try:
        logo = Image.open(logo_path).convert('RGBA')
        # Maintain aspect ratio
        aspect_ratio = logo.width / logo.height
        logo_width = int(logo_height * aspect_ratio)
        logo = logo.resize((logo_width, logo_height), Image.Resampling.LANCZOS)

        # Calculate positions
        logo_x = (WIDTH - logo_width) // 2
        logo_y = y_position - (logo_height // 2)

        line_margin = 40  # Space between line and logo
        line_start_x = line_margin
        line_end_x = WIDTH - line_margin
        line_left_end = logo_x - line_margin
        line_right_start = logo_x + logo_width + line_margin

        # Draw left line
        draw.line([(line_start_x, y_position), (line_left_end, y_position)],
                  fill=DIVIDER_COLOR, width=1)

        # Draw right line
        draw.line([(line_right_start, y_position), (line_end_x, y_position)],
                  fill=DIVIDER_COLOR, width=1)

        # Draw spherical black gradient halo behind logo
        halo_overlay = Image.new('RGBA', (WIDTH, HEIGHT), (0, 0, 0, 0))
        halo_draw = ImageDraw.Draw(halo_overlay)

        center_x = logo_x + logo_width // 2
        center_y = logo_y + logo_height // 2

        # Draw radial gradient (black in center fading to transparent)
        for radius in range(LOGO_HALO_SIZE, 0, -1):
            # Alpha decreases as radius increases (opaque in center, transparent at edge)
            alpha = int(LOGO_HALO_MAX_ALPHA * (1 - radius / LOGO_HALO_SIZE))
            halo_draw.ellipse(
                [center_x - radius, center_y - radius, center_x + radius, center_y + radius],
                fill=(0, 0, 0, alpha)
            )

        # Composite halo onto canvas
        canvas = Image.alpha_composite(canvas.convert('RGBA'), halo_overlay).convert('RGB')

        # Reduce logo opacity to avoid competing with title
        logo_with_opacity = logo.copy()
        alpha = logo_with_opacity.split()[3]  # Get alpha channel
        alpha = alpha.point(lambda p: int(p * LOGO_OPACITY))  # Reduce opacity
        logo_with_opacity.putalpha(alpha)

        # Paste logo (with reduced opacity)
        canvas_rgba = canvas.convert('RGBA')
        canvas_rgba.paste(logo_with_opacity, (logo_x, logo_y), logo_with_opacity)
        canvas = canvas_rgba.convert('RGB')

        print(f"DEBUG: Logo with halo placed at ({logo_x}, {logo_y}), size: {logo_width}x{logo_height}, opacity: {LOGO_OPACITY}")

    except Exception as e:
        print(f"WARNING: Could not load logo ({e}), falling back to text")
        # Fallback to text if logo fails
        try:
            font = ImageFont.truetype(FONT_HANDLE, DIVIDER_FONT_SIZE)
        except:
            font = ImageFont.load_default()

        text = "@factsmind"
        draw.text((WIDTH // 2, y_position), text, fill=CYAN_GLOW, font=font, anchor="mm")

    return canvas


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


def draw_smart_text(draw, text, y_start, font_size, emphasis_size, max_width, color, font_path, is_bold=True, shadow=True):
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

        # Always draw entire line centered with shadow (emphasis disabled - was causing text jumping)
        draw_text_with_shadow(
            draw,
            (WIDTH // 2, current_y, "mt"),
            line,
            base_font,
            color,
            shadow=shadow
        )

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

    # ========================================================================
    # SLIDE 5: CTA (Same layout as slides 2-4, with blur and no swipe)
    # ========================================================================
    if slide_num == 5:
        # Step 1: Create dark background
        canvas = create_base_background()

        # Step 2: Load CTA background image at full size and 100% opacity
        cta_img_path = "/data/outputs/logo/slide_5_background.png"
        print(f"DEBUG: Looking for CTA background at: {cta_img_path}")

        if os.path.exists(cta_img_path) and os.path.getsize(cta_img_path) > 0:
            print(f"DEBUG: CTA image found, size: {os.path.getsize(cta_img_path)} bytes")

            # Load and resize to cover full slide at 100% opacity
            try:
                ai_image = Image.open(cta_img_path)
                print(f"DEBUG: Original CTA image size: {ai_image.size}")

                # Scale to cover entire canvas (use max to ensure full coverage)
                scale_x = WIDTH / ai_image.width
                scale_y = HEIGHT / ai_image.height
                scale = max(scale_x, scale_y)  # Use max to cover entire canvas

                new_width = int(ai_image.width * scale)
                new_height = int(ai_image.height * scale)
                ai_image = ai_image.resize((new_width, new_height), Image.Resampling.LANCZOS)

                # Center crop to exact canvas size
                left = (new_width - WIDTH) // 2
                top = (new_height - HEIGHT) // 2
                ai_image = ai_image.crop((left, top, left + WIDTH, top + HEIGHT))

                print(f"DEBUG: CTA image scaled and cropped to full canvas: {ai_image.size}")

                # NO darkening, NO fade - paste at 100% opacity covering full slide
                canvas = ai_image.convert('RGB')
                print(f"DEBUG: CTA image pasted at full slide, 100% opacity, no effects")

            except Exception as e:
                print(f"WARNING: Failed to load/resize CTA image: {e}")
        else:
            print(f"Warning: CTA image missing: {cta_img_path}")

        # Step 3: Create draw object for text
        draw = ImageDraw.Draw(canvas)

        # Step 4: Draw custom 4-line CTA text with different sizes
        try:
            line1_font = ImageFont.truetype(FONT_BODY, SLIDE_5_LINE1_SIZE)       # "This is just"
            line2_font = ImageFont.truetype(FONT_TITLE, SLIDE_5_LINE2_SIZE)      # "THE BEGINNING"
            line3_font = ImageFont.truetype(FONT_HANDLE, SLIDE_5_LINE3_SIZE)     # "Follow @factsmind"
            line4_font = ImageFont.truetype(FONT_BODY, SLIDE_5_LINE4_SIZE)       # "Endless discoveries await"
        except:
            line1_font = line2_font = line3_font = line4_font = ImageFont.load_default()

        # Define the 4 lines
        line1_text = "This is just"
        line2_text = "THE BEGINNING"
        line3_text = "Follow @factsmind"
        line4_text = "Endless discoveries await"

        # Calculate vertical spacing
        current_y = SLIDE_5_TEXT_Y_START

        # Line 1: "This is just" (smaller, regular)
        draw_text_with_shadow(
            draw,
            (WIDTH // 2, current_y, "mm"),
            line1_text,
            line1_font,
            SOFT_WHITE,
            shadow=True
        )
        current_y += int(SLIDE_5_LINE1_SIZE * 1.6)  # More spacing

        # Line 2: "THE BEGINNING" (large, bold)
        draw_text_with_shadow(
            draw,
            (WIDTH // 2, current_y, "mm"),
            line2_text,
            line2_font,
            SOFT_WHITE,
            shadow=True
        )

        # Line 3: "Follow @factsmind" - positioned at standard title position
        line3_y = SLIDE_5_LINE3_Y
        draw_text_with_shadow(
            draw,
            (WIDTH // 2, line3_y, "mm"),
            line3_text,
            line3_font,
            CYAN_GLOW,  # Use cyan for the @handle
            shadow=True
        )

        # Line 4: "Endless discoveries await" - positioned below line 3 with spacing
        line4_y = line3_y + int(SLIDE_5_LINE3_SIZE * 1.5)  # More spacing
        draw_text_with_shadow(
            draw,
            (WIDTH // 2, line4_y, "mm"),
            line4_text,
            line4_font,
            SOFT_WHITE,
            shadow=True
        )

        print(f"DEBUG: CTA custom 4-line text rendered")

        # Step 5: Apply final vignette to entire canvas for focal effect
        canvas = apply_final_vignette(canvas, FINAL_VIGNETTE_STRENGTH)

        # Step 6: Add centered logo (moved 200px up from bottom)
        logo_path = "/data/scripts/factsmind_logo.png"
        logo_height = 70  # Same size as divider logo
        logo_bottom_margin = 240  # Distance from bottom edge (200px higher than before)

        try:
            logo = Image.open(logo_path).convert('RGBA')
            # Maintain aspect ratio
            aspect_ratio = logo.width / logo.height
            logo_width = int(logo_height * aspect_ratio)
            logo = logo.resize((logo_width, logo_height), Image.Resampling.LANCZOS)

            # Calculate centered position at bottom
            logo_x = (WIDTH - logo_width) // 2
            logo_y = HEIGHT - logo_height - logo_bottom_margin

            # Paste logo (with alpha channel for transparency)
            canvas_rgba = canvas.convert('RGBA')
            canvas_rgba.paste(logo, (logo_x, logo_y), logo)
            canvas = canvas_rgba.convert('RGB')

            print(f"DEBUG: CTA logo placed at ({logo_x}, {logo_y}), size: {logo_width}x{logo_height}")

        except Exception as e:
            print(f"WARNING: Could not load logo for CTA slide ({e})")

        # Step 7: Save final output (NO swipe indicator for CTA slide)
        os.makedirs("/data/outputs/final", exist_ok=True)
        canvas.save(f"/data/outputs/final/slide_{slide_num}_final.png")
        print(f"Saved CTA slide to /data/outputs/final/slide_{slide_num}_final.png")
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
            hook_font = ImageFont.truetype(FONT_TITLE, HOOK_FONT_SIZE)
        except:
            hook_font = ImageFont.load_default()

        # Get natural line breaks for hook text
        lines = get_natural_line_breaks(title, hook_font, HOOK_MAX_WIDTH)
        print(f"DEBUG: Hook text in {len(lines)} lines: {lines}")

        # Calculate total hook text height for dynamic centering
        line_spacing = int(HOOK_FONT_SIZE * 1.2)
        total_hook_text_height = len(lines) * line_spacing

        # Calculate available vertical space for hook text
        hook_text_zone_start = 200  # Top margin
        hook_text_zone_end = HOOK_CTA_Y - 100  # End above CTA with margin
        available_hook_height = hook_text_zone_end - hook_text_zone_start

        # Center hook text block vertically
        vertical_hook_padding = (available_hook_height - total_hook_text_height) / 2
        dynamic_hook_y = int(hook_text_zone_start + vertical_hook_padding)

        print(f"DEBUG: Hook dynamic centering - Lines: {len(lines)}, Total height: {total_hook_text_height}px")
        print(f"DEBUG: Centered HOOK_Y: {dynamic_hook_y} (was {HOOK_TEXT_Y})")

        # Draw centered hook text with shadow at dynamically centered position
        current_y = dynamic_hook_y
        for line in lines:
            draw_text_with_shadow(
                draw,
                (WIDTH // 2, current_y, "mm"),
                line,
                hook_font,
                SOFT_WHITE,
                shadow=True
            )
            current_y += line_spacing

        # Step 4: Draw CTA at bottom center
        try:
            cta_font = ImageFont.truetype(FONT_BODY, HOOK_CTA_SIZE)
        except:
            cta_font = ImageFont.load_default()

        cta_text = "TAP TO DISCOVER →"
        draw_text_with_shadow(
            draw,
            (WIDTH // 2, HOOK_CTA_Y, "mm"),
            cta_text,
            cta_font,
            CYAN_GLOW,  # Changed from gray to cyan glow for more visibility
            shadow=True
        )

        # Step 5: Apply final vignette to entire canvas for focal effect
        canvas = apply_final_vignette(canvas, FINAL_VIGNETTE_STRENGTH)

        # Step 6: Save hook slide
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

            # Apply subtle vignette to image for professional look
            ai_image = apply_vignette(ai_image, VIGNETTE_STRENGTH)
            print(f"DEBUG: Vignette applied to image")

            # Calculate where fade should start on the image itself
            # Image is pasted at IMAGE_Y_OFFSET (-75), fade starts at IMAGE_FADE_START (700)
            # So fade starts at: IMAGE_FADE_START - IMAGE_Y_OFFSET = 700 - (-75) = 775 pixels from top of image
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

    # Step 3: Draw divider line with FactsMind logo (with halo effect)
    canvas = draw_divider_with_branding(canvas, DIVIDER_Y)
    draw = ImageDraw.Draw(canvas)

    # Step 3.5: Pre-calculate text heights for dynamic vertical centering
    # This ensures balanced layout regardless of content length
    try:
        temp_title_font = ImageFont.truetype(FONT_TITLE, TITLE_FONT_SIZE)
        temp_subtitle_font = ImageFont.truetype(FONT_BODY, SUBTITLE_FONT_SIZE)
    except:
        temp_title_font = ImageFont.load_default()
        temp_subtitle_font = ImageFont.load_default()

    # Pre-calculate line counts
    title_lines_preview = len(get_natural_line_breaks(title, temp_title_font, TEXT_MAX_WIDTH))
    subtitle_lines_preview = len(get_natural_line_breaks(subtitle, temp_subtitle_font, TEXT_MAX_WIDTH))

    # Calculate dynamic spacing based on subtitle line count
    if subtitle_lines_preview <= 2:
        dynamic_offset = 50   # More space for short subtitles
    elif subtitle_lines_preview == 3:
        dynamic_offset = 35   # Perfect spacing (current setting)
    elif subtitle_lines_preview == 4:
        dynamic_offset = 25   # Closer for 4 lines (target length)
    else:  # 5+ lines
        dynamic_offset = 20   # Very tight for edge cases

    # Calculate total text block height
    title_height = title_lines_preview * (TITLE_FONT_SIZE * LINE_HEIGHT_RATIO)
    subtitle_height = subtitle_lines_preview * (SUBTITLE_FONT_SIZE * LINE_HEIGHT_RATIO)
    total_text_height = title_height + dynamic_offset + subtitle_height

    # Calculate available vertical space for text
    text_zone_start = DIVIDER_Y + 75  # Start below divider with margin
    text_zone_end = SWIPE_INDICATOR_Y - 20  # End above swipe with margin
    available_height = text_zone_end - text_zone_start

    # Center text block vertically in available space
    vertical_padding = (available_height - total_text_height) / 2
    dynamic_title_y = int(text_zone_start + vertical_padding)

    print(f"DEBUG: Dynamic centering - Title lines: {title_lines_preview}, Subtitle lines: {subtitle_lines_preview}")
    print(f"DEBUG: Total text height: {total_text_height}px, Available: {available_height}px")
    print(f"DEBUG: Centered TITLE_Y: {dynamic_title_y} (was {TITLE_Y})")

    # Step 4: Draw title with smart text rendering at dynamically centered position
    title_end_y, title_lines = draw_smart_text(
        draw,
        title,
        dynamic_title_y,  # Use calculated position instead of TITLE_Y
        TITLE_FONT_SIZE,
        TITLE_EMPHASIS_SIZE,
        TEXT_MAX_WIDTH,
        SOFT_WHITE,
        FONT_TITLE,
        is_bold=True
    )

    print(f"DEBUG: Title has {title_lines} lines, ends at Y={title_end_y}")

    # Step 5: Calculate subtitle position based on title end and dynamic offset
    subtitle_y = title_end_y + dynamic_offset

    # Step 6: Draw subtitle with dynamic spacing
    subtitle_end_y, subtitle_lines = draw_smart_text(
        draw,
        subtitle,
        subtitle_y,
        SUBTITLE_FONT_SIZE,
        SUBTITLE_FONT_SIZE,  # No emphasis for subtitle
        TEXT_MAX_WIDTH,
        SOFT_WHITE,
        FONT_BODY,
        is_bold=False
    )

    print(f"DEBUG: Subtitle has {subtitle_lines} lines, ends at Y={subtitle_end_y}")

    # Step 7: Apply final vignette to entire canvas for focal effect
    canvas = apply_final_vignette(canvas, FINAL_VIGNETTE_STRENGTH)
    # Need to recreate draw object after canvas modification
    draw = ImageDraw.Draw(canvas)

    # Step 8: Add "SWIPE >>>" indicator in bottom right
    try:
        swipe_font = ImageFont.truetype(FONT_BODY, SWIPE_FONT_SIZE)  # Reduced for subtlety
    except:
        swipe_font = ImageFont.load_default()

    swipe_text = "SWIPE >>>"
    # Position in bottom right corner (60px from right edge for cornered feel)
    draw_text_with_shadow(
        draw,
        (WIDTH - 60, SWIPE_INDICATOR_Y, "rm"),
        swipe_text,
        swipe_font,
        SOFT_WHITE,
        shadow=True
    )

    # Step 9: Save final output
    os.makedirs("/data/outputs/final", exist_ok=True)
    canvas.save(f"/data/outputs/final/slide_{slide_num}_final.png")
    print(f"Saved to /data/outputs/final/slide_{slide_num}_final.png")


if __name__ == "__main__":
    main()
