# Semgrep Docker Image with Custom Rules

This Docker image packages Semgrep with custom security rules, making it portable across different environments. The image includes an entrypoint script that accepts a commit SHA and repository clone URL for automated scanning, generates both JSON findings and HTML reports for human review, and automatically POSTs results to an internal webserver for artifact storage.

## Features

- **Portable**: Run Semgrep scans in any Docker environment
- **Custom Rules**: Pre-packaged security rules for Go, JavaScript, and PHP
- **Automated Workflow**: Clone repository, checkout specific commit, scan, and cleanup
- **Dual Output**: JSON findings for machine processing + HTML reports for human review
- **Webserver Integration**: Automatic POST of results to internal webserver with authentication
- **Flexible Output**: Support for SARIF, JSON, and text output formats
- **Clean Environment**: Temporary workspace with automatic cleanup

## Quick Start

### 1. Build the Image

```bash
# Build using Makefile (recommended)
make build

# Or build using Docker
docker build -t semgrep-custom:latest .

# Or build using docker-compose
docker-compose build
```

### 2. Test the Setup

```bash
# Run the comprehensive test script
./test-docker.sh

# Or test manually
make test
```

### 3. Run a Scan

```bash
# Basic scan (generates JSON + HTML by default)
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123 https://github.com/user/repo.git

# With webserver integration
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123 https://github.com/user/repo.git \
  --api-key your-api-key

# With custom webserver URL
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123 https://github.com/user/repo.git \
  --api-key your-api-key \
  --webserver-url https://your-server.com/api/results
```

### 4. Using Docker Compose

```bash
# Interactive mode
docker-compose run --rm semgrep-scanner

# Run with webserver integration
API_KEY=your-key docker-compose run --rm semgrep-scanner

# Run with custom configuration
WEBSERVER_URL=https://your-server.com/api/results API_KEY=your-key docker-compose run --rm semgrep-scanner
```

## Usage

### Command Line Arguments

The entrypoint script accepts the following arguments:

1. **commit_sha** (required): The Git commit SHA to scan
2. **repository_clone_url** (required): The Git repository URL to clone

### Options

