#!/usr/bin/env python3
"""
HTML Report Generator for Semgrep Findings

This script converts Semgrep JSON output into a beautiful HTML report
for human review and analysis.
"""

import json
import sys
import os
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Any, Optional

try:
    from jinja2 import Template
except ImportError:
    print("Error: Jinja2 is required. Install with: pip install jinja2")
    sys.exit(1)


class SemgrepReportGenerator:
    """Generates HTML reports from Semgrep JSON output."""
    
    def __init__(self, template_path: str = "/app/templates/report_template.html"):
        """Initialize the report generator with template path."""
        self.template_path = template_path
        self.template = self._load_template()
    
    def _load_template(self) -> Template:
        """Load the HTML template."""
        try:
            with open(self.template_path, 'r', encoding='utf-8') as f:
                return Template(f.read())
        except FileNotFoundError:
            print(f"Warning: Template not found at {self.template_path}")
            print("Using fallback template...")
            return self._get_fallback_template()
    
    def _get_fallback_template(self) -> Template:
        """Provide a fallback template if the main template is not found."""
        fallback_html = """
        <!DOCTYPE html>
        <html>
        <head>
            <title>Semgrep Security Report</title>
            <style>
                body { font-family: Arial, sans-serif; margin: 20px; }
                .finding { border: 1px solid #ddd; margin: 10px 0; padding: 15px; }
                .high { border-left: 5px solid #dc3545; }
                .medium { border-left: 5px solid #fd7e14; }
                .low { border-left: 5px solid #28a745; }
                .info { border-left: 5px solid #17a2b8; }
            </style>
        </head>
        <body>
            <h1>Semgrep Security Scan Report</h1>
            <p><strong>Generated:</strong> {{ scan_date }}</p>
            <p><strong>Total Findings:</strong> {{ total_findings }}</p>
            
            {% for finding in findings %}
            <div class="finding {{ finding.level.lower() }}">
                <h3>{{ finding.rule_id }}</h3>
                <p><strong>Severity:</strong> {{ finding.level }}</p>
                <p><strong>Message:</strong> {{ finding.message }}</p>
                <p><strong>File:</strong> {{ finding.path }}:{{ finding.start.line }}</p>
                {% if finding.code %}
                <pre><code>{{ finding.code }}</code></pre>
                {% endif %}
            </div>
            {% endfor %}
        </body>
        </html>
        """
        return Template(fallback_html)
    
    def parse_semgrep_output(self, json_file: str) -> Dict[str, Any]:
        """Parse Semgrep JSON output file."""
        try:
            with open(json_file, 'r', encoding='utf-8') as f:
                data = json.load(f)
            return data
        except (FileNotFoundError, json.JSONDecodeError) as e:
            print(f"Error reading JSON file: {e}")
            return {}
    
    def extract_findings(self, semgrep_data: Dict[str, Any]) -> List[Dict[str, Any]]:
        """Extract and normalize findings from Semgrep output."""
        findings = []
        
        if not semgrep_data or 'runs' not in semgrep_data:
            return findings
        
        for run in semgrep_data['runs']:
            if 'results' in run:
                for result in run['results']:
                    finding = {
                        'rule_id': result.get('ruleId', 'Unknown Rule'),
                        'message': result.get('message', {}).get('text', 'No message'),
                        'level': result.get('level', 'note').upper(),
                        'path': result.get('locations', [{}])[0].get('physicalLocation', {}).get('artifactLocation', {}).get('uri', 'Unknown file'),
                        'start': {
                            'line': result.get('locations', [{}])[0].get('physicalLocation', {}).get('region', {}).get('startLine', 0),
                            'column': result.get('locations', [{}])[0].get('physicalLocation', {}).get('region', {}).get('startColumn', 0)
                        },
                        'end': {
                            'line': result.get('locations', [{}])[0].get('physicalLocation', {}).get('region', {}).get('endLine', 0),
                            'column': result.get('locations', [{}])[0].get('physicalLocation', {}).get('region', {}).get('endColumn', 0)
                        },
                        'code': self._extract_code_snippet(result),
                        'tags': result.get('tags', [])
                    }
                    findings.append(finding)
        
        return findings
    
    def _extract_code_snippet(self, result: Dict[str, Any]) -> Optional[str]:
        """Extract code snippet from the result if available."""
        if 'codeFlows' in result and result['codeFlows']:
            for flow in result['codeFlows']:
                if 'threadFlows' in flow and flow['threadFlows']:
                    for thread in flow['threadFlows']:
                        if 'locations' in thread and thread['locations']:
                            for location in thread['locations']:
                                if 'location' in location and 'snippet' in location['location']:
                                    return location['location']['snippet'].get('text', '')
        return None
    
    def generate_report_data(self, findings: List[Dict[str, Any]], 
                           repository_url: str = "Unknown", 
                           commit_sha: str = "Unknown") -> Dict[str, Any]:
        """Generate data for the HTML report template."""
        # Count findings by severity
        severity_counts = {
            'high': 0,
            'medium': 0,
            'low': 0,
            'info': 0
        }
        
        for finding in findings:
            level = finding['level'].lower()
            if level in severity_counts:
                severity_counts[level] += 1
        
        return {
            'repository_url': repository_url,
            'commit_sha': commit_sha,
            'scan_date': datetime.now().strftime('%Y-%m-%d %H:%M:%S UTC'),
            'semgrep_version': 'Latest',  # Could be extracted from semgrep output
            'total_findings': len(findings),
            'high_severity_count': severity_counts['high'],
            'medium_severity_count': severity_counts['medium'],
            'low_severity_count': severity_counts['low'],
            'info_severity_count': severity_counts['info'],
            'findings': findings
        }
    
    def generate_html(self, report_data: Dict[str, Any]) -> str:
        """Generate HTML report from template and data."""
        try:
            return self.template.render(**report_data)
        except Exception as e:
            print(f"Error generating HTML: {e}")
            return f"<html><body><h1>Error generating report</h1><p>{e}</p></body></html>"
    
    def save_report(self, html_content: str, output_file: str) -> bool:
        """Save HTML report to file."""
        try:
            with open(output_file, 'w', encoding='utf-8') as f:
                f.write(html_content)
            return True
        except Exception as e:
            print(f"Error saving report: {e}")
            return False


