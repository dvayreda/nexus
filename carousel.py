from PIL import Image, ImageDraw, ImageFont
import textwrap

def create_carousel_slide(text, image_path, output_path, slide_index, total_slides, font_path=None):
    # Load base image or create a blank one if no image_path is provided
    try:
        base_image = Image.open(image_path).convert("RGBA")
    except (FileNotFoundError, AttributeError):
        # Create a blank image if no valid path or file not found
        base_image = Image.new("RGBA", (1080, 1350), (255, 255, 255, 255)) # White background

    # Resize image to fit the carousel slide dimensions (1080x1350)
    base_image = base_image.resize((1080, 1350))

    draw = ImageDraw.Draw(base_image)

    # Define font and text color
    try:
        font = ImageFont.truetype(font_path or "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 40)
    except IOError:
        font = ImageFont.load_default()
        print("Warning: Custom font not found, using default font.")

    text_color = (0, 0, 0, 255)  # Black color

    # Wrap text to fit within the image width
    margin = 50
    max_width = base_image.width - 2 * margin
    wrapped_text = textwrap.fill(text, width=int(max_width / (font.getlength("A") / 2)))

    # Calculate text position (centered horizontally, top-aligned vertically)
    text_bbox = draw.textbbox((0,0), wrapped_text, font=font)
    text_width = text_bbox[2] - text_bbox[0]
    text_height = text_bbox[3] - text_bbox[0]
    
    x = (base_image.width - text_width) / 2
    y = margin # Start from top margin

    draw.text((x, y), wrapped_text, font=font, fill=text_color)

    # Add slide number at the bottom right
    slide_number_text = f"{slide_index}/{total_slides}"
    slide_number_font = ImageFont.truetype(font_path or "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 30)
    slide_number_bbox = draw.textbbox((0,0), slide_number_text, font=slide_number_font)
    slide_number_width = slide_number_bbox[2] - slide_number_bbox[0]
    slide_number_height = slide_number_bbox[3] - slide_number_bbox[0]

    draw.text((base_image.width - slide_number_width - margin, base_image.height - slide_number_height - margin), 
              slide_number_text, font=slide_number_font, fill=text_color)

    base_image.save(output_path)

if __name__ == "__main__":
    # Example Usage:
    sample_text = "This is a sample text for the carousel slide. It should be wrapped nicely within the image boundaries."
    sample_image_path = "/srv/projects/nexus/tests/sample_image.jpg" # Replace with a real image path or remove for blank
    output_slide_path = "/srv/outputs/carousel_slide_1.png"

    # Ensure the output directory exists
    import os
    os.makedirs(os.path.dirname(output_slide_path), exist_ok=True)

    create_carousel_slide(sample_text, sample_image_path, output_slide_path, 1, 5)
    print(f"Generated: {output_slide_path}")

    sample_text_2 = "Second slide with more content to test text wrapping and different image."
    output_slide_path_2 = "/srv/outputs/carousel_slide_2.png"
    create_carousel_slide(sample_text_2, None, output_slide_path_2, 2, 5) # No image, will create blank
    print(f"Generated: {output_slide_path_2}")


