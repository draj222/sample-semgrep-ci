# Use the official Semgrep image as base
FROM returntocorp/semgrep:latest

# Install additional dependencies
RUN apk add --no-cache \
    git \
    bash \
    curl \
    jq \
    python3 \
    py3-pip \
    nodejs \
    npm

# Install Python packages for HTML generation
RUN pip3 install --no-cache-dir \
    jinja2 \
    markdown

# Install Node.js packages for HTML formatting
RUN npm install -g \
    json2html \
    prettier

# Create app directory
WORKDIR /app

# Copy custom rules
COPY custom-semgrep-rules/ /app/custom-semgrep-rules/

# Copy entrypoint script
COPY entrypoint.sh /app/entrypoint.sh

# Copy HTML report generator
COPY generate_html_report.py /app/generate_html_report.py

# Copy HTML template
COPY templates/ /app/templates/

# Make scripts executable
RUN chmod +x /app/entrypoint.sh /app/generate_html_report.py

# Set the entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]

# Default command (can be overridden)
CMD ["--help"]
