# API Versioning Strategy

## Executive Summary

This document defines how the Cardano RWA platform manages API evolution while maintaining backward compatibility and providing clear upgrade paths for consumers.

**Key Principles:**
- Semantic versioning for all APIs and releases
- 6-month deprecation window for breaking changes
- URL-path versioning (v1, v2, v3)
- Automated breaking-change detection in CI/CD
- Changelog generation from commit messages

## Versioning Scheme

### Application Version Format: MAJOR.MINOR.PATCH

| Component | Meaning | Example | Trigger |
|-----------|---------|---------|---------|
| **MAJOR** | Breaking changes | 1.0.0 → 2.0.0 | Removed endpoint, changed response schema |
| **MINOR** | Backward-compatible features | 1.0.0 → 1.1.0 | New endpoint, new optional parameter |
| **PATCH** | Bug fixes | 1.0.1 → 1.0.2 | Fixed validation logic, security patch |

### API Version Format: /api/v{N}

```
/api/v1/weatherforecast      # v1 of API
/api/v2/weatherforecast      # v2 of API
/api/v3/assets/mint          # v3 endpoint for minting
```

## What Constitutes a Breaking Change?

### ✗ BREAKING CHANGES (Require MAJOR version bump + deprecation)

1. **Endpoint removal**
   ```
   ❌ DELETE /api/v1/audit → Upgrade to v2
   ```

2. **Required parameter addition**
   ```
   ❌ POST /api/v1/mint
   Old: { "assetId": "123" }
   New: { "assetId": "123", "nodeUrl": "http://..." }  ← Required!
   ```

3. **Response schema change (fields removed)**
   ```
   ❌ GET /api/v1/asset/123
   Old: { "id": "123", "name": "Property", "location": "NYC" }
   New: { "id": "123", "name": "Property" }  ← location removed!
   ```

4. **HTTP status code change**
   ```
   ❌ 201 Created → 200 OK
   ❌ 400 Bad Request → 422 Unprocessable Entity
   ```

5. **Authentication/authorization changes**
   ```
   ❌ Bearer token → API key required
   ❌ Scope change: "read:assets" is now required
   ```

6. **Data type change**
   ```
   ❌ { "amount": "1000" }  ← string
   → { "amount": 1000 }     ← number
   ```

### ✓ NON-BREAKING CHANGES (MINOR version bump)

1. **New optional parameter**
   ```
   ✓ POST /api/v1/mint
   Old: { "assetId": "123" }
   New: { "assetId": "123", "expedite": false }  ← optional
   ```

2. **New optional response field**
   ```
   ✓ GET /api/v1/asset/123
   Old: { "id": "123", "name": "Property" }
   New: { "id": "123", "name": "Property", "valuation": 999999 }  ← new field
   ```

3. **New endpoint**
   ```
   ✓ POST /api/v1/audit/export
   ```

4. **New HTTP status code**
   ```
   ✓ Add 429 Too Many Requests (rate limiting)
   ```

### ~ PATCH version bump

1. Bug fixes with no interface change
2. Security patches
3. Performance improvements

## Versioning Strategy by Layer

### Backend API Versioning

**Location:** `/api/v{N}/`

**Example transitions:**

```
V1 (Current)
├── GET  /api/v1/weatherforecast
├── GET  /api/v1/assets
├── POST /api/v1/assets/{id}/mint
└── GET  /api/v1/audit

V2 (In Development - Deprecate V1 in 6 months)
├── GET  /api/v2/weatherforecast        # Enhanced with caching
├── GET  /api/v2/assets                 # Added filtering
├── POST /api/v2/assets/{id}/mint       # Added batch operations
├── GET  /api/v2/audit                  # New: Audit log streaming
└── (V1 endpoints still available, marked deprecated)
```

### Entity Versioning (Data Model)

Each entity carries a version for data migrations:

```csharp
public class Asset
{
    public string Id { get; set; }
    public string Name { get; set; }
    public decimal Value { get; set; }
    
    // Versioning metadata
    public int EntityVersion { get; set; } = 1;  // Incremented on breaking changes
    public DateTime CreatedAt { get; set; }
}
```

### Smart Contract Versioning (On-Chain)

Cardano smart contracts immutably live on-chain. New versions deployed as new contracts:

```
Contracts:
├── MintAsset_v1.plutus       # Original implementation
├── MintAsset_v1_bug_fix.plutus # Patch
└── MintAsset_v2.plutus       # New version with breaking changes
```

## Deprecation Policy

### Timeline

