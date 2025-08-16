#!/bin/bash

set -e

# Function to display usage
usage() {
    echo "Usage: $0 <commit_sha> <repository_clone_url> [options]"
    echo ""
    echo "Arguments:"
    echo "  commit_sha          The commit SHA to scan"
    echo "  repository_clone_url The Git repository URL to clone"
    echo ""
    echo "Options:"
    echo "  --output-format <format>  Output format (sarif, json, text) [default: json]"
    echo "  --output-file <file>      Output file path [default: semgrep-results.<format>]"
    echo "  --html-report <file>      HTML report file path [default: security-report.html]"
    echo "  --webserver-url <url>     Internal webserver URL [default: http://webserver.local/api/results]"
    echo "  --api-key <key>           API key for webserver authentication"
    echo "  --config <rules>          Additional Semgrep rule configurations"
    echo "  --help                    Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 abc123 https://github.com/user/repo.git"
    echo "  $0 abc123 https://github.com/user/repo.git --output-format sarif --html-report report.html"
    echo "  $0 abc123 https://github.com/user/repo.git --config p/default --config ./custom-semgrep-rules/"
    echo "  $0 abc123 https://github.com/user/repo.git --api-key your-api-key"
}

# Function to cleanup temporary files
cleanup() {
    if [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ]; then
        echo "Cleaning up temporary directory..."
        rm -rf "$TEMP_DIR"
    fi
}

# Function to post results to webserver
post_to_webserver() {
    local json_file="$1"
    local commit_sha="$2"
    local repo_url="$3"
    local webserver_url="$4"
    local api_key="$5"
    
    if [ -z "$api_key" ]; then
        echo "⚠️  No API key provided, skipping webserver POST"
        return 0
    fi
    
    if [ ! -f "$json_file" ]; then
        echo "⚠️  JSON results file not found, skipping webserver POST"
        return 0
    fi
    
    echo "📡 Posting results to internal webserver..."
    
    # Parse JSON results to extract findings and summary
    if command -v jq &> /dev/null; then
        # Extract findings array
        FINDINGS=$(jq -c '.runs[].results // []' "$json_file" 2>/dev/null || echo '[]')
        
        # Count errors and warnings
        ERRORS=$(jq '.runs[].results[] | select(.level == "error") | length' "$json_file" 2>/dev/null | awk '{sum += $1} END {print sum+0}')
        WARNINGS=$(jq '.runs[].results[] | select(.level == "warning") | length' "$json_file" 2>/dev/null | awk '{sum += $1} END {print sum+0}')
        
        # Create payload
        PAYLOAD=$(jq -n \
            --arg commit "$commit_sha" \
            --arg repo "$repo_url" \
            --argjson findings "$FINDINGS" \
            --argjson errors "$ERRORS" \
            --argjson warnings "$WARNINGS" \
            '{
                commit: $commit,
                repository: $repo,
                findings: $findings,
                summary: {
                    errors: $errors,
                    warnings: $warnings
                },
                timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
                scan_id: (now | tostring)
            }')
        
        # POST to webserver
        RESPONSE=$(curl -s -w "%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -H "X-API-Key: $api_key" \
            -d "$PAYLOAD" \
            "$webserver_url" 2>/dev/null)
        
        HTTP_CODE="${RESPONSE: -3}"
        RESPONSE_BODY="${RESPONSE%???}"
        
        if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
            echo "✅ Successfully posted results to webserver (HTTP $HTTP_CODE)"
            if [ -n "$RESPONSE_BODY" ]; then
                echo "📋 Response: $RESPONSE_BODY"
            fi
        else
            echo "❌ Failed to post to webserver (HTTP $HTTP_CODE)"
            if [ -n "$RESPONSE_BODY" ]; then
                echo "📋 Error response: $RESPONSE_BODY"
            fi
        fi
        
    else
        echo "⚠️  jq not available, using fallback method for webserver POST"
        
        # Fallback: create simple payload without jq
        TOTAL_FINDINGS=$(grep -c '"ruleId"' "$json_file" 2>/dev/null || echo "0")
        ERRORS=$(grep -c '"level": "error"' "$json_file" 2>/dev/null || echo "0")
        WARNINGS=$(grep -c '"level": "warning"' "$json_file" 2>/dev/null || echo "0")
        
        PAYLOAD="{\"commit\":\"$commit_sha\",\"repository\":\"$repo_url\",\"findings\":[],\"summary\":{\"errors\":$ERRORS,\"warnings\":$WARNINGS},\"total_findings\":$TOTAL_FINDINGS}"
        
        RESPONSE=$(curl -s -w "%{http_code}" \
            -X POST \
            -H "Content-Type: application/json" \
            -H "X-API-Key: $api_key" \
            -d "$PAYLOAD" \
            "$webserver_url" 2>/dev/null)
        
        HTTP_CODE="${RESPONSE: -3}"
        if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 201 ]; then
            echo "✅ Successfully posted results to webserver (HTTP $HTTP_CODE)"
        else
            echo "❌ Failed to post to webserver (HTTP $HTTP_CODE)"
        fi
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Parse arguments
if [ $# -lt 2 ]; then
    echo "Error: Missing required arguments"
    usage
    exit 1
fi

COMMIT_SHA="$1"
REPO_URL="$2"
shift 2

# Default values
OUTPUT_FORMAT="json"
OUTPUT_FILE=""
HTML_REPORT="security-report.html"
WEBSERVER_URL="http://webserver.local/api/results"
API_KEY=""
ADDITIONAL_CONFIGS=""

# Parse options
while [[ $# -gt 0 ]]; do
    case $1 in
        --output-format)
            OUTPUT_FORMAT="$2"
            shift 2
            ;;
        --output-file)
            OUTPUT_FILE="$2"
            shift 2
            ;;
        --html-report)
            HTML_REPORT="$2"
            shift 2
            ;;
        --webserver-url)
            WEBSERVER_URL="$2"
            shift 2
            ;;
        --api-key)
            API_KEY="$2"
            shift 2
            ;;
        --config)
            ADDITIONAL_CONFIGS="$ADDITIONAL_CONFIGS --config $2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            echo "Error: Unknown option $1"
            usage
            exit 1
            ;;
    esac
