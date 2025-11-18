"""Integration tests for end-to-end carousel generation."""
import pytest
import sys
from pathlib import Path
from PIL import Image
import os
from unittest.mock import Mock, patch

# Add paths
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))
sys.path.insert(0, str(Path(__file__).parent.parent))


@pytest.mark.integration
class TestCarouselGenerationPipeline:
    """Test end-to-end carousel generation workflow."""

    def test_complete_carousel_generation(self, temp_dir, carousel_slides_data, mock_env_vars):
        """Test complete carousel generation from data to images."""
        from rendering.carousel_renderer import CarouselRenderer

        # Initialize renderer
        renderer = CarouselRenderer(width=1080, height=1080)

        # Generate carousel
        output_paths = renderer.render_carousel(carousel_slides_data, output_dir=temp_dir)

        # Verify outputs
        assert len(output_paths) == 5

        for i, path in enumerate(output_paths):
            # Check file exists
            assert os.path.exists(path)

            # Verify it's a valid image
            img = Image.open(path)
            assert img.size == (1080, 1080)
            assert img.mode == 'RGB'

            # Check file size is reasonable
            file_size = os.path.getsize(path)
            assert file_size > 1000  # At least 1KB

    @patch('src.api_clients.pexels_client.requests.get')
    def test_carousel_with_pexels_images(self, mock_get, temp_dir, mock_env_vars, mock_pexels_response):
        """Test carousel generation with Pexels image integration."""
        from api_clients.pexels_client import PexelsClient
        from rendering.carousel_renderer import CarouselRenderer

        # Setup Pexels mock
        mock_response = Mock()
        mock_response.json.return_value = mock_pexels_response
        mock_response.raise_for_status = Mock()
        mock_response.content = b'fake_image_data'
        mock_get.return_value = mock_response

        # Search for images
        pexels_client = PexelsClient()
        images = pexels_client.search_images("technology", per_page=3)

        assert len(images) > 0

        # Generate carousel slides
        slides = [{"text": f"Slide about technology {i+1}"} for i in range(3)]

        # Render carousel
        renderer = CarouselRenderer()
        output_paths = renderer.render_carousel(slides, output_dir=temp_dir)

        assert len(output_paths) == 3
        for path in output_paths:
            assert os.path.exists(path)

    @patch('src.api_clients.groq_client.Groq')
    def test_carousel_with_ai_content_generation(self, mock_groq_class, temp_dir, mock_env_vars):
        """Test carousel generation with AI-generated content."""
        from api_clients.groq_client import GroqClient
        from rendering.carousel_renderer import CarouselRenderer

        # Setup Groq mock
        mock_client = Mock()
        mock_responses = [
            Mock(choices=[Mock(message=Mock(content="AI-generated slide 1"))]),
            Mock(choices=[Mock(message=Mock(content="AI-generated slide 2"))]),
            Mock(choices=[Mock(message=Mock(content="AI-generated slide 3"))])
        ]
        mock_client.chat.completions.create.side_effect = mock_responses
        mock_groq_class.return_value = mock_client

        # Generate content with AI
        groq_client = GroqClient()
        slides = []
        for i in range(3):
            content = groq_client.generate_text(f"Generate slide {i+1} about AI")
            slides.append({"text": content})

        assert len(slides) == 3

        # Render carousel
        renderer = CarouselRenderer()
        output_paths = renderer.render_carousel(slides, output_dir=temp_dir)

        assert len(output_paths) == 3
        for path in output_paths:
            assert os.path.exists(path)
            img = Image.open(path)
            assert img.size == (1080, 1080)

    def test_carousel_error_recovery(self, temp_dir, mock_env_vars):
        """Test that carousel generation handles errors gracefully."""
        from rendering.carousel_renderer import CarouselRenderer

        renderer = CarouselRenderer()

        # Test with invalid slide data
        invalid_slides = [
            {"text": "Valid slide"},
            {},  # Invalid - no text
            {"text": "Another valid slide"}
        ]

        # Should handle gracefully and generate what it can
        output_paths = renderer.render_carousel(invalid_slides, output_dir=temp_dir)

        # Should still generate 3 slides (even if one has default text)
        assert len(output_paths) == 3
