"""Unit tests for carousel_renderer.py."""
import pytest
import sys
from pathlib import Path
from PIL import Image
import os

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))

from rendering.carousel_renderer import CarouselRenderer


@pytest.mark.unit
class TestCarouselRenderer:
    """Test suite for CarouselRenderer class."""

    def test_renderer_initialization_default(self):
        """Test renderer initialization with defaults."""
        renderer = CarouselRenderer()

        assert renderer.width == 1080
        assert renderer.height == 1080
        assert renderer.font is not None

    def test_renderer_initialization_custom_dimensions(self):
        """Test renderer with custom dimensions."""
        renderer = CarouselRenderer(width=1920, height=1080)

        assert renderer.width == 1920
        assert renderer.height == 1080

    def test_create_slide_basic(self):
        """Test basic slide creation."""
        renderer = CarouselRenderer()
        text = "Test slide content"

        slide = renderer.create_slide(text)

        assert isinstance(slide, Image.Image)
        assert slide.size == (1080, 1080)
        assert slide.mode == 'RGB'

    def test_create_slide_custom_colors(self):
        """Test slide creation with custom colors."""
        renderer = CarouselRenderer()
        text = "Colored slide"
        bg_color = (255, 0, 0)  # Red
        text_color = (255, 255, 255)  # White

        slide = renderer.create_slide(text, background_color=bg_color, text_color=text_color)

        assert isinstance(slide, Image.Image)
        # Check that red pixels exist in image
        pixels = list(slide.getdata())
        assert bg_color in pixels

    def test_create_slide_text_wrapping(self):
        """Test that long text is properly wrapped."""
        renderer = CarouselRenderer()
        long_text = "This is a very long text that should be wrapped " * 10

        slide = renderer.create_slide(long_text)

        assert isinstance(slide, Image.Image)
        assert slide.size == (1080, 1080)

    def test_render_carousel_single_slide(self, temp_dir, carousel_slides_data):
        """Test rendering single slide."""
        renderer = CarouselRenderer()
        single_slide = [carousel_slides_data[0]]

        output_paths = renderer.render_carousel(single_slide, output_dir=temp_dir)

        assert len(output_paths) == 1
        assert os.path.exists(output_paths[0])

        # Verify image is valid
        img = Image.open(output_paths[0])
        assert img.size == (1080, 1080)

    def test_render_carousel_multiple_slides(self, temp_dir, carousel_slides_data):
        """Test rendering multiple slides."""
        renderer = CarouselRenderer()

        output_paths = renderer.render_carousel(carousel_slides_data, output_dir=temp_dir)

        assert len(output_paths) == len(carousel_slides_data)

        for i, path in enumerate(output_paths):
            assert os.path.exists(path)
            assert f"slide_{i+1}.png" in path

            # Verify each image
            img = Image.open(path)
            assert img.size == (1080, 1080)

    def test_render_carousel_creates_output_directory(self, temp_dir):
        """Test that output directory is created if it doesn't exist."""
        renderer = CarouselRenderer()
        slides = [{"text": "Test"}]
        new_dir = os.path.join(temp_dir, "new_output")

        assert not os.path.exists(new_dir)

        output_paths = renderer.render_carousel(slides, output_dir=new_dir)

        assert os.path.exists(new_dir)
        assert len(output_paths) == 1

    def test_render_carousel_empty_slides(self, temp_dir):
        """Test rendering with empty slides list."""
        renderer = CarouselRenderer()

        output_paths = renderer.render_carousel([], output_dir=temp_dir)

        assert len(output_paths) == 0

    def test_font_fallback_on_missing_font(self):
        """Test that renderer falls back to default font if custom font missing."""
        renderer = CarouselRenderer(font_path="/nonexistent/font.ttf")

        # Should use default font and not crash
        assert renderer.font is not None

        slide = renderer.create_slide("Test")
        assert isinstance(slide, Image.Image)
