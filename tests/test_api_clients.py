"""Unit tests for all API clients with mocking."""
import pytest
import sys
from pathlib import Path
from unittest.mock import Mock, MagicMock, patch, mock_open
import os

# Add src to path
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))


@pytest.mark.unit
class TestPexelsClient:
    """Test suite for PexelsClient."""

    @patch('src.api_clients.pexels_client.requests.get')
    def test_search_images_success(self, mock_get, mock_env_vars, mock_pexels_response):
        """Test successful image search."""
        from api_clients.pexels_client import PexelsClient

        # Setup mock
        mock_response = Mock()
        mock_response.json.return_value = mock_pexels_response
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        # Test
        client = PexelsClient()
        results = client.search_images("nature", per_page=5)

        assert len(results) == 1
        assert results[0]['id'] == 12345
        assert 'src' in results[0]
        mock_get.assert_called_once()

    @patch('src.api_clients.pexels_client.requests.get')
    def test_search_images_api_error(self, mock_get, mock_env_vars):
        """Test handling of API errors."""
        from api_clients.pexels_client import PexelsClient

        # Setup mock to raise error
        mock_get.side_effect = Exception("API Error")

        # Test
        client = PexelsClient()
        with pytest.raises(Exception) as exc_info:
            client.search_images("nature")

        assert "Pexels API error" in str(exc_info.value)

    @patch('src.api_clients.pexels_client.requests.get')
    @patch('builtins.open', new_callable=mock_open)
    def test_download_image_success(self, mock_file, mock_get, mock_env_vars, temp_dir):
        """Test successful image download."""
        from api_clients.pexels_client import PexelsClient

        # Setup mock
        mock_response = Mock()
        mock_response.content = b'fake_image_data'
        mock_response.raise_for_status = Mock()
        mock_get.return_value = mock_response

        # Test
        client = PexelsClient()
        filepath = os.path.join(temp_dir, "downloaded.jpg")
        client.download_image("https://example.com/image.jpg", filepath)

        mock_get.assert_called_once_with("https://example.com/image.jpg")
        mock_file.assert_called_once_with(filepath, 'wb')


@pytest.mark.unit
class TestGroqClient:
    """Test suite for GroqClient."""

    @patch('src.api_clients.groq_client.Groq')
    def test_generate_text_success(self, mock_groq_class, mock_env_vars, mock_llm_response):
        """Test successful text generation."""
        from api_clients.groq_client import GroqClient

        # Setup mock
        mock_client = Mock()
        mock_response = Mock()
        mock_response.choices = [Mock(message=Mock(content=mock_llm_response))]
        mock_client.chat.completions.create.return_value = mock_response
        mock_groq_class.return_value = mock_client

        # Test
        client = GroqClient()
        result = client.generate_text("Test prompt")

        assert result == mock_llm_response
        mock_client.chat.completions.create.assert_called_once()

    @patch('src.api_clients.groq_client.Groq')
    def test_generate_text_api_error(self, mock_groq_class, mock_env_vars):
        """Test handling of API errors."""
        from api_clients.groq_client import GroqClient

        # Setup mock to raise error
        mock_client = Mock()
        mock_client.chat.completions.create.side_effect = Exception("API Error")
        mock_groq_class.return_value = mock_client

        # Test
        client = GroqClient()
        with pytest.raises(Exception) as exc_info:
            client.generate_text("Test prompt")

        assert "Groq API error" in str(exc_info.value)


@pytest.mark.unit
class TestGeminiClient:
    """Test suite for GeminiClient."""

    @patch('src.api_clients.gemini_client.genai.GenerativeModel')
    @patch('src.api_clients.gemini_client.genai.configure')
    def test_generate_text_success(self, mock_configure, mock_model_class, mock_env_vars, mock_llm_response):
        """Test successful text generation."""
        from api_clients.gemini_client import GeminiClient

        # Setup mock
        mock_model = Mock()
        mock_response = Mock(text=mock_llm_response)
        mock_model.generate_content.return_value = mock_response
        mock_model_class.return_value = mock_model

        # Test
        client = GeminiClient()
        result = client.generate_text("Test prompt")

        assert result == mock_llm_response
        mock_model.generate_content.assert_called_once_with("Test prompt")

    @patch('src.api_clients.gemini_client.genai.GenerativeModel')
    @patch('src.api_clients.gemini_client.genai.configure')
    def test_generate_text_api_error(self, mock_configure, mock_model_class, mock_env_vars):
        """Test handling of API errors."""
        from api_clients.gemini_client import GeminiClient

        # Setup mock to raise error
        mock_model = Mock()
        mock_model.generate_content.side_effect = Exception("API Error")
        mock_model_class.return_value = mock_model

        # Test
        client = GeminiClient()
        with pytest.raises(Exception) as exc_info:
            client.generate_text("Test prompt")

        assert "Gemini API error" in str(exc_info.value)


@pytest.mark.unit
class TestClaudeClient:
    """Test suite for ClaudeClient."""

    @patch('src.api_clients.claude_client.Anthropic')
    def test_generate_text_success(self, mock_anthropic_class, mock_env_vars, mock_llm_response):
        """Test successful text generation."""
        from api_clients.claude_client import ClaudeClient

        # Setup mock
        mock_client = Mock()
        mock_response = Mock()
        mock_response.content = [Mock(text=mock_llm_response)]
        mock_client.messages.create.return_value = mock_response
        mock_anthropic_class.return_value = mock_client

        # Test
        client = ClaudeClient()
        result = client.generate_text("Test prompt")

        assert result == mock_llm_response
        mock_client.messages.create.assert_called_once()

    @patch('src.api_clients.claude_client.Anthropic')
    def test_generate_text_api_error(self, mock_anthropic_class, mock_env_vars):
        """Test handling of API errors."""
        from api_clients.claude_client import ClaudeClient

        # Setup mock to raise error
        mock_client = Mock()
        mock_client.messages.create.side_effect = Exception("API Error")
        mock_anthropic_class.return_value = mock_client

        # Test
        client = ClaudeClient()
        with pytest.raises(Exception) as exc_info:
            client.generate_text("Test prompt")

        assert "Claude API error" in str(exc_info.value)
