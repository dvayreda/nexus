#!/bin/bash
# Quick test runner script for Nexus

set -e

echo "==================================="
echo "Nexus Test Suite Runner"
echo "==================================="

# Check if pytest is installed
if ! command -v pytest &> /dev/null; then
    echo "❌ pytest not found. Installing dependencies..."
    pip install -r requirements.txt
fi

# Parse command line arguments
TEST_TYPE="${1:-all}"

case "$TEST_TYPE" in
    unit)
        echo "🧪 Running unit tests..."
        pytest tests/ -v -m unit --cov=. --cov-report=term-missing
        ;;
    integration)
        echo "🔗 Running integration tests..."
        pytest tests/ -v -m integration --cov=. --cov-report=term-missing
        ;;
    coverage)
        echo "📊 Running tests with full coverage report..."
        pytest tests/ -v --cov=. --cov-report=html --cov-report=term-missing
        echo "✅ Coverage report generated at: htmlcov/index.html"
        ;;
    quick)
        echo "⚡ Running quick test check..."
        pytest tests/ -v -x
        ;;
    all)
        echo "🚀 Running all tests with coverage..."
        pytest tests/ -v --cov=. --cov-report=term-missing --cov-report=html
        echo ""
        echo "✅ All tests completed!"
        echo "📊 Coverage report: htmlcov/index.html"
        ;;
    *)
        echo "Usage: ./run_tests.sh [unit|integration|coverage|quick|all]"
        echo ""
        echo "Options:"
        echo "  unit        - Run unit tests only"
        echo "  integration - Run integration tests only"
        echo "  coverage    - Run all tests with HTML coverage report"
        echo "  quick       - Run tests and stop at first failure"
        echo "  all         - Run all tests (default)"
        exit 1
        ;;
esac

echo ""
echo "==================================="
echo "✅ Test run complete!"
echo "==================================="
