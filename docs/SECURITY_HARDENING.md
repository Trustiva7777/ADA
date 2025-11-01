# Security Hardening & SAST/DAST Implementation

## Overview

This guide covers implementing Static Application Security Testing (SAST), Dynamic Application Security Testing (DAST), supply chain security, and security hardening for the Cardano RWA platform.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                  Development Flow                        │
│                                                          │
│  1. Developer Commits Code                              │
│              │                                           │
│              ▼                                           │
│  2. Git Pre-Commit Hooks                                │
│     - Detect secrets (gitleaks)                         │
│     - Lint checks                                       │
│              │                                           │
│              ▼                                           │
│  3. GitHub Actions CI/CD                                │
│     ├─ SAST: SonarQube, Snyk                            │
│     ├─ Dependency: OWASP Dependency-Check               │
│     ├─ Container: Trivy, Clair                          │
│     └─ SBOM: cyclonedx-bom                              │
│              │                                           │
│              ▼                                           │
│  4. Staging Environment DAST                            │
│     - OWASP ZAP                                         │
│     - Burp Suite                                        │
│     - Manual penetration testing                        │
│              │                                           │
│              ▼                                           │
│  5. Production Deployment                               │
│     - WAF (Web Application Firewall)                    │
│     - Runtime monitoring (RASP)                         │
│     - Incident response                                 │
│                                                          │
└─────────────────────────────────────────────────────────┘
```

## Part 1: SAST - Static Application Security Testing

### 1.1 SonarQube Setup

#### Installation

```bash
# Docker Compose addition
docker run -d \
  --name sonarqube \
  -e SONAR_JDBC_URL=jdbc:postgresql://postgres:5432/sonarqube \
  -e SONAR_JDBC_USERNAME=sonar \
  -e SONAR_JDBC_PASSWORD=sonar \
  -p 9000:9000 \
  sonarqube:latest
```

#### SonarQube Configuration

Create `sonar-project.properties`:

```properties
# Project identification
sonar.projectKey=cardano-rwa
sonar.projectName=Cardano RWA Platform
sonar.projectVersion=1.0

# Source code
sonar.sources=SampleApp/BackEnd,SampleApp/FrontEnd
sonar.exclusions=**/bin/**,**/obj/**,**/node_modules/**

# C# specific
sonar.cs.roslyn.analyzerVersion=latest
sonar.cs.vstest.reportsPaths=**/TestResults/*.trx
sonar.cs.opencover.reportsPaths=**/coverage.xml

# JavaScript/TypeScript
sonar.javascript.lcov.reportPaths=coverage/lcov.info

# Security hotspots
sonar.security.hotspots.path=sonar-security-hotspots.json

