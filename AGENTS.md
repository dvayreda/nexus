# Agent Guidelines for Nexus

## Test Commands
- Run all tests: `pytest tests/ -v` or `./tests/run_tests.sh`
- Run single test: `pytest tests/test_<name>.py::test_<function> -v`
- Run with coverage: `pytest tests/ -v --cov=. --cov-report=term-missing`
- Run unit tests only: `pytest tests/ -v -m unit`
- Run integration tests: `pytest tests/ -v -m integration`
- Lint code: `black --check . && ruff check .`
- Format code: `black .`

## Code Style
- **Python version**: 3.10+ (target 3.11 for production)
- **Formatting**: Black (auto-format before commits)
- **Linting**: Ruff (fast, strict linting)
- **Imports**: Group stdlib, third-party, local (alphabetized within groups)
- **Type hints**: Use type annotations (e.g., `def func(text: str) -> Image.Image:`)
- **Error handling**: Use try/except with specific exceptions, raise with context (e.g., `raise Exception(f"Claude API error: {str(e)}")`)
- **Naming**: snake_case for functions/variables, PascalCase for classes
- **Docstrings**: Use for public methods ("""Brief description""")
- **Coverage**: Maintain 80% minimum test coverage (enforced in CI)

## Project Context
This is Nexus infrastructure (Raspberry Pi-based AI content platform). Application work (FactsMind) lives in separate repo. Focus on infrastructure: Docker services, monitoring, helper scripts, rendering libraries. Check ROADMAP.md before accepting tasks to prevent scope creep. Speak in first-person when embodying Nexus ("My n8n service...").