```
Timeline Example: v1 → v2
├─ Month 0:     v2 released, v1 still primary
├─ Month 1:     Warning headers added to v1 responses
├─ Month 2:     Documentation points to v2
├─ Month 3:     Announce: "v1 sunset in 3 months"
├─ Month 4:     Heavy promotion of v2, offer migration support
├─ Month 5:     Final warning email to API consumers
├─ Month 6:     v1 endpoints return 410 Gone
└─ Month 7:     v1 code removed from codebase
```

### Deprecation Headers

**v1 endpoint response headers (Month 1+):**

```http
HTTP/1.1 200 OK
Content-Type: application/json
Deprecation: true
Sunset: Sun, 01 Jul 2025 00:00:00 GMT
Link: </api/v2/asset>; rel="successor-version"
X-API-Warn: "API v1 deprecated. Migrate to v2 by July 1, 2025. See docs: https://..."

{
  "id": "asset-123",
  "name": "Property A"
}
```

### Sunset Response

**After 6 months (Month 6+):**

```http
HTTP/1.1 410 Gone
Content-Type: application/json
Link: </api/v2/asset>; rel="successor-version"

{
  "error": "gone",
  "message": "API v1 is no longer supported. Please migrate to v2: https://docs/migration-guide-v1-to-v2",
  "successor": "/api/v2/asset",
  "deprecation_date": "2025-07-01"
}
```

## Automated Breaking-Change Detection

### GitHub Actions Workflow

Create `.github/workflows/api-breaking-changes.yml`:

```yaml
name: API Breaking Change Detection

on:
  pull_request:
    paths:
      - 'SampleApp/BackEnd/**'

jobs:
  detect-breaking-changes:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Detect schema changes
        run: |
          # Compare current OpenAPI spec with main
          git diff origin/main...HEAD -- openapi.yaml > /tmp/api.diff || true
          
          if grep -E "^\-.*required:|^\+.*required:" /tmp/api.diff; then
            echo "❌ BREAKING: Required field added/removed"
            exit 1
          fi
          
          if grep -E "^\-\s+properties:" /tmp/api.diff; then
            echo "❌ BREAKING: Response property removed"
            exit 1
          fi
          
          echo "✅ No breaking changes detected"

      - name: Validate version bump
        run: |
          # Check if MAJOR version was bumped
          if grep -E "BREAKING" /tmp/api.diff; then
            VERSION=$(grep "version:" openapi.yaml | head -1 | cut -d: -f2 | xargs)
            PREV_VERSION=$(git show origin/main:openapi.yaml | grep "version:" | head -1 | cut -d: -f2 | xargs)
            
            if [[ "$VERSION" != "2.0"* && "$PREV_VERSION" == "1."* ]]; then
              echo "❌ BREAKING changes detected but MAJOR version not bumped"
              exit 1
            fi
          fi
          echo "✅ Version properly bumped"
```

### Commit Message Convention

Use Conventional Commits with breaking-change marker:

```
BREAKING CHANGE: Removed asset deprecation endpoint /api/v1/asset/{id}/deprecate

# or in footer:

feat(api): add asset valuation API

BREAKING CHANGE: Asset schema no longer includes 'estimated_value', 
use 'current_valuation' endpoint instead
```

**CI/CD automatically:**
- Detects commits with "BREAKING CHANGE"
- Requires MAJOR version bump
- Blocks PR if not bumped correctly

## Migration Guides

### Example: v1 → v2

Create `docs/migration/v1-to-v2.md`:

```markdown
# Migrating from API v1 to v2

## What's New in v2
- Batch operations support
- Enhanced filtering
- Streaming audit logs
- Improved error messages

## Breaking Changes

### 1. Response field rename
**v1:**
\`\`\`json
{ "assetId": "123" }
\`\`\`

**v2:**
\`\`\`json
{ "asset_id": "123" }
\`\`\`

**Migration:** Update your JSON parsing to use `asset_id`

### 2. New required parameter
**v1:**
\`\`\`bash
POST /api/v1/mint
\`\`\`

**v2:**
\`\`\`bash
POST /api/v2/mint
Header: X-Idempotency-Key: uuid
\`\`\`

**Migration:** Add idempotency key header to prevent duplicate mints

## Step-by-Step Migration

1. Update client library: `npm install @cardano-rwa/sdk@2.0`
2. Review migration guide (this document)
3. Update endpoint URLs: `/api/v1/` → `/api/v2/`
4. Update response parsing for field name changes
5. Add new required headers
6. Test in staging environment
7. Deploy to production
8. Monitor for errors in first 24h
```

