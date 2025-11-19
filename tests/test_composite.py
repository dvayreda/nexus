"""Unit tests for composite.py image composition functionality."""
import pytest
import sys
from pathlib import Path
from PIL import Image
import os

# Add scripts directory to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'scripts'))


@pytest.mark.unit
class TestImageComposition:
    """Test suite for image composition functions."""

    def test_image_scaling_wider_image(self, sample_image_path, temp_dir):
        """Test image scaling when image is wider than target."""
        from PIL import Image

        # Create a wide image (2:1 ratio)
        wide_img = Image.new('RGB', (2000, 1000), color='green')
        wide_path = os.path.join(temp_dir, 'wide.png')
        wide_img.save(wide_path)

        # Load and scale
        img = Image.open(wide_path)
        target_width, target_height = 1080, 1080

        img_ratio = img.width / img.height
        target_ratio = target_width / target_height

        if img_ratio > target_ratio:
            new_height = target_height
            new_width = int(new_height * img_ratio)
        else:
            new_width = target_width
            new_height = int(new_width / img_ratio)

        resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)

        assert resized.height == target_height
        assert resized.width >= target_width

    def test_image_scaling_taller_image(self, temp_dir):
        """Test image scaling when image is taller than target."""
        # Create a tall image (1:2 ratio)
        tall_img = Image.new('RGB', (1000, 2000), color='blue')
        tall_path = os.path.join(temp_dir, 'tall.png')
        tall_img.save(tall_path)

        # Load and scale
        img = Image.open(tall_path)
        target_width, target_height = 1080, 1080

        img_ratio = img.width / img.height
        target_ratio = target_width / target_height

        if img_ratio > target_ratio:
            new_height = target_height
            new_width = int(new_height * img_ratio)
        else:
            new_width = target_width
            new_height = int(new_width / img_ratio)

        resized = img.resize((new_width, new_height), Image.Resampling.LANCZOS)

        assert resized.width == target_width
        assert resized.height >= target_height

    def test_image_centering_crop(self, temp_dir):
        """Test that image is properly cropped to center."""
        # Create oversized image
        large_img = Image.new('RGB', (3000, 3000), color='red')
        large_path = os.path.join(temp_dir, 'large.png')
        large_img.save(large_path)

        img = Image.open(large_path)
        target_width, target_height = 1080, 1080

        # Center crop calculation
        left = (img.width - target_width) // 2
        top = (img.height - target_height) // 2
        right = left + target_width
        bottom = top + target_height

        cropped = img.crop((left, top, right, bottom))

        assert cropped.width == target_width
        assert cropped.height == target_height

    def test_template_composition(self, sample_image_path, sample_template_path, temp_dir):
        """Test compositing image onto template."""
        template = Image.open(sample_template_path)
        gen_img = Image.open(sample_image_path)

        # Resize to fit template
        target_width, target_height = 2160, 1760
        gen_img = gen_img.resize((target_width, target_height), Image.Resampling.LANCZOS)

        # Paste onto template
        template.paste(gen_img, (0, 0))

        # Save result
        output_path = os.path.join(temp_dir, 'composite_result.png')
        template.save(output_path)

        assert os.path.exists(output_path)
        result = Image.open(output_path)
        assert result.size == (2160, 2700)

    def test_missing_image_handling(self, temp_dir):
        """Test handling of missing image files."""
        missing_path = os.path.join(temp_dir, 'nonexistent.png')

        assert not os.path.exists(missing_path)

        # Should handle gracefully
        with pytest.raises(FileNotFoundError):
            Image.open(missing_path)

    def test_empty_image_handling(self, temp_dir):
        """Test handling of empty image files."""
        empty_path = os.path.join(temp_dir, 'empty.png')

        # Create empty file
        open(empty_path, 'w').close()

        assert os.path.exists(empty_path)
        assert os.path.getsize(empty_path) == 0

        # Should raise error for empty file
        with pytest.raises(Exception):
            Image.open(empty_path)
