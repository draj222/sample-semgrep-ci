# Custom Semgrep Rules

This directory contains custom Semgrep rules for security scanning. These rules complement the default Semgrep rule sets and can be tailored to your organization's specific security requirements.

## Rule Structure

Each rule file follows the Semgrep rule format and can be written in YAML or JSON. Rules are organized by language and vulnerability type.

## Usage

Rules in this directory are automatically loaded when running the Semgrep Docker container. You can also reference them explicitly:

```bash
semgrep scan --config ./custom-semgrep-rules/ --config p/default src/
```

## Adding New Rules

1. Create a new YAML file in the appropriate subdirectory
2. Follow the Semgrep rule format
3. Test your rule with sample code
4. Update this README if adding new rule categories
```

## Rule Categories

- **go/**: Go-specific security rules
- **js/**: JavaScript/Node.js security rules  
- **php/**: PHP security rules
- **general/**: Language-agnostic security rules