- `--output-format <format>`: Output format (sarif, json, text) [default: json]
- `--output-file <file>`: Output file path [default: semgrep-results.<format>]
- `--html-report <file>`: HTML report file path [default: security-report.html]
- `--webserver-url <url>`: Internal webserver URL [default: http://webserver.local/api/results]
- `--api-key <key>`: API key for webserver authentication
- `--config <rules>`: Additional Semgrep rule configurations
- `--help`: Show help message

### Examples

```bash
# Scan a specific commit with default settings
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123def456 https://github.com/example/repo.git

# Scan with webserver integration
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123def456 https://github.com/example/repo.git \
  --api-key your-secure-api-key

# Scan with custom webserver and HTML report
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123def456 https://github.com/example/repo.git \
  --api-key your-secure-api-key \
  --webserver-url https://security-server.internal/api/scan-results \
  --html-report detailed-report.html

# Scan with additional rule configurations
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123def456 https://github.com/example/repo.git \
  --api-key your-secure-api-key \
  --config p/default --config p/security
```

## Webserver Integration

### Overview

After each successful scan, the container automatically POSTs scan results to an internal webserver, ensuring raw artifacts are stored for later retrieval and analysis.

### Payload Format

The webserver receives a JSON payload with the following structure:

```json
{
  "commit": "abc123def456...",
  "repository": "https://github.com/user/repo.git",
  "findings": [...],
  "summary": {
    "errors": 5,
    "warnings": 12
  },
  "timestamp": "2024-01-15T10:30:00Z",
  "scan_id": "1705312200.123"
}
```

### Authentication

- **Header**: `X-API-Key: your-secure-api-key`
- **Content-Type**: `application/json`
- **Method**: `POST`

### Configuration

Create a `webserver-config.env` file based on the example:

```bash
# Copy the example configuration
cp webserver-config.env.example webserver-config.env

# Edit with your actual values
nano webserver-config.env
```

Example configuration:
```bash
WEBSERVER_URL=https://your-internal-server.com/api/security-results
API_KEY=your-secure-randomly-generated-key
```

### Environment Variables

- `WEBSERVER_URL`: Internal webserver endpoint [default: http://webserver.local/api/results]
- `API_KEY`: Authentication key for webserver access
- `COMMIT_SHA`: Git commit SHA to scan
- `REPOSITORY_URL`: Repository URL to clone

## Workflow

The Docker container performs the following automated workflow:

1. **Clone Repository**: Clones the target repository at the specified URL
2. **Checkout Commit**: Switches to the exact commit SHA for scanning
3. **Run Semgrep**: Executes security scan with custom rules and default rules
4. **Generate Output**: Creates JSON findings and HTML report
5. **POST to Webserver**: Sends results to internal webserver with authentication
6. **Copy Results**: Copies all output files to the mounted workspace
7. **Cleanup**: Automatically removes temporary files and cloned repository

## Output Files

### JSON Findings
- **Format**: Machine-readable JSON with detailed vulnerability information
- **Content**: Rule matches, severity levels, file locations, code snippets
- **Use Case**: CI/CD integration, automated processing, data analysis

### HTML Report
- **Format**: Beautiful, human-readable HTML report
- **Content**: Summary dashboard, detailed findings, severity breakdown
- **Use Case**: Security team review, stakeholder presentations, documentation

### Webserver Storage
- **Format**: Structured JSON payload with metadata
- **Content**: Commit info, findings array, severity summary, timestamps
- **Use Case**: Centralized artifact storage, historical analysis, compliance tracking

### Report Features
- **Summary Cards**: Total findings, severity breakdown, scan metadata
- **Detailed Findings**: Rule descriptions, vulnerable code, file locations
- **Responsive Design**: Works on desktop and mobile devices
- **Professional Styling**: Clean, modern interface for easy review

## Custom Rules

The image includes pre-packaged custom security rules for:

### Go
- **go-broken-auth**: Broken authentication patterns
- **go-ssti**: Server-side template injection

### JavaScript/TypeScript
- **js-sqli**: SQL injection vulnerabilities
- **js-ssrf**: Server-side request forgery

### PHP
- **php-lfi**: Local file inclusion
- **php-rce**: Remote code execution

### Adding Custom Rules

1. Add your rule files to the `custom-semgrep-rules/` directory
2. Rebuild the Docker image
3. Rules are automatically loaded during scanning

## Integration Examples

### CI/CD Pipeline with Webserver Integration

```yaml
# GitHub Actions example
- name: Run Semgrep Scan
  env:
    API_KEY: ${{ secrets.WEBSERVER_API_KEY }}
    WEBSERVER_URL: ${{ secrets.WEBSERVER_URL }}
  run: |
    docker run --rm \
      -v ${{ github.workspace }}:/workspace \
      -e API_KEY=$API_KEY \
      -e WEBSERVER_URL=$WEBSERVER_URL \
      semgrep-custom:latest \
      ${{ github.sha }} \
      ${{ github.repositoryUrl }} \
      --api-key $API_KEY \
      --webserver-url $WEBSERVER_URL
```

### Jenkins Pipeline

```groovy
stage('Security Scan') {
    environment {
        API_KEY = credentials('webserver-api-key')
        WEBSERVER_URL = 'https://security-server.internal/api/results'
    }
    steps {
        script {
            sh '''
                docker run --rm \
                  -v ${WORKSPACE}:/workspace \
                  -e API_KEY=${API_KEY} \
                  -e WEBSERVER_URL=${WEBSERVER_URL} \
                  semgrep-custom:latest \
                  ${GIT_COMMIT} \
                  ${GIT_URL} \
                  --api-key ${API_KEY} \
                  --webserver-url ${WEBSERVER_URL}
            '''
        }
    }
}
```

### GitLab CI

```yaml
security_scan:
  stage: test
  image: semgrep-custom:latest
  variables:
    WEBSERVER_URL: "https://security-server.internal/api/results"
  script:
    - /app/entrypoint.sh $CI_COMMIT_SHA $CI_REPOSITORY_URL --api-key $WEBSERVER_API_KEY
  artifacts:
    paths:
      - semgrep-results.json
      - security-report.html
```

### Using Makefile

```bash
# Basic scan
make scan-example

# Scan with webserver integration
API_KEY=your-key make scan-with-webserver

# Generate HTML from existing results
make generate-html
```

## Output Formats

### JSON (Default)
- Machine-readable format for automated processing
- Includes all Semgrep findings with metadata
- Compatible with security tools and dashboards

### SARIF
- Industry standard format for security tool results
- Compatible with GitHub Security tab, Azure DevOps, and other platforms
- Includes detailed metadata and rule information

### Text
- Human-readable format for quick review
- Suitable for console output and basic reporting

## Environment Variables

- `SEMGREP_VERSION`: Override Semgrep version (defaults to latest)
- `WEBSERVER_URL`: Internal webserver endpoint for results storage
- `API_KEY`: Authentication key for webserver access
- `COMMIT_SHA`: Git commit SHA to scan
- `REPOSITORY_URL`: Repository URL to clone

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure the current directory is writable
2. **Git Clone Failed**: Check repository URL and access permissions
3. **Commit Not Found**: Verify the commit SHA exists in the repository
4. **HTML Generation Failed**: Check Python dependencies and template files
5. **Webserver POST Failed**: Verify API key and webserver URL

### Debug Mode

```bash
# Run with verbose output
docker run --rm -it -v $(pwd):/workspace semgrep-custom:latest bash
# Then run the entrypoint manually with debug information
```

### Volume Mounting

Ensure the current directory is mounted as a volume to access output files:

```bash
docker run --rm -v $(pwd):/workspace semgrep-custom:latest ...
```

### Webserver Issues

```bash
# Test webserver connectivity
curl -H "X-API-Key: your-key" http://webserver.local/api/results

# Check webserver logs
docker logs your-webserver-container

# Verify API key format and permissions
```

## Security Considerations

- The image runs in a temporary, isolated environment
- Repository cloning is done with `--depth 1` for minimal data exposure
- Temporary files are automatically cleaned up on exit
- Custom rules are read-only mounted
- No persistent state between scans
- API keys are passed securely via environment variables
- Webserver communication uses HTTPS (when configured)

## Contributing

To add new rules or modify existing ones:

1. Edit the rule files in `custom-semgrep-rules/`
2. Test with sample vulnerable code
3. Rebuild the Docker image
4. Update documentation as needed

## License

This project follows the same license as Semgrep (LGPL 2.1).