done

# Set default output file if not specified
if [ -z "$OUTPUT_FILE" ]; then
    OUTPUT_FILE="semgrep-results.${OUTPUT_FORMAT}"
fi

# Validate commit SHA format (basic check)
if [[ ! "$COMMIT_SHA" =~ ^[a-f0-9]{7,40}$ ]]; then
    echo "Error: Invalid commit SHA format: $COMMIT_SHA"
    exit 1
fi

# Validate repository URL
if [[ ! "$REPO_URL" =~ ^https?:// ]]; then
    echo "Error: Invalid repository URL: $REPO_URL"
    exit 1
fi

echo "🚀 Starting Semgrep Security Scan"
echo "=================================="
echo "Commit SHA: $COMMIT_SHA"
echo "Repository: $REPO_URL"
echo "Output format: $OUTPUT_FORMAT"
echo "Output file: $OUTPUT_FILE"
echo "HTML report: $HTML_REPORT"
echo "Webserver URL: $WEBSERVER_URL"
if [ -n "$API_KEY" ]; then
    echo "API Key: ${API_KEY:0:8}..."
else
    echo "API Key: Not provided (webserver POST disabled)"
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"

echo ""
echo "📥 Cloning repository..."
git clone --depth 1 "$REPO_URL" repo
cd repo

echo "🔍 Checking out commit: $COMMIT_SHA"
git checkout "$COMMIT_SHA"

# Verify we're on the correct commit
ACTUAL_SHA=$(git rev-parse HEAD)
if [ "$ACTUAL_SHA" != "$COMMIT_SHA" ]; then
    echo "Warning: Requested commit $COMMIT_SHA, but checked out $ACTUAL_SHA"
    echo "This might be a short SHA or the commit doesn't exist in the default branch"
fi

echo ""
echo "🔒 Running Semgrep security scan..."
# Build semgrep command
SEMGREP_CMD="semgrep scan --quiet --output-format $OUTPUT_FORMAT"

# Add custom rules by default
if [ -d "/app/custom-semgrep-rules" ]; then
    SEMGREP_CMD="$SEMGREP_CMD --config /app/custom-semgrep-rules"
    echo "✅ Using custom security rules"
fi

# Add additional configs if specified
if [ -n "$ADDITIONAL_CONFIGS" ]; then
    SEMGREP_CMD="$SEMGREP_CMD $ADDITIONAL_CONFIGS"
    echo "✅ Using additional rule configurations"
fi

# Add default rules if no custom configs specified
if [ -z "$ADDITIONAL_CONFIGS" ]; then
    SEMGREP_CMD="$SEMGREP_CMD --config p/default"
    echo "✅ Using default Semgrep rules"
fi

# Add output file
SEMGREP_CMD="$SEMGREP_CMD --output $OUTPUT_FILE"

# Add source directory
SEMGREP_CMD="$SEMGREP_CMD ."

echo "Executing: $SEMGREP_CMD"
echo ""

# Run Semgrep scan
if eval $SEMGREP_CMD; then
    echo "✅ Semgrep scan completed successfully!"
    echo "📊 Results saved to: $OUTPUT_FILE"
    
    # Generate HTML report if JSON output
    if [ "$OUTPUT_FORMAT" = "json" ] && [ -f "$OUTPUT_FILE" ]; then
        echo ""
        echo "🔄 Generating HTML report..."
        
        # Check if HTML report generator is available
        if [ -f "/app/generate_html_report.py" ]; then
            python3 /app/generate_html_report.py "$OUTPUT_FILE" "$HTML_REPORT" "$REPO_URL" "$COMMIT_SHA"
            
            if [ -f "$HTML_REPORT" ]; then
                echo "✅ HTML report generated: $HTML_REPORT"
            else
                echo "⚠️  HTML report generation failed"
            fi
        else
            echo "⚠️  HTML report generator not found, skipping HTML generation"
        fi
    fi
    
    # POST results to webserver
    if [ -n "$API_KEY" ]; then
        echo ""
        post_to_webserver "$OUTPUT_FILE" "$COMMIT_SHA" "$REPO_URL" "$WEBSERVER_URL" "$API_KEY"
    fi
    
    # Display summary
    echo ""
    echo "📈 Scan Summary:"
    if [ -f "$OUTPUT_FILE" ]; then
        if [ "$OUTPUT_FORMAT" = "json" ] && command -v jq &> /dev/null; then
            RUNS=$(jq '.runs | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
            RESULTS=$(jq '.runs[].results | length' "$OUTPUT_FILE" 2>/dev/null | awk '{sum += $1} END {print sum+0}')
            echo "  📁 Runs: $RUNS"
            echo "  🔍 Total Findings: $RESULTS"
            
            # Count by severity if available
            if [ "$RESULTS" -gt 0 ]; then
                HIGH=$(jq '.runs[].results[] | select(.level == "error") | length' "$OUTPUT_FILE" 2>/dev/null | awk '{sum += $1} END {print sum+0}')
                MEDIUM=$(jq '.runs[].results[] | select(.level == "warning") | length' "$OUTPUT_FILE" 2>/dev/null | awk '{sum += $1} END {print sum+0}')
                LOW=$(jq '.runs[].results[] | select(.level == "note") | length' "$OUTPUT_FILE" 2>/dev/null | awk '{sum += $1} END {print sum+0}')
                echo "  🚨 High Severity: $HIGH"
                echo "  ⚠️  Medium Severity: $MEDIUM"
                echo "  ℹ️  Low Severity: $LOW"
            fi
        elif [ "$OUTPUT_FORMAT" = "sarif" ] && command -v jq &> /dev/null; then
            RUNS=$(jq '.runs | length' "$OUTPUT_FILE" 2>/dev/null || echo "0")
            RESULTS=$(jq '.runs[].results | length' "$OUTPUT_FILE" 2>/dev/null | awk '{sum += $1} END {print sum+0}')
            echo "  📁 Runs: $RUNS"
            echo "  🔍 Total Findings: $RESULTS"
        else
            echo "  📁 Output file: $OUTPUT_FILE"
            echo "  📏 Format: $OUTPUT_FORMAT"
        fi
    fi
    
    # Copy results to workspace if mounted
    if [ -d "/workspace" ]; then
        echo ""
        echo "📋 Copying results to workspace..."
        cp "$OUTPUT_FILE" "/workspace/"
        if [ -f "$HTML_REPORT" ]; then
            cp "$HTML_REPORT" "/workspace/"
        fi
        echo "✅ Results copied to workspace"
    fi
    
else
    echo "❌ Error: Semgrep scan failed"
    exit 1
fi

echo ""
echo "🎉 Security scan completed successfully!"
echo "📁 Raw results: $OUTPUT_FILE"
if [ -f "$HTML_REPORT" ]; then
    echo "🌐 HTML report: $HTML_REPORT"
fi
if [ -n "$API_KEY" ]; then
    echo "📡 Results posted to: $WEBSERVER_URL"
fi

