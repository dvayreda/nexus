from PIL import Image, ImageDraw, ImageFont
import os
import json
import argparse
from datetime import datetime

class CarouselRenderer:
    def __init__(self, width=1080, height=1080, font_path=None):
        self.width = width
        self.height = height
        self.font_path = font_path if font_path else "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" # Default font
        try:
            self.font = ImageFont.truetype(self.font_path, 40)
        except IOError:
            print(f"Warning: Default font not found at {self.font_path}. Using a generic font.")
            self.font = ImageFont.load_default()

    def create_slide(self, text: str, background_color=(255, 255, 255), text_color=(0, 0, 0)) -> Image.Image:
        img = Image.new('RGB', (self.width, self.height), color=background_color)
        d = ImageDraw.Draw(img)

        # Simple text wrapping and centering
        lines = []
        words = text.split()
        current_line = []
        for word in words:
            test_line = ' '.join(current_line + [word])
            if d.textbbox((0,0), test_line, font=self.font)[2] < self.width - 100: # 100px padding
                current_line.append(word)
            else:
                lines.append(' '.join(current_line))
                current_line = [word]
        lines.append(' '.join(current_line))

        y_text = (self.height - len(lines) * 50) / 2 # Center vertically, assuming 50px per line
        for line in lines:
            text_width = d.textbbox((0,0), line, font=self.font)[2]
            x_text = (self.width - text_width) / 2
            d.text((x_text, y_text), line, font=self.font, fill=text_color)
            y_text += 50 # Line height

        return img

    def render_carousel(self, slides_data: list[dict], output_dir: str = "/srv/outputs") -> list[str]:
        os.makedirs(output_dir, exist_ok=True)
        output_paths = []
        for i, slide_data in enumerate(slides_data):
            text = slide_data.get("text", f"Slide {i+1}")
            # You can extend this to handle image backgrounds, different colors, etc.
            slide_image = self.create_slide(text)
            output_path = os.path.join(output_dir, f"slide_{i+1}.png")
            print(f"Saving slide {i+1} to {output_path}")
            try:
                slide_image.save(output_path)
                print(f"Successfully saved {output_path}")
            except Exception as e:
                print(f"Failed to save {output_path}: {e}")
            output_paths.append(output_path)
        return output_paths

if __name__ == "__main__":
    renderer = CarouselRenderer()
    sample_slides = [
        {"text": "This is the first slide of our new AI-generated carousel content."}, 
        {"text": "Pillow allows us to programmatically create and manipulate images with Python."}, 
        {"text": "We can add text, shapes, and even integrate images from Pexels."}, 
        {"text": "This replaces the need for Canva's API for automated rendering."}, 
        {"text": "Excited to see the Nexus project come to life with this new capability!"}
    ]
    print("Rendering sample carousel...")
    rendered_files = renderer.render_carousel(sample_slides, output_dir="./output_carousels")
    print(f"Rendered files: {rendered_files}")
    print("Sample carousel rendering complete. Check the ./output_carousels directory.")
