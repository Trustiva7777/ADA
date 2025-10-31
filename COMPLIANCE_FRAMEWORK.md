# SR-Level Compliance Framework - Configuration Guide

## Overview

This guide provides comprehensive compliance configuration across all system locations:
- Smart Contracts (Solidity)
- Backend Services (.NET)
- Infrastructure (Docker/Kubernetes)
- CI/CD Pipelines (GitHub Actions)
- Deployment Procedures

## 1. SMART CONTRACT COMPLIANCE LAYER

### ComplianceRegistry.sol
Enterprise-grade KYC/AML/sanctions screening with immutable audit trail

**Key Functions:**
```solidity
// KYC Management
submitKYC(investor, nameHash, jurisdiction, accreditationLevel, documentHash)
approveKYC(investor)
renewKYC(investor)
isKYCValid(account) → bool

// Sanctions Screening
setSanctionsFlag(account, screenResult)
setPEPFlag(account, isPEP)
setAdverseMediaFlag(account, hasFlag)

// Transfer Authorization
canTransfer(from, to, amount) → (bool, reason)

// Jurisdiction Control
allowJurisdiction(code)
restrictJurisdiction(code)

// Account Blocking (EMERGENCY)
blockAccount(account, reason)
unblockAccount(account)
isBlocked(account) → bool

// Audit Trail
getComplianceAuditTrail(account) → ComplianceEvent[]
```

**Deployment Configuration:**
```solidity
// Initialize with:
- Admin address (DEFAULT_ADMIN_ROLE)
- OFAC Oracle address
- Initial allowed jurisdictions
```

**Audit Trail Events:**
- KYC_SUBMITTED
- KYC_APPROVED
- KYC_EXPIRED
- SANCTIONS_MATCH
- PEP_FLAG_SET
- ADVERSE_MEDIA_FLAG_SET
- LOCKUP_SET
- TRANSFER_DENIED
- ACCOUNT_BLOCKED
- ACCOUNT_UNBLOCKED
- JURISDICTION_ALLOWED
- JURISDICTION_RESTRICTED

### TransferGate.sol
Reg D/S compliance enforcement with Rule 144 restrictions

**Key Functions:**
```solidity
// Investor Registration
registerInvestor(investor, status, acquisitionDate, acquisitionPrice, totalAcquired)
setAffiliateStatus(investor, isAffiliate)

// Transfer Authorization
requestTransfer(from, to, amount) → requestId
executeTransfer(requestId)

// Form 144 Filing
fileForm144(investor, saleAmount)

// Compliance Checks
_checkTransferCompliance(from, to, amount) → (bool, reason)
_checkAccreditedSaleCompliance(investor, amount)
_checkAffiliateSaleCompliance(investor, amount)
_checkControlPersonSaleCompliance(investor, amount)

// Volume Calculations
updateAverageDailyVolume(newAverageVolume)
getDaysUntilUnrestricted(investor) → uint256
```

**Holding Periods:**
- Accredited Individual: 180 days (Rule 504)
- Affiliate: 6 months (Rule 144(i))
- Control Person: 1 year (Rule 144(h))

**Compliance Status Checks:**
- KYC/AML validation
- Jurisdiction allowed
- No active OFAC/sanctions flags
- Holding period satisfied
- Volume limits honored (Rule 144(e))
- Form 144 filing current (if required)

## 2. .NET BACKEND COMPLIANCE SERVICE

### ComplianceService.cs
Comprehensive compliance service with database persistence

**Configuration (appsettings.json):**
```json
{
  "Compliance": {
    "KYCExpiryPeriodDays": 365,
    "PostIssuanceLockupDays": 180,
    "SanctionsCacheValidityDays": 30,
    "RequireForm144": true,
    "Form144FilingRequirementHours": 48,
    "AllowedJurisdictions": ["US", "CA", "GB", "DE", "..."],
    "RestrictedJurisdictions": ["IR", "KP", "SY", "CU"],
    "OFAC": {
      "ApiEndpoint": "https://api.ofac.treasury.gov/screening",
      "ApiKey": "${OFAC_API_KEY}",
      "Timeout": 5000
    },
    "PII": {
      "EncryptionKey": "${PII_ENCRYPTION_KEY}",
      "Algorithm": "AES-256-GCM"
    }
  }
}
```

**Key Services:**
1. **KYC Management**
   - Submit KYC with document verification
   - Annual re-verification
   - Expiry tracking and renewal
   - PII encryption in storage

2. **Sanctions Screening**
   - OFAC list screening
   - CFTC watchlist checking
   - UN sanctions verification
   - EU sanctions compliance
   - Result caching (30-day TTL default)
   - Fuzzy matching for name variations

3. **Transfer Authorization**
   - Multi-layer compliance checks
   - Lockup period verification
   - Volume limit calculations
   - Form 144 filing validation

