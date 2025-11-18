"""Pytest configuration and shared fixtures."""
import pytest
import os
import tempfile
import shutil
from pathlib import Path
from PIL import Image
from unittest.mock import Mock, MagicMock

# Add project root to path
import sys
sys.path.insert(0, str(Path(__file__).parent.parent))


@pytest.fixture
def temp_dir():
    """Create a temporary directory for test outputs."""
    temp_path = tempfile.mkdtemp()
    yield temp_path
    shutil.rmtree(temp_path, ignore_errors=True)


@pytest.fixture
def sample_image():
    """Create a sample test image."""
    img = Image.new('RGB', (1080, 1080), color='red')
    return img


@pytest.fixture
def sample_image_path(temp_dir, sample_image):
    """Create a sample image file and return its path."""
    image_path = os.path.join(temp_dir, 'test_image.png')
    sample_image.save(image_path)
    return image_path


@pytest.fixture
def sample_template_image():
    """Create a sample template image."""
    img = Image.new('RGB', (2160, 2700), color='blue')
    return img


@pytest.fixture
def sample_template_path(temp_dir, sample_template_image):
    """Create a sample template file and return its path."""
    template_path = os.path.join(temp_dir, 'template.png')
    sample_template_image.save(template_path)
    return template_path


@pytest.fixture
def mock_pexels_response():
    """Mock Pexels API response."""
    return {
        'photos': [
            {
                'id': 12345,
                'url': 'https://www.pexels.com/photo/12345/',
                'src': {
                    'original': 'https://images.pexels.com/photos/12345/pexels-photo-12345.jpeg',
                    'large': 'https://images.pexels.com/photos/12345/pexels-photo-12345.jpeg?w=1080',
                    'medium': 'https://images.pexels.com/photos/12345/pexels-photo-12345.jpeg?w=640'
                },
                'photographer': 'Test Photographer',
                'alt': 'Test image description'
            }
        ]
    }


@pytest.fixture
def mock_llm_response():
    """Mock LLM API response text."""
    return "This is a test response from the AI model."


@pytest.fixture
def carousel_slides_data():
    """Sample carousel slides data."""
    return [
        {
            "text": "First slide: Hook your audience with a question",
            "type": "hook"
        },
        {
            "text": "Second slide: Present the main point",
            "type": "reveal"
        },
        {
            "text": "Third slide: Provide supporting evidence",
            "type": "reveal"
        },
        {
            "text": "Fourth slide: Show the solution",
            "type": "reveal"
        },
        {
            "text": "Fifth slide: Call to action - Follow for more!",
            "type": "cta"
        }
    ]


@pytest.fixture
def mock_env_vars(monkeypatch):
    """Mock environment variables for API keys."""
    monkeypatch.setenv('PEXELS_API_KEY', 'test_pexels_key')
    monkeypatch.setenv('GROQ_API_KEY', 'test_groq_key')
    monkeypatch.setenv('GEMINI_API_KEY', 'test_gemini_key')
    monkeypatch.setenv('ANTHROPIC_API_KEY', 'test_anthropic_key')
