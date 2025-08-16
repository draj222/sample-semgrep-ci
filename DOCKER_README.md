# Semgrep Docker Image with Custom Rules

This Docker image packages Semgrep with custom security rules, making it portable across different environments. The image includes an entrypoint script that accepts a commit SHA and repository clone URL for automated scanning, and generates both JSON findings and HTML reports for human review.

## Features

- **Portable**: Run Semgrep scans in any Docker environment
- **Custom Rules**: Pre-packaged security rules for Go, JavaScript, and PHP
- **Automated Workflow**: Clone repository, checkout specific commit, scan, and cleanup
- **Dual Output**: JSON findings for machine processing + HTML reports for human review
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

# With custom output format and HTML report
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123 https://github.com/user/repo.git \
  --output-format json --html-report my-report.html
```

### 4. Using Docker Compose

```bash
# Interactive mode
docker-compose run --rm semgrep-scanner

# Run with specific command
docker-compose run --rm semgrep-scanner \
  abc123 https://github.com/user/repo.git --output-format json
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
- `--config <rules>`: Additional Semgrep rule configurations
- `--help`: Show help message

### Examples

```bash
# Scan a specific commit with default settings
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123def456 https://github.com/example/repo.git

# Scan with JSON output and custom HTML report
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123def456 https://github.com/example/repo.git \
  --output-format json --html-report security-scan.html

# Scan with additional rule configurations
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123def456 https://github.com/example/repo.git \
  --config p/default --config p/security
```

## Workflow

The Docker container performs the following automated workflow:

1. **Clone Repository**: Clones the target repository at the specified URL
2. **Checkout Commit**: Switches to the exact commit SHA for scanning
3. **Run Semgrep**: Executes security scan with custom rules and default rules
4. **Generate Output**: Creates JSON findings and HTML report
5. **Copy Results**: Copies all output files to the mounted workspace
6. **Cleanup**: Automatically removes temporary files and cloned repository

## Output Files

### JSON Findings
- **Format**: Machine-readable JSON with detailed vulnerability information
- **Content**: Rule matches, severity levels, file locations, code snippets
- **Use Case**: CI/CD integration, automated processing, data analysis

### HTML Report
- **Format**: Beautiful, human-readable HTML report
- **Content**: Summary dashboard, detailed findings, severity breakdown
- **Use Case**: Security team review, stakeholder presentations, documentation

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

### CI/CD Pipeline

```yaml
# GitHub Actions example
- name: Run Semgrep Scan
  run: |
    docker run --rm \
      -v ${{ github.workspace }}:/workspace \
      semgrep-custom:latest \
      ${{ github.sha }} \
      ${{ github.repositoryUrl }} \
      --output-file semgrep-results.json \
      --html-report security-report.html
```

### Jenkins Pipeline

```groovy
stage('Security Scan') {
    steps {
        script {
            sh '''
                docker run --rm \
                  -v ${WORKSPACE}:/workspace \
                  semgrep-custom:latest \
                  ${GIT_COMMIT} \
                  ${GIT_URL} \
                  --output-file results.json \
                  --html-report jenkins-report.html
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
  script:
    - /app/entrypoint.sh $CI_COMMIT_SHA $CI_REPOSITORY_URL
  artifacts:
    paths:
      - semgrep-results.json
      - security-report.html
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

## Troubleshooting

### Common Issues

1. **Permission Denied**: Ensure the current directory is writable
2. **Git Clone Failed**: Check repository URL and access permissions
3. **Commit Not Found**: Verify the commit SHA exists in the repository
4. **HTML Generation Failed**: Check Python dependencies and template files

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

## Security Considerations

- The image runs in a temporary, isolated environment
- Repository cloning is done with `--depth 1` for minimal data exposure
- Temporary files are automatically cleaned up on exit
- Custom rules are read-only mounted
- No persistent state between scans

## Contributing

To add new rules or modify existing ones:

1. Edit the rule files in `custom-semgrep-rules/`
2. Test with sample vulnerable code
3. Rebuild the Docker image
4. Update documentation as needed

## License

This project follows the same license as Semgrep (LGPL 2.1).
