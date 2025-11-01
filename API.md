# API Architecture & OpenAPI Documentation

## Overview

The Cardano RWA Backend exposes a comprehensive REST API designed to interact with blockchain assets, IPFS storage, and PostgreSQL database.

## API Specifications

### Base URL

```
http://localhost:8080
```

### Version

```
v1.0.0
```

### Content Types

- **Request:** `application/json`
- **Response:** `application/json`

## Core Endpoints

### Health & Status

#### Health Check

```http
GET /health
```

**Response (200 OK):**
```json
{
  "status": "Healthy",
  "timestamp": "2025-11-01T12:00:00Z",
  "services": {
    "database": "Connected",
    "ipfs": "Connected",
    "cardano": "Synced"
  }
}
```

### Weather Forecast (Sample)

#### Get Weather Forecast

```http
GET /weatherforecast
```

**Parameters:**
- `startDate` (query) - Start date for forecast (ISO 8601)

**Response (200 OK):**
```json
[
  {
    "date": "2025-11-02",
    "temperatureC": 25,
    "temperatureF": 77,
    "summary": "Warm"
  },
  {
    "date": "2025-11-03",
    "temperatureC": 18,
    "temperatureF": 64,
    "summary": "Cool"
  }
]
```

## Service Integration Endpoints

### IPFS Integration

#### Upload File to IPFS

```http
POST /api/ipfs/upload
Content-Type: multipart/form-data

file: <binary>
```

**Response (200 OK):**
```json
{
  "ipfsHash": "QmXxxx...",
  "size": 1024,
  "timestamp": "2025-11-01T12:00:00Z",
  "gateway": "http://localhost:8080/ipfs/QmXxxx..."
}
```

#### Retrieve File from IPFS

```http
GET /api/ipfs/retrieve/{ipfsHash}
```

**Response (200 OK):**
- Returns file binary content
- Header: `Content-Type: application/octet-stream`

#### Pin File (Ensure Persistence)

```http
POST /api/ipfs/pin
Content-Type: application/json

{
  "ipfsHash": "QmXxxx..."
}
```

**Response (200 OK):**
```json
{
  "ipfsHash": "QmXxxx...",
  "pinned": true
}
```

### Cardano Blockchain

#### Get Node Status

```http
GET /api/cardano/health
```

**Response (200 OK):**
```json
{
  "network": "preview",
  "synced": true,
  "blockHeight": 1234567,
  "slotNumber": 890123
}
```

#### Query UTXOs

```http
POST /api/cardano/utxos
Content-Type: application/json

{
  "address": "addr_test1vqxxx..."
}
```

**Response (200 OK):**
```json
{
  "address": "addr_test1vqxxx...",
  "utxos": [
    {
      "txHash": "abc123...",
      "outputIndex": 0,
      "amount": "1000000",
      "assets": []
    }
  ]
}
```

#### Submit Transaction

```http
POST /api/cardano/submit-tx
Content-Type: application/json

{
  "signedTx": "base64-encoded-cbor"
}
```

**Response (200 OK):**
```json
{
  "txHash": "txhash123...",
  "submitted": true,
  "timestamp": "2025-11-01T12:00:00Z"
}
```

### RWA (Real World Assets)

#### Create Asset

```http
POST /api/rwa/assets
Content-Type: application/json

{
  "name": "Real Estate Token",
  "symbol": "RET",
  "totalSupply": "1000000",
  "description": "Tokenized real estate",
  "documentHash": "QmXxxx..." 
}
```

**Response (201 Created):**
```json
{
  "assetId": "uuid-1234",
  "policyId": "abcd1234...",
  "ipfsHash": "QmXxxx...",
  "status": "Created",
  "createdAt": "2025-11-01T12:00:00Z"
}
```

#### Get Asset Details

```http
GET /api/rwa/assets/{assetId}
```

**Response (200 OK):**
```json
{
  "assetId": "uuid-1234",
  "name": "Real Estate Token",
  "symbol": "RET",
  "totalSupply": "1000000",
  "circulating": "500000",
  "policyId": "abcd1234...",
  "ipfsHash": "QmXxxx...",
  "documentHash": "QmYyyy...",
  "status": "Active",
  "createdAt": "2025-11-01T12:00:00Z",
  "updatedAt": "2025-11-01T13:00:00Z"
}
```

#### List Assets

```http
GET /api/rwa/assets
```

**Query Parameters:**
- `skip` (query) - Number of records to skip (default: 0)
- `limit` (query) - Number of records to return (default: 20, max: 100)
- `status` (query) - Filter by status (Active, Inactive, Paused)
- `sortBy` (query) - Sort field (createdAt, name, totalSupply)
- `order` (query) - Sort order (asc, desc)

