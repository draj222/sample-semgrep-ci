.PHONY: help build test run clean scan-example generate-html scan-with-webserver

# Default target
help:
	@echo "Available targets:"
	@echo "  build                - Build the Semgrep Docker image"
	@echo "  test                 - Test the image with a sample scan"
	@echo "  run                  - Run interactive shell in the container"
	@echo "  clean                - Clean up Docker images and containers"
	@echo "  scan-example         - Run a sample scan on the vulnerable code"
	@echo "  generate-html        - Generate HTML report from existing JSON results"
	@echo "  scan-with-webserver  - Run scan with webserver integration"
	@echo "  help                 - Show this help message"

# Build the Docker image
build:
	@echo "Building Semgrep Docker image..."
	docker build -t semgrep-custom:latest .
	@echo "Build complete!"

# Test the image
test:
	@echo "Testing Semgrep Docker image..."
	docker run --rm semgrep-custom:latest --help
	@echo "Test passed!"

# Run interactive shell
run:
	@echo "Starting interactive shell in Semgrep container..."
	docker run --rm -it -v $(PWD):/workspace semgrep-custom:latest bash

# Clean up Docker resources
clean:
	@echo "Cleaning up Docker resources..."
	docker rmi semgrep-custom:latest 2>/dev/null || true
	docker system prune -f
	@echo "Cleanup complete!"

# Run sample scan on vulnerable code
scan-example:
	@echo "Running sample scan on vulnerable code..."
	@echo "This will scan the vulnerable-source-code directory..."
	docker run --rm -v $(PWD):/workspace semgrep-custom:latest \
		$(shell git rev-parse HEAD 2>/dev/null || echo "abc123") \
		$(shell git remote get-url origin 2>/dev/null || echo "https://github.com/user/repo.git") \
		--output-format json \
		--output-file sample-scan-results.json \
		--html-report sample-security-report.html
	@echo "Sample scan complete!"
	@echo "📁 JSON results: sample-scan-results.json"
	@echo "🌐 HTML report: sample-security-report.html"

# Run scan with webserver integration
scan-with-webserver:
	@echo "Running scan with webserver integration..."
	@echo "This will scan and POST results to the internal webserver..."
	@if [ -z "$(API_KEY)" ]; then \
		echo "Error: API_KEY environment variable not set"; \
		echo "Usage: API_KEY=your-key make scan-with-webserver"; \
		exit 1; \
	fi
	docker run --rm -v $(PWD):/workspace semgrep-custom:latest \
		$(shell git rev-parse HEAD 2>/dev/null || echo "abc123") \
		$(shell git remote get-url origin 2>/dev/null || echo "https://github.com/user/repo.git") \
		--output-format json \
		--output-file webserver-scan-results.json \
		--html-report webserver-security-report.html \
		--api-key "$(API_KEY)" \
		--webserver-url "http://webserver.local/api/results"
	@echo "Webserver scan complete!"
	@echo "📁 JSON results: webserver-scan-results.json"
	@echo "🌐 HTML report: webserver-security-report.html"
	@echo "📡 Results posted to webserver"

# Generate HTML report from existing JSON results
generate-html:
	@echo "Generating HTML report from existing JSON results..."
	@if [ ! -f "semgrep-results.json" ]; then \
		echo "Error: semgrep-results.json not found. Run a scan first."; \
		exit 1; \
	fi
	docker run --rm -v $(PWD):/workspace semgrep-custom:latest \
		python3 /app/generate_html_report.py \
		/workspace/semgrep-results.json \
		/workspace/security-report.html \
		"$(shell git remote get-url origin 2>/dev/null || echo 'Unknown')" \
		"$(shell git rev-parse HEAD 2>/dev/null || echo 'Unknown')"
	@echo "HTML report generated: security-report.html"

# Build using docker-compose
build-compose:
	@echo "Building using docker-compose..."
	docker-compose build
	@echo "Build complete!"

# Run using docker-compose
run-compose:
	@echo "Starting container with docker-compose..."
	docker-compose run --rm semgrep-scanner

# Show image info
info:
	@echo "Docker image information:"
	docker images semgrep-custom:latest
	@echo ""
	@echo "Container information:"
	docker ps -a --filter ancestor=semgrep-custom:latest

# Test HTML generation
test-html:
	@echo "Testing HTML report generation..."
	@if [ ! -f "semgrep-results.json" ]; then \
		echo "Creating sample JSON for testing..."; \
		echo '{"runs":[{"results":[{"ruleId":"test-rule","message":{"text":"Test finding"},"level":"error","locations":[{"physicalLocation":{"artifactLocation":{"uri":"test.go"},"region":{"startLine":10,"startColumn":1,"endLine":10,"endColumn":20}}}]}]}]}' > semgrep-results.json; \
	fi
	$(MAKE) generate-html
	@echo "HTML generation test complete!"

# Test webserver integration (dry run)
test-webserver:
	@echo "Testing webserver integration (dry run)..."
	@echo "Creating sample JSON for testing..."
	echo '{"runs":[{"results":[{"ruleId":"test-rule","message":{"text":"Test finding"},"level":"error","locations":[{"physicalLocation":{"artifactLocation":{"uri":"test.go"},"region":{"startLine":10,"startColumn":1,"endLine":10,"endColumn":20}}}]}]}]}' > test-webserver.json
	@echo "Sample JSON created: test-webserver.json"
	@echo "To test actual webserver integration, run:"
	@echo "  API_KEY=your-key make scan-with-webserver"
