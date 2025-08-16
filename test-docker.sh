#!/bin/bash

set -e

echo "🧪 Testing Semgrep Docker Image Setup"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local status=$1
    local message=$2
    if [ "$status" = "PASS" ]; then
        echo -e "${GREEN}✅ PASS${NC}: $message"
    elif [ "$status" = "FAIL" ]; then
        echo -e "${RED}❌ FAIL${NC}: $message"
    else
        echo -e "${YELLOW}⚠️  INFO${NC}: $message"
    fi
}

# Check if Docker is running
echo "Checking Docker availability..."
if ! docker info >/dev/null 2>&1; then
    print_status "FAIL" "Docker is not running or not accessible"
    exit 1
fi
print_status "PASS" "Docker is running"

# Check if image exists
echo "Checking if Semgrep image exists..."
if ! docker images | grep -q "semgrep-custom"; then
    print_status "INFO" "Semgrep image not found, building..."
    make build
else
    print_status "PASS" "Semgrep image found"
fi

# Test basic functionality
echo "Testing basic image functionality..."
if docker run --rm semgrep-custom:latest --help >/dev/null 2>&1; then
    print_status "PASS" "Image runs successfully"
else
    print_status "FAIL" "Image failed to run"
    exit 1
fi

# Test entrypoint script
echo "Testing entrypoint script..."
if docker run --rm semgrep-custom:latest --help | grep -q "Usage:"; then
    print_status "PASS" "Entrypoint script works correctly"
else
    print_status "FAIL" "Entrypoint script not working"
    exit 1
fi

# Test custom rules availability
echo "Testing custom rules availability..."
if docker run --rm semgrep-custom:latest ls /app/custom-semgrep-rules/ >/dev/null 2>&1; then
    print_status "PASS" "Custom rules directory accessible"
    
    # Count rule files
    RULE_COUNT=$(docker run --rm semgrep-custom:latest find /app/custom-semgrep-rules/ -name "*.yaml" | wc -l)
    print_status "INFO" "Found $RULE_COUNT custom rule files"
else
    print_status "FAIL" "Custom rules directory not accessible"
    exit 1
fi

# Test HTML template availability
echo "Testing HTML template availability..."
if docker run --rm semgrep-custom:latest ls /app/templates/ >/dev/null 2>&1; then
    print_status "PASS" "HTML templates directory accessible"
    
    # Check for report template
    if docker run --rm semgrep-custom:latest ls /app/templates/report_template.html >/dev/null 2>&1; then
        print_status "PASS" "HTML report template found"
    else
        print_status "FAIL" "HTML report template not found"
        exit 1
    fi
else
    print_status "FAIL" "HTML templates directory not accessible"
    exit 1
fi

# Test HTML report generator availability
echo "Testing HTML report generator availability..."
if docker run --rm semgrep-custom:latest ls /app/generate_html_report.py >/dev/null 2>&1; then
    print_status "PASS" "HTML report generator script found"
    
    # Test Python script execution
    if docker run --rm semgrep-custom:latest python3 /app/generate_html_report.py --help >/dev/null 2>&1; then
        print_status "PASS" "HTML report generator script is executable"
    else
        print_status "FAIL" "HTML report generator script failed to execute"
        exit 1
    fi
else
    print_status "FAIL" "HTML report generator script not found"
    exit 1
fi

# Test with a simple scan (dry run)
echo "Testing scan functionality (dry run)..."
if docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
    abc123 https://github.com/test/repo.git --help >/dev/null 2>&1; then
    print_status "PASS" "Scan command structure is valid"
else
    print_status "FAIL" "Scan command structure is invalid"
    exit 1
fi

# Check for required tools
echo "Checking required tools in image..."
REQUIRED_TOOLS=("git" "bash" "semgrep" "jq" "python3" "node")
for tool in "${REQUIRED_TOOLS[@]}"; do
    if docker run --rm semgrep-custom:latest which "$tool" >/dev/null 2>&1; then
        print_status "PASS" "$tool is available"
    else
        print_status "FAIL" "$tool is not available"
        exit 1
    fi
done

# Test Python packages
echo "Testing Python packages..."
PYTHON_PACKAGES=("jinja2" "markdown")
for package in "${PYTHON_PACKAGES[@]}"; do
    if docker run --rm semgrep-custom:latest python3 -c "import $package" >/dev/null 2>&1; then
        print_status "PASS" "Python package $package is available"
    else
        print_status "FAIL" "Python package $package is not available"
        exit 1
    fi
done

# Test HTML generation with sample data
echo "Testing HTML report generation..."
SAMPLE_JSON='{"runs":[{"results":[{"ruleId":"test-rule","message":{"text":"Test finding"},"level":"error","locations":[{"physicalLocation":{"artifactLocation":{"uri":"test.go"},"region":{"startLine":10,"startColumn":1,"endLine":10,"endColumn":20}}}]}]}]}'
echo "$SAMPLE_JSON" > test-sample.json

if docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
    python3 /app/generate_html_report.py \
    /workspace/test-sample.json \
    /workspace/test-report.html \
    "https://github.com/test/repo.git" \
    "abc123" >/dev/null 2>&1; then
    
    if [ -f "test-report.html" ]; then
        print_status "PASS" "HTML report generation works correctly"
        rm -f test-sample.json test-report.html
    else
        print_status "FAIL" "HTML report file not created"
        rm -f test-sample.json
        exit 1
    fi
else
    print_status "FAIL" "HTML report generation failed"
    rm -f test-sample.json
    exit 1
fi

echo ""
echo "🎉 All tests passed! The Semgrep Docker image is ready to use."
echo ""
echo "Quick usage examples:"
echo "  # Basic scan with HTML report"
echo "  docker run --rm -v \$(pwd):/workspace semgrep-custom:latest \\"
echo "    abc123 https://github.com/user/repo.git"
echo ""
echo "  # Custom output and HTML report"
echo "  docker run --rm -v \$(pwd):/workspace semgrep-custom:latest \\"
echo "    abc123 https://github.com/user/repo.git \\"
echo "    --output-format json --html-report my-report.html"
echo ""
echo "  # Using Makefile"
echo "  make scan-example"
echo "  make generate-html"
echo ""
echo "For more information, see DOCKER_README.md"