**Response (200 OK):**
```json
{
  "total": 42,
  "skip": 0,
  "limit": 20,
  "data": [
    {
      "assetId": "uuid-1234",
      "name": "Real Estate Token",
      "symbol": "RET",
      "totalSupply": "1000000",
      "status": "Active",
      "createdAt": "2025-11-01T12:00:00Z"
    }
  ]
}
```

## Error Handling

### Error Response Format

All errors follow a consistent format:

```json
{
  "error": {
    "code": "ERROR_CODE",
    "message": "Human-readable error message",
    "details": {
      "field": "Additional context"
    },
    "timestamp": "2025-11-01T12:00:00Z"
  }
}
```

### Common HTTP Status Codes

| Code | Meaning | Example |
|------|---------|---------|
| 200 | OK | Request successful |
| 201 | Created | Resource created |
| 400 | Bad Request | Invalid parameters |
| 401 | Unauthorized | Missing/invalid auth token |
| 403 | Forbidden | Insufficient permissions |
| 404 | Not Found | Resource not found |
| 409 | Conflict | Duplicate resource |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server Error | Server error |
| 503 | Service Unavailable | Service down |

### Example Error Response

```json
{
  "error": {
    "code": "INVALID_ADDRESS",
    "message": "Provided Cardano address is invalid",
    "details": {
      "address": "Invalid Bech32 encoding"
    },
    "timestamp": "2025-11-01T12:00:00Z"
  }
}
```

## Authentication & Authorization

### JWT Bearer Token

```http
Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

### Scopes

- `read:assets` - Read asset information
- `write:assets` - Create and modify assets
- `read:transactions` - Read transaction history
- `write:transactions` - Submit transactions
- `admin` - Full access

## Rate Limiting

### Headers

```http
X-RateLimit-Limit: 1000
X-RateLimit-Remaining: 999
X-RateLimit-Reset: 1730505600
```

### Limits by Endpoint

| Endpoint | Limit | Window |
|----------|-------|--------|
| Read endpoints | 1000 | 1 hour |
| Write endpoints | 100 | 1 hour |
| Blockchain | 50 | 1 hour |

## Response Pagination

### Query Parameters

- `skip` - Number of items to skip
- `limit` - Number of items per page (max 100)

### Response Structure

```json
{
  "total": 1234,
  "skip": 0,
  "limit": 20,
  "hasMore": true,
  "data": []
}
```

## OpenAPI/Swagger Documentation

### Access

- **Swagger UI:** `GET /swagger`
- **ReDoc:** `GET /redoc`
- **OpenAPI Spec:** `GET /openapi/v1.json`

### Download OpenAPI Spec

```bash
curl http://localhost:8080/openapi/v1.json > openapi.json
```

## Integration Examples

### cURL

```bash
# Get health status
curl http://localhost:8080/health

# Get assets
curl http://localhost:8080/api/rwa/assets

# Create asset
curl -X POST http://localhost:8080/api/rwa/assets \
  -H "Content-Type: application/json" \
  -d '{"name":"Token","symbol":"TKN","totalSupply":"1000000"}'
```

### JavaScript/TypeScript

```typescript
// Fetch assets
const response = await fetch('http://localhost:8080/api/rwa/assets');
const assets = await response.json();

// Create asset
const newAsset = await fetch('http://localhost:8080/api/rwa/assets', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    name: 'Token',
    symbol: 'TKN',
    totalSupply: '1000000'
  })
});
```

### Python

```python
import requests

# Get assets
response = requests.get('http://localhost:8080/api/rwa/assets')
assets = response.json()

# Create asset
new_asset = requests.post(
  'http://localhost:8080/api/rwa/assets',
  json={
    'name': 'Token',
    'symbol': 'TKN',
    'totalSupply': '1000000'
  }
)
```

## Webhooks (Planned)

Webhooks for real-time event notifications:

```http
POST /api/webhooks
Content-Type: application/json

{
  "url": "https://example.com/webhook",
  "events": ["asset.created", "tx.confirmed"],
  "active": true
}
```

## Versioning

The API uses semantic versioning. Future versions:

- `v1.x.x` - Current stable (backward compatible)
- `v2.0.0` - Next major version (planned)

## Deprecation Policy

Deprecated endpoints will:
1. Show warning headers: `Deprecation: true`
2. Continue working for 6 months
3. Include migration guide

## Support

- **Documentation:** `/swagger` or `/docs`
- **Issues:** GitHub Issues
- **Support Email:** support@trustiva.io

---

**Last Updated:** November 2025
**API Version:** 1.0.0