4. **Audit Logging**
   - Immutable event trail
   - Compliance violation logging
   - Timestamp + operator tracking
   - 90-day retention (configurable)

### Dependency Injection Configuration
```csharp
services.AddScoped<IComplianceService, ComplianceService>();
services.AddScoped<IComplianceDataRepository, ComplianceDataRepository>();
services.AddScoped<ISanctionsScreeningProvider, SanctionsScreeningProvider>();
services.AddScoped<IAuditLogger, AuditLogger>();
```

## 3. REST API COMPLIANCE ENDPOINTS

### Submit KYC
```
POST /api/compliance/kyc/submit
Content-Type: application/json

{
  "address": "0x...",
  "legalName": "John Doe",
  "dateOfBirth": "1980-01-15",
  "jurisdiction": "US",
  "accreditationLevel": "ACCREDITED",
  "documentHash": "0x..."
}

Response 200:
{
  "success": true,
  "message": "KYC submitted for review"
}

Response 400:
{
  "success": false,
  "errors": ["Field validation error 1", "Field validation error 2"]
}
```

### Check KYC Status
```
GET /api/compliance/kyc/status/{address}

Response 200:
{
  "status": "APPROVED",
  "isValid": true,
  "expiryDate": "2026-10-31",
  "accreditationLevel": "ACCREDITED"
}
```

### Authorize Transfer
```
POST /api/compliance/transfer/authorize
Content-Type: application/json

{
  "fromAddress": "0x...",
  "toAddress": "0x...",
  "amount": "1000"
}

Response 200:
{
  "authorized": true
}

Response 403:
{
  "authorized": false,
  "violations": [
    {
      "code": "SENDER_KYC_INVALID",
      "message": "Sender KYC is invalid or expired"
    }
  ]
}
```

### Get Compliance Audit Trail
```
GET /api/compliance/audit-trail/{address}?days=90

Response 200:
{
  "events": [
    {
      "eventType": "KYC_APPROVED",
      "address": "0x...",
      "details": "Passed KYC review",
      "severity": "INFO",
      "timestamp": "2025-10-31T14:30:00Z"
    }
  ]
}
```

## 4. INFRASTRUCTURE SECURITY CONTROLS

### Environment Variables (.env)
```bash
# Smart Contracts
COMPLIANCE_REGISTRY_ADDRESS=0x...
TRANSFER_GATE_ADDRESS=0x...
OFAC_ORACLE_ADDRESS=0x...

# Database
COMPLIANCE_DB_CONNECTION_STRING=encrypted:...
AUDIT_LOG_DB_CONNECTION_STRING=encrypted:...

# Security
PII_ENCRYPTION_KEY=encrypted:...
AUDIT_SIGNING_KEY=encrypted:...

# APIs
OFAC_API_KEY=encrypted:...
CHAINLINK_ORACLE_KEY=encrypted:...

# Monitoring
DATADOG_API_KEY=encrypted:...
SENTRY_DSN=encrypted:...
```

### Docker Compose Security Configuration
```yaml
services:
  compliance-db:
    image: postgres:16-alpine
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/db_password
      PGDATA: /var/lib/postgresql/data/pgdata
    secrets:
      - db_password
    volumes:
      - compliance_data:/var/lib/postgresql/data
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5
    networks:
      - secure

  audit-log-db:
    image: elasticsearch:8.10.0
    environment:
      - xpack.security.enabled=true
      - xpack.security.authc.api_key.enabled=true
    secrets:
      - es_password
    volumes:
      - audit_data:/usr/share/elasticsearch/data
    networks:
      - secure

secrets:
  db_password:
    external: true
  es_password:
    external: true
```

## 5. CI/CD QUALITY GATES

### GitHub Actions - Code Quality
```yaml
name: SR-Level Quality Gates

on: [pull_request, push]

jobs:
  compliance-checks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      # Solidity Compilation
      - name: Compile Smart Contracts
        run: |
          cd contracts
          npm install
          npx hardhat compile
      
      # Solidity Linting
      - name: Lint Solidity Code
        run: npx solhint 'contracts/src/**/*.sol'
      
      # Solidity Security Analysis
      - name: Security Analysis (Slither)
        run: |
          pip install slither-analyzer
          slither . --json slither-report.json
      
      # Test Coverage
      - name: Test Coverage (Solidity)
        run: |
          npx hardhat coverage --testfiles 'test/**/*compliance*.js'
          if [ $(cat coverage.txt | grep -oP '\d+(?=%)' | head -1) -lt 95 ]; then
            echo "Coverage below 95% threshold"
            exit 1
          fi
      
      # .NET Build
      - name: Build Backend
        run: |
          cd SampleApp/BackEnd
          dotnet build --configuration Release
      
      # .NET Testing
      - name: Test Backend
        run: |
          dotnet test --configuration Release --collect:"XPlat Code Coverage"
      
      # Code Coverage Analysis
      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          fail_ci_if_error: true
          threshold: 85
      
      # SBOM Generation
      - name: Generate SBOM
        run: |
          npm install -g @cyclonedx/npm
          cyclonedx-npm -o sbom.json

  security-scanning:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      # Dependency Scanning
      - name: Dependency Check
        uses: dependency-check/Dependency-Check_Action@main
        with:
          project: 'dotnet-codespaces'
          path: '.'
          format: 'JSON'
      
      # Container Scanning
      - name: Scan Docker Image
        run: |
          docker build -t qh-backend:latest ./SampleApp/BackEnd
          trivy image --exit-code 1 --severity HIGH,CRITICAL qh-backend:latest
      
      # Secret Scanning
      - name: Secret Detection
        run: |
          npm install -g detect-secrets
          detect-secrets scan --baseline .secrets.baseline
```

