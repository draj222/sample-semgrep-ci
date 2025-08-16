# Semgrep Docker Setup Summary

This document provides a complete overview of the Docker-based Semgrep setup that packages Semgrep with custom security rules for portable scanning across environments.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    Semgrep Docker Image                     │
├─────────────────────────────────────────────────────────────┤
│  Base: returntocorp/semgrep:latest                        │
│  + Git, Bash, curl, jq                                    │
│  + Custom Security Rules                                   │
│  + Entrypoint Script                                       │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Entrypoint Script                        │
│  • Accepts commit SHA + repository URL                     │
│  • Clones repository to specific commit                    │
│  • Runs Semgrep with custom rules                         │
│  • Outputs results in SARIF/JSON/Text format              │
│  • Automatic cleanup of temporary files                   │
└─────────────────────────────────────────────────────────────┘
```

## 📁 File Structure

```
sample-semgrep-ci/
├── Dockerfile                          # Docker image definition
├── docker-compose.yml                  # Docker Compose configuration
├── entrypoint.sh                       # Main entrypoint script
├── .dockerignore                       # Docker build exclusions
├── Makefile                           # Build and test commands
├── test-docker.sh                     # Validation script
├── custom-semgrep-rules/              # Custom security rules
│   ├── README.md                      # Rules documentation
│   ├── go/                           # Go-specific rules
│   │   ├── broken-auth.yaml          # Authentication bypass
│   │   └── ssti.yaml                 # Template injection
│   ├── js/                           # JavaScript rules
│   │   ├── sqli.yaml                 # SQL injection
│   │   └── ssrf.yaml                 # Server-side request forgery
│   └── php/                          # PHP rules
│       ├── lfi.yaml                  # Local file inclusion
│       └── rce.yaml                  # Remote code execution
├── DOCKER_README.md                   # Comprehensive Docker guide
├── SETUP_SUMMARY.md                   # This document
└── .github/workflows/                 # CI/CD examples
    ├── semgrep.yaml                   # Original workflow
    └── docker-semgrep.yaml            # Docker-based workflow
```

## 🚀 Quick Start

### 1. Build the Image

```bash
# Using Makefile (recommended)
make build

# Or using Docker directly
docker build -t semgrep-custom:latest .

# Or using Docker Compose
docker-compose build
```

### 2. Test the Setup

```bash
# Run the test script
./test-docker.sh

# Or test manually
make test
```

### 3. Run a Scan

```bash
# Basic scan
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123 https://github.com/user/repo.git

# With custom output
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123 https://github.com/user/repo.git \
  --output-format json --output-file results.json
```

## 🔧 Key Features

### Entrypoint Script
- **Arguments**: `commit_sha` + `repository_clone_url`
- **Options**: Output format, file path, custom rules
- **Workflow**: Clone → Checkout → Scan → Cleanup
- **Output**: SARIF (default), JSON, or Text format

### Custom Rules
- **Go**: Authentication bypass, template injection
- **JavaScript**: SQL injection, SSRF
- **PHP**: File inclusion, code execution
- **Extensible**: Easy to add new rules

### Portability
- **Self-contained**: All dependencies included
- **Cross-platform**: Runs on any Docker environment
- **CI/CD ready**: Integrates with GitHub Actions, Jenkins, GitLab CI
- **Volume mounting**: Results accessible on host system

## 📋 Usage Examples

### Basic Usage
```bash
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123def456 https://github.com/example/repo.git
```

### Custom Output Format
```bash
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123def456 https://github.com/example/repo.git \
  --output-format json --output-file security-scan.json
```

### Additional Rule Sets
```bash
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  abc123def456 https://github.com/example/repo.git \
  --config p/default --config p/security
```

### Interactive Mode
```bash
docker run --rm -it -v $(pwd):/workspace semgrep-custom:latest bash
```

## 🔄 CI/CD Integration

### GitHub Actions
```yaml
- name: Run Semgrep Scan
  run: |
    docker run --rm \
      -v ${{ github.workspace }}:/workspace \
      semgrep-custom:latest \
      ${{ github.sha }} \
      ${{ github.repositoryUrl }} \
      --output-file semgrep-results.sarif
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
                  --output-file results.sarif
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
      - semgrep-results.sarif
```

## 🛠️ Development

### Adding Custom Rules
1. Create new YAML rule file in `custom-semgrep-rules/`
2. Follow Semgrep rule format
3. Rebuild Docker image
4. Test with sample code

### Modifying Entrypoint
1. Edit `entrypoint.sh`
2. Rebuild Docker image
3. Test functionality

### Building for Production
```bash
# Build with specific tag
docker build -t semgrep-custom:v1.0.0 .

# Push to registry
docker tag semgrep-custom:v1.0.0 your-registry/semgrep-custom:v1.0.0
docker push your-registry/semgrep-custom:v1.0.0
```

## 🧪 Testing

### Validation Script
```bash
./test-docker.sh
```

### Manual Testing
```bash
# Test basic functionality
make test

# Test with sample scan
make scan-example

# Interactive testing
make run
```

### Custom Test Scenarios
```bash
# Test with specific repository
docker run --rm -v $(pwd):/workspace semgrep-custom:latest \
  $(git rev-parse HEAD) \
  $(git remote get-url origin) \
  --output-format sarif
```

## 🔒 Security Considerations

- **Isolated Environment**: Each scan runs in temporary container
- **Minimal Data Exposure**: Repository cloned with `--depth 1`
- **Automatic Cleanup**: Temporary files removed on exit
- **Read-only Rules**: Custom rules mounted as read-only
- **No Persistent State**: Each scan starts fresh

## 📚 Documentation

- **DOCKER_README.md**: Comprehensive usage guide
- **Makefile**: Build and test commands
- **test-docker.sh**: Validation and testing
- **Custom Rules**: Security rule documentation

## 🆘 Troubleshooting

### Common Issues
1. **Permission Denied**: Check volume mount permissions
2. **Git Clone Failed**: Verify repository URL and access
3. **Commit Not Found**: Confirm commit SHA exists
4. **Output File Issues**: Ensure workspace is writable

### Debug Mode
```bash
# Run with verbose output
docker run --rm -it -v $(pwd):/workspace semgrep-custom:latest bash
# Then run entrypoint manually
```

### Logs and Output
- Entrypoint script provides detailed progress information
- Semgrep output includes rule matches and severity levels
- SARIF format includes comprehensive metadata

## 🎯 Next Steps

1. **Customize Rules**: Add organization-specific security rules
2. **Integrate CI/CD**: Deploy in your existing pipeline
3. **Scale Usage**: Use in multiple environments and teams
4. **Monitor Results**: Set up result analysis and reporting
5. **Update Regularly**: Keep Semgrep and rules up to date

---

This setup provides a production-ready, portable Semgrep solution that can be easily integrated into any CI/CD environment while maintaining security best practices and providing comprehensive vulnerability scanning capabilities.
