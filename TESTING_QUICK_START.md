# Testing Quick Start Guide

Get started with the Nexus test suite in 5 minutes.

## 1. Install Dependencies

```bash
cd /home/user/nexus
pip install -r requirements.txt
```

## 2. Run Your First Test

```bash
# Simple test to verify setup
pytest tests/test_carousel_renderer.py -v
```

## 3. Run All Tests

```bash
# Run complete test suite
pytest tests/ -v

# Or use the convenient script
./tests/run_tests.sh
```

## 4. View Coverage Report

```bash
# Generate HTML coverage report
pytest tests/ --cov=. --cov-report=html

# Open the report (Linux)
xdg-open htmlcov/index.html

# Or use the script
./tests/run_tests.sh coverage
```

## Common Commands

```bash
# Unit tests only (fast)
pytest tests/ -v -m unit

# Integration tests
pytest tests/ -v -m integration

# Run tests and stop at first failure
pytest tests/ -v -x

# Run specific test file
pytest tests/test_api_clients.py -v

# Run specific test
pytest tests/test_carousel_renderer.py::TestCarouselRenderer::test_create_slide_basic -v
```

## Test Suite Overview

- **693 lines** of production-ready test code
- **40+ test cases** covering all major components
- **80%+ coverage target**
- **4 test categories:** Unit, Integration, API, Composite

## What's Tested

✅ **Image Composition** - Scaling, cropping, compositing
✅ **Carousel Rendering** - Slide creation, text rendering
✅ **API Clients** - All clients with proper mocking
✅ **Integration** - End-to-end carousel generation

## Test Files Created

```
tests/
├── conftest.py              # Shared fixtures (86 lines)
├── test_composite.py        # Image composition (108 lines)
├── test_carousel_renderer.py # Carousel tests (116 lines)
├── test_api_clients.py      # API client tests (163 lines)
├── test_integration.py      # Integration tests (120 lines)
├── fixtures/
│   └── sample_data.py       # Test data (45 lines)
├── README.md                # Full test documentation
└── run_tests.sh             # Convenient test runner
```

## Configuration Files

```
pytest.ini                   # Pytest configuration
.coveragerc                  # Coverage settings
.github/workflows/ci.yml     # CI/CD pipeline (updated)
```

## Troubleshooting

### Issue: ModuleNotFoundError

**Solution:** Ensure you're running from project root:
```bash
cd /home/user/nexus
pytest tests/ -v
```

### Issue: Import errors for src modules

**Solution:** Check that `conftest.py` has correct path setup:
```python
sys.path.insert(0, str(Path(__file__).parent.parent / 'src'))
```

### Issue: Font errors on Linux

**Solution:** Install system fonts:
```bash
sudo apt-get install fonts-dejavu-core
```

### Issue: Coverage below 80%

**Solution:** Check which modules need coverage:
```bash
pytest --cov=. --cov-report=term-missing
coverage report -m
```

## Next Steps

1. ✅ Run tests to verify setup
2. ✅ Check coverage report
3. ✅ Add more test cases as needed
4. ✅ Set up pre-commit hooks
5. ✅ Monitor CI/CD pipeline

## Support

- Full documentation: `docs/testing/test-suite-implementation.md`
- Test README: `tests/README.md`
- CI Configuration: `.github/workflows/ci.yml`

---

**Ready to test!** Run `./tests/run_tests.sh` to get started.