def main():
    """Main function to generate HTML report."""
    if len(sys.argv) < 3:
        print("Usage: python3 generate_html_report.py <json_file> <output_html> [repository_url] [commit_sha]")
        print("Example: python3 generate_html_report.py semgrep-results.json report.html https://github.com/user/repo.git abc123")
        sys.exit(1)
    
    json_file = sys.argv[1]
    output_html = sys.argv[2]
    repository_url = sys.argv[3] if len(sys.argv) > 3 else "Unknown"
    commit_sha = sys.argv[4] if len(sys.argv) > 4 else "Unknown"
    
    # Check if input file exists
    if not os.path.exists(json_file):
        print(f"Error: Input file '{json_file}' not found")
        sys.exit(1)
    
    # Initialize report generator
    generator = SemgrepReportGenerator()
    
    # Parse Semgrep output
    print(f"Parsing Semgrep output from: {json_file}")
    semgrep_data = generator.parse_semgrep_output(json_file)
    
    if not semgrep_data:
        print("Error: No valid Semgrep data found")
        sys.exit(1)
    
    # Extract findings
    print("Extracting findings...")
    findings = generator.extract_findings(semgrep_data)
    print(f"Found {len(findings)} security findings")
    
    # Generate report data
    print("Generating report data...")
    report_data = generator.generate_report_data(findings, repository_url, commit_sha)
    
    # Generate HTML
    print("Generating HTML report...")
    html_content = generator.generate_html(report_data)
    
    # Save report
    print(f"Saving report to: {output_html}")
    if generator.save_report(html_content, output_html):
        print("✅ HTML report generated successfully!")
        print(f"📊 Report contains {len(findings)} findings")
        print(f"🔍 High severity: {report_data['high_severity_count']}")
        print(f"⚠️  Medium severity: {report_data['medium_severity_count']}")
        print(f"ℹ️  Low severity: {report_data['low_severity_count']}")
        print(f"📁 Report saved to: {output_html}")
    else:
        print("❌ Failed to save HTML report")
        sys.exit(1)


if __name__ == "__main__":
    main()