# Quality gates
sonar.qualitygate.wait=true
```

### 1.2 GitHub Actions SAST Workflow

Create `.github/workflows/sast.yml`:

```yaml
name: SAST Security Scan

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  sonarqube:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0  # Full history for analysis

      - name: Setup .NET
        uses: actions/setup-dotnet@v3
        with:
          dotnet-version: '9.0.x'

      - name: Restore .NET
        run: dotnet restore

      - name: Build .NET
        run: dotnet build -c Release

      - name: Run tests with coverage
        run: dotnet test --no-build -c Release /p:CollectCoverage=true /p:CoverageFormat=opencover

      - name: SonarQube Scan
        uses: SonarSource/sonarcloud-github-action@master
        with:
          projectBaseDir: .
          args: >
            -Dsonar.projectKey=cardano-rwa
            -Dsonar.organization=cardano-rwa
            -Dsonar.sources=SampleApp
            -Dsonar.tests=Tests
            -Dsonar.exclusions=**/bin/**,**/obj/**
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          SONAR_TOKEN: ${{ secrets.SONAR_TOKEN }}

  snyk:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup .NET
        uses: actions/setup-dotnet@v3

      - name: Restore dependencies
        run: dotnet restore

      - name: Snyk scan
        uses: snyk/actions/dotnet@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}
        with:
          args: --severity-threshold=high

      - name: Upload Snyk report
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: snyk.sarif
```

### 1.3 Code Quality Rules

Create `sonar-quality-gate.json`:

```json
{
  "quality_gate": {
    "name": "Enterprise Standard",
    "conditions": [
      {
        "metric": "coverage",
        "operator": "GREATER_THAN",
        "warning": 80,
        "error": 70,
        "description": "Code coverage must be at least 70%"
      },
      {
        "metric": "bugs",
        "operator": "LESS_THAN",
        "error": 10,
        "description": "Critical and major bugs < 10"
      },
      {
        "metric": "vulnerabilities",
        "operator": "EQUALS",
        "error": 0,
        "description": "Zero vulnerabilities allowed"
      },
      {
        "metric": "security_hotspots_reviewed",
        "operator": "GREATER_THAN",
        "warning": 80,
        "error": 50,
        "description": "At least 50% of hotspots reviewed"
      },
      {
        "metric": "duplicated_lines_density",
        "operator": "LESS_THAN",
        "error": 5,
        "description": "Code duplication < 5%"
      },
      {
        "metric": "cognitive_complexity",
        "operator": "LESS_THAN",
        "warning": 15,
        "description": "Cognitive complexity < 15 per method"
      }
    ]
  }
}
```

## Part 2: Dependency Scanning

### 2.1 OWASP Dependency-Check

Create `.github/workflows/dependency-check.yml`:

```yaml
name: Dependency Check

on: [push, pull_request]

jobs:
  dependency-check:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Run Dependency-Check
        uses: dependency-check/Dependency-Check_Action@main
        with:
          project: 'cardano-rwa'
          path: '.'
          format: 'SARIF'

      - name: Upload Dependency-Check report
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: dependency-check-report.sarif

      - name: Comment on PR
        if: github.event_name == 'pull_request'
        uses: actions/github-script@v6
        with:
          script: |
            const fs = require('fs');
            const report = JSON.parse(fs.readFileSync('dependency-check-report.sarif', 'utf8'));
            const vulnerabilities = report.runs[0].results || [];
            
            let comment = '### 🔐 Dependency Check Results\n\n';
            if (vulnerabilities.length === 0) {
              comment += '✅ No vulnerabilities found';
            } else {
              comment += `⚠️ Found **${vulnerabilities.length}** vulnerabilities:\n`;
              vulnerabilities.forEach(v => {
                comment += `- ${v.message.text}\n`;
              });
            }
            
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: comment
            });
```

### 2.2 Docker Image Scanning

Create `.github/workflows/container-scan.yml`:

```yaml
name: Container Security Scan

on:
  push:
    branches: [main]

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Build Docker image
        run: docker build -t cardano-rwa:latest SampleApp/BackEnd

      - name: Scan with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: 'cardano-rwa:latest'
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy report
        uses: github/codeql-action/upload-sarif@v2
        with:
          sarif_file: trivy-results.sarif

      - name: Fail on critical vulnerabilities
        run: |
          trivy image --exit-code 1 --severity CRITICAL cardano-rwa:latest
```

## Part 3: Secret Detection

### 3.1 Pre-Commit Hooks

Create `.pre-commit-config.yaml`:

```yaml
repos:
  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.4.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
        exclude: package.lock.json

  - repo: https://github.com/gitleaks/gitleaks-action
    rev: v2.3.2
    hooks:
      - id: gitleaks
        args: ['--baseline', '.gitleaks-baseline.json']

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.4.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
        args: ['--maxkb=1000']
```

### 3.2 GitHub Actions Secret Scanning

Create `.github/workflows/gitleaks.yml`:

```yaml
name: Secret Scanning

on: [push, pull_request]

jobs:
  gitleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Run Gitleaks
        uses: gitleaks/gitleaks-action@v2
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          GITLEAKS_ENABLE_COMMENTS: true

      - name: Comment on PR
        if: failure()
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '🚨 Secrets detected! Please review and remove before proceeding.'
            })
```

## Part 4: DAST - Dynamic Application Security Testing

### 4.1 OWASP ZAP Setup

Create `docker-compose.security.yml`:

```yaml
version: '3.8'

services:
  zap:
    image: owasp/zap2docker-stable
    ports:
      - "8080:8080"
      - "8090:8090"
    environment:
      ZAP_CONFIG_FILE: /zap/config.conf
    volumes:
      - ./security/zap-config.conf:/zap/config.conf
      - ./security/zap-policies:/zap/policies
    command: >
      zap.sh -daemon -host 0.0.0.0 -port 8080
      -config api.disablekey=true
      -config api.key=cardano-rwa
```

### 4.2 ZAP API Scan

Create `security/zap-scan.sh`:

```bash
#!/bin/bash

TARGET_URL=${1:-http://localhost:5000}
ZAP_ENDPOINT="http://localhost:8090/JSON"
REPORT_FILE="zap-report.html"

echo "Starting ZAP API scan against $TARGET_URL"

# Start active scan
SCAN_ID=$(curl -s "$ZAP_ENDPOINT/scan/activeScan?url=$TARGET_URL&contextId=1&recurse=true&inScopeOnly=true" | jq -r '.id')

echo "Scan ID: $SCAN_ID"

# Wait for scan to complete
while true; do
  PROGRESS=$(curl -s "$ZAP_ENDPOINT/scan/status?id=$SCAN_ID" | jq -r '.status')
  
  if [ "$PROGRESS" == "100" ]; then
    echo "✅ Scan complete"
    break
  fi
  
  echo "Scan progress: $PROGRESS%"
  sleep 10
done

# Generate report
curl -s "$ZAP_ENDPOINT/core/htmlreport" > "$REPORT_FILE"
echo "Report generated: $REPORT_FILE"

# Get results summary
ALERTS=$(curl -s "$ZAP_ENDPOINT/core/numberOfAlerts?baseurl=$TARGET_URL" | jq -r '.numberOfAlerts')
echo "Total alerts: $ALERTS"

# Fail if critical vulnerabilities found
CRITICAL=$(curl -s "$ZAP_ENDPOINT/core/numberOfAlerts?baseurl=$TARGET_URL&riskId=3" | jq -r '.numberOfAlerts')

if [ "$CRITICAL" -gt 0 ]; then
  echo "❌ CRITICAL vulnerabilities detected: $CRITICAL"
  exit 1
fi

echo "✅ No critical vulnerabilities found"
```

### 4.3 ZAP in CI/CD

Create `.github/workflows/dast.yml`:

```yaml
name: DAST - Dynamic Security Test

on:
  schedule:
    - cron: '0 2 * * *'  # Daily at 2 AM UTC
  workflow_dispatch:

jobs:
  dast:
    runs-on: ubuntu-latest
    services:
      postgres:
        image: postgres:15
        env:
          POSTGRES_PASSWORD: postgres
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5

    steps:
      - uses: actions/checkout@v3

      - name: Start backend
        run: |
          docker-compose up -d
          sleep 10
          curl http://localhost:5000/health || true

      - name: Run ZAP scan
        run: bash security/zap-scan.sh http://localhost:5000

      - name: Upload ZAP report
        uses: actions/upload-artifact@v3
        if: always()
        with:
          name: zap-report
          path: zap-report.html

      - name: Comment on PR
        if: failure()
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '⚠️ DAST scan found vulnerabilities. See artifacts for details.'
            })
```

## Part 5: Security Headers & WAF

### 5.1 Secure Headers (C#)

Create middleware in `Program.cs`:

```csharp
// Security headers middleware
app.Use(async (context, next) =>
{
    context.Response.Headers.Add("X-Content-Type-Options", "nosniff");
    context.Response.Headers.Add("X-Frame-Options", "DENY");
    context.Response.Headers.Add("X-XSS-Protection", "1; mode=block");
    context.Response.Headers.Add("Referrer-Policy", "strict-origin-when-cross-origin");
    context.Response.Headers.Add("Permissions-Policy", "geolocation=(), microphone=(), camera=()");
    
    // CSP - only allow trusted sources
    context.Response.Headers.Add("Content-Security-Policy",
        "default-src 'self'; " +
        "script-src 'self' 'unsafe-inline' https://cdn.jsdelivr.net; " +
        "style-src 'self' 'unsafe-inline'; " +
        "img-src 'self' data: https:; " +
        "font-src 'self' https://fonts.googleapis.com; " +
        "connect-src 'self' https://blockfrost.io https://ogmios.io");
    
    // HSTS - Force HTTPS
    context.Response.Headers.Add("Strict-Transport-Security", "max-age=31536000; includeSubDomains; preload");
    
    await next();
});
```

### 5.2 AWS WAF Rules

```hcl
# terraform/modules/security/waf.tf
resource "aws_wafv2_web_acl" "main" {
  name  = "${var.environment}-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 1

    override_action {
      none {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"

        excluded_rule {
          name = "SizeRestrictions_BODY"
        }
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "AWSManagedRulesCommonRuleSetMetric"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimitRule"
    priority = 2

    action {
      block {}
    }

    statement {
      rate_based_statement {
        limit              = 2000
        aggregate_key_type = "IP"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "RateLimitRuleMetric"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "cardano-rwa-waf"
    sampled_requests_enabled   = true
  }
}
```

## Part 6: SBOM (Software Bill of Materials)

Create `.github/workflows/sbom.yml`:

```yaml
name: Generate SBOM

on:
  push:
    branches: [main]

jobs:
  sbom:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3

      - name: Setup .NET
        uses: actions/setup-dotnet@v3

      - name: Generate C# SBOM
        run: |
          dotnet tool install --global CycloneDX
          cyclonedx-dotnet SampleApp/BackEnd -o sbom.json -f json

      - name: Generate Node.js SBOM
        run: |
          npm install -g @cyclonedx/bom
          cyclonedx-bom --output-file sbom-node.json --output-format json

      - name: Merge SBOMs
        run: |
          # Merge both SBOMs into single file
          python3 scripts/merge-sbom.py sbom.json sbom-node.json > sbom-complete.json

      - name: Upload SBOM
        uses: actions/upload-artifact@v3
        with:
          name: sbom
          path: sbom-complete.json

      - name: Check SBOM for known vulnerabilities
        run: |
          # Use Dependency-Track or similar
          curl -X POST http://localhost:8081/api/v1/bom \
            -H "Content-Type: application/json" \
            -d @sbom-complete.json
```

## Success Criteria (for Gap #6 closure)

✅ SonarQube SAST configured with quality gates  
✅ Dependency-Check scanning all packages  
✅ Container image scanning (Trivy)  
✅ Secret detection (gitleaks) in pre-commit hooks  
✅ DAST scan against staging environment  
✅ Secure headers configured  
✅ WAF rules deployed  
✅ SBOM generated and tracked  
✅ Zero critical vulnerabilities in main branch  
✅ All security scans run in CI/CD pipeline  
✅ Security findings dashboard visible  
✅ Team trained on security practices  