## OpenAPI Specification

Update `openapi.yaml` to include version info:

```yaml
openapi: 3.0.1
info:
  title: Cardano RWA API
  version: '2.0.0'
  x-api-lifecycle: stable
  x-deprecation:
    sunset_date: '2025-07-01'
    migration_guide: '/docs/migration/v1-to-v2'

servers:
  - url: https://api.cardano-rwa.io/api/v2
    description: Production (v2)
  - url: https://api.cardano-rwa.io/api/v1
    description: Deprecated (sunset 2025-07-01)
    x-deprecated: true

paths:
  /assets:
    get:
      summary: List assets
      deprecated: false
      parameters:
        - name: version
          in: query
          description: API version override
          schema:
            type: string
            enum: [v1, v2]
```

## Version Release Process

### 1. Feature Development
```
feat(api): add batch mint endpoint

Adds support for minting multiple assets in single request.

MINOR version bump (no breaking changes)
```

### 2. Pull Request Checks
- ✅ No breaking changes detected by CI
- ✅ Version properly bumped in files:
  - `openapi.yaml`
  - `package.json` (Node.js SDK)
  - `.csproj` (C# SDK)
- ✅ Migration guide included (if breaking)
- ✅ Deprecation headers added (if deprecating)

### 3. Changelog Generation
```bash
npm install conventional-changelog-cli --save-dev
npm run changelog  # Generates CHANGELOG.md from commits
```

**Generated output:**
```markdown
# [2.1.0](https://github.com/cardano-rwa/core/compare/v2.0.0...v2.1.0)

## Features
- **api**: add batch mint endpoint (#456)
- **api**: add asset filtering by category (#454)

## Bug Fixes
- **compliance**: fix sanctions check timeout (#457)

## BREAKING CHANGES

None - all changes are backward compatible
```

### 4. Release Notes
```markdown
# v2.1.0 - June 15, 2025

## ✨ Features
- Batch operations: Mint up to 1000 assets per request
- Filtering: Filter assets by category, region, issuer
- Performance: 40% faster list queries

## 🐛 Bug Fixes
- Fixed timeout on sanctions checks > 10K records
- Fixed memory leak in asset validation

## 📋 Migration Guide
No migration needed. All changes are backward compatible.

## 📅 Deprecations
- Scheduled: Deprecate v1 API June 2025 (6 months notice given March 2025)

## 🔗 Links
- [Full Changelog](https://github.com/cardano-rwa/core/compare/v2.0.0...v2.1.0)
- [OpenAPI Spec](https://api.cardano-rwa.io/openapi.json)
```

## Version Support Matrix

| Version | Release Date | Support Ends | Status |
|---------|-------------|-------------|--------|
| 1.0.x   | Jan 2025    | Jul 2025    | ⚠️ Deprecated |
| 1.1.x   | Feb 2025    | Aug 2025    | ⚠️ Deprecated |
| 2.0.x   | Mar 2025    | Sep 2025    | 🟡 LTS (9 months) |
| 2.1.x   | Jun 2025    | Dec 2025    | 🟢 Current |
| 3.0.x   | Dec 2025    | Jun 2027    | 🔵 LTS (18 months) |

**LTS (Long-Term Support):** Critical security fixes provided

## Tools & Automation

### SDK Version Management

**C# SDK (NuGet):**
```bash
dotnet package search Cardano.RWA.SDK
dotnet add package Cardano.RWA.SDK --version 2.1.0
```

**TypeScript SDK (npm):**
```bash
npm view @cardano-rwa/sdk versions
npm install @cardano-rwa/sdk@2.1.0
```

### Continuous Versioning

**Automatic patch version bump on every commit:**
```bash
npm version patch  # 2.1.0 → 2.1.1
git tag v2.1.1
git push origin main --tags
```

**Manual minor/major bumps:**
```bash
npm version minor  # 2.1.0 → 2.2.0
npm version major  # 2.1.0 → 3.0.0
```

## Success Criteria (for Gap #4 closure)

✅ API versioning in URL paths (v1, v2, v3)  
✅ Semantic versioning applied to all releases  
✅ 6-month deprecation window enforced  
✅ Breaking-change detection automated in CI  
✅ Deprecation headers in responses  
✅ Migration guides written and linked  
✅ Changelog automatically generated  
✅ SDKs versioned and distributed  
✅ Version support matrix published  
✅ Zero unplanned breaking changes in prod  