## 6. DEPLOYMENT VERIFICATION CHECKLIST

### Pre-Deployment (2 weeks before)
- [ ] Security audit completed (OpenZeppelin or equivalent)
- [ ] All compliance tests passing (>95% coverage)
- [ ] Load testing completed (1M transactions/day simulation)
- [ ] Disaster recovery tested
- [ ] Compliance review board approval

### Deployment Day
- [ ] Contract addresses registered with OFAC/FinCEN
- [ ] Hot wallet funded with operational capital
- [ ] Emergency pause switch tested (multi-sig)
- [ ] Monitoring alerts configured and verified
- [ ] Support team on-call (24/7 for 72 hours)

### Post-Deployment (1 month)
- [ ] Transaction volume monitoring
- [ ] KYC approval rate analysis
- [ ] Compliance violation tracking
- [ ] System performance analysis
- [ ] User feedback collection

## 7. COMPLIANCE METRICS & SLAs

### Key Performance Indicators
| Metric | Target | Threshold |
|--------|--------|-----------|
| KYC Approval Time | <2 hours | 4 hours max |
| Compliance Check Latency | <500ms | 1s max |
| Sanctions Check Coverage | 100% | 99.5% min |
| Audit Trail Availability | 99.99% uptime | 99.95% min |
| Code Coverage | 95%+ | 85% min |
| Incident Response | <15 min | 30 min max |

### Compliance Audit Frequency
- Daily: Sanctions list updates, transaction monitoring
- Weekly: KYC expiry reminders, compliance violations review
- Monthly: Attestation cycle verification, reserve audits
- Quarterly: Formal compliance review, policy updates
- Annually: Independent audit, accreditation renewal

## 8. INCIDENT RESPONSE PROCEDURES

### Sanctions Match
1. Immediately block account (EMERGENCY_ROLE)
2. Log to audit trail with timestamp
3. Notify compliance officer
4. File suspicious activity report (SAR) if needed
5. Investigate false positive (48 hours)
6. Re-screen or manual review

### KYC Expiry
1. Send renewal notice (30 days before)
2. Restrict transfer if not renewed (expiry day)
3. Automatic re-screening on renewal
4. Notify compliance team

### Compliance Violation
1. Log event with severity level
2. Prevent transaction execution
3. Generate audit trail entry
4. Alert compliance team
5. Document decision and remediation

## 9. DOCUMENTATION & RECORD-KEEPING

### Required Records (7-year retention)
- All KYC submissions and approvals
- Sanctions screening results
- Form 144 filings
- Transfer authorization logs
- Compliance violation reports
- Incident response actions
- Audit trail entries
- Configuration changes

### Access Control
- Read-only for compliance team
- Write restricted to COMPLIANCE_ROLE
- Emergency access logs
- 90-day download audit trail
- Quarterly access review

## 10. NEXT STEPS

1. **Deploy ComplianceRegistry** to testnet (Sepolia)
   - Initialize with OFAC Oracle
   - Set up allowed jurisdictions
   - Configure admin roles

2. **Deploy TransferGate** to testnet
   - Link to QHSecurityToken
   - Link to ComplianceRegistry
   - Configure holding periods

3. **Implement Backend Compliance APIs**
   - Set up database schema
   - Integrate OFAC screening
   - Enable audit logging

4. **Configure CI/CD Gates**
   - Add GitHub Actions workflows
   - Set coverage thresholds
   - Enable security scanning

5. **Run Formal Audit**
   - Engage OpenZeppelin or Certora
   - Address findings
   - Re-test and verify

6. **Deploy to Mainnet**
   - Execute mainnet checklist
   - Multi-sig approval
   - 72-hour monitoring

---

**Version**: 1.0  
**Date**: October 31, 2025  
**Author**: Engineering Team  
**Review**: Quarterly
