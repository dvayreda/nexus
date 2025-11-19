# Nexus Test Suite

Comprehensive test suite for the Nexus content automation system.

## Test Structure

```
tests/
├── conftest.py                 # Shared fixtures and configuration
├── test_composite.py           # Image composition tests
├── test_carousel_renderer.py   # Carousel rendering tests
├── test_api_clients.py         # API client tests (mocked)
├── test_integration.py         # End-to-end integration tests
└── fixtures/
    └── sample_data.py          # Sample test data
```

## Running Tests

### All Tests
```bash
pytest tests/ -v
```

### By Category
```bash
# Unit tests only
pytest tests/ -v -m unit

# Integration tests only
pytest tests/ -v -m integration
```

### With Coverage
```bash
pytest tests/ -v --cov=. --cov-report=html
open htmlcov/index.html
```

### Specific Test File
```bash
pytest tests/test_carousel_renderer.py -v
```

## Test Markers

- `@pytest.mark.unit` - Fast unit tests
- `@pytest.mark.integration` - Integration tests
- `@pytest.mark.slow` - Slow-running tests
- `@pytest.mark.api` - Tests requiring external APIs

## Coverage Target

**Target:** 80%+ overall coverage

Current coverage can be viewed by running:
```bash
pytest --cov=. --cov-report=term-missing
```

## Writing New Tests

1. Add tests to appropriate test file
2. Use fixtures from `conftest.py`
3. Mark tests with appropriate markers
4. Follow naming convention: `test_<feature>_<scenario>`
5. Include docstrings explaining what is being tested

## Fixtures Available

- `temp_dir` - Temporary directory for test outputs
- `sample_image` - Sample PIL Image object
- `sample_image_path` - Path to sample image file
- `carousel_slides_data` - Sample carousel data
- `mock_env_vars` - Mocked environment variables
- `mock_pexels_response` - Mock Pexels API response
- `mock_llm_response` - Mock LLM response

## CI/CD

Tests run automatically on:
- Push to main/develop branches
- Pull requests to main/develop branches

See `.github/workflows/ci.yml` for CI configuration.
