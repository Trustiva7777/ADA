# 📚 API Documentation

Complete REST API reference for the Cardano RWA Platform.

## Base URL

```
Production: https://api.cardano-rwa.io
Staging:    https://staging-api.cardano-rwa.io
Local:      http://localhost:8080
```

## Authentication

All endpoints require authentication via Bearer token or API key.

```bash
curl -H "Authorization: Bearer YOUR_TOKEN" \
     http://localhost:8080/api/endpoint
```

## Core Endpoints

### Health & Status

#### Get System Health

```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00Z",
  "services": {
    "database": "ok",
    "blockchain": "ok",
    "ipfs": "ok"
  }
}
```

### Token Operations

#### List All Tokens

```http
GET /api/tokens
```

**Query Parameters:**
- `skip` (integer): Skip first N tokens (default: 0)
- `limit` (integer): Max tokens to return (default: 100)
- `status` (string): Filter by status (active, locked, ended)

**Response:**
```json
{
  "data": [
    {
      "id": "token-001",
      "ticker": "QH-R1",
      "name": "Quebrada Honda Royalty I",
      "policyId": "d7d6e6415f0e01d668a8dbb4fc3a....",
      "status": "active",
      "supply": "1000000",
      "decimals": 2,
      "createdAt": "2024-01-15T10:00:00Z"
    }
  ],
  "total": 1,
  "page": 1
}
```

#### Get Token Details

```http
GET /api/tokens/{tokenId}
```

**Response:**
```json
{
  "id": "token-001",
  "ticker": "QH-R1",
  "name": "Quebrada Honda Royalty I",
  "description": "Mining royalty token for QH operations",
  "policyId": "d7d6e6415f0e01d668a8dbb4fc3a...",
  "supply": "1000000",
  "decimals": 2,
  "status": "active",
  "metadata": {
    "image": "ipfs://QmXxxx",
    "website": "https://quebradahonda.com"
  },
  "attestation": {
    "hash": "abc123...",
    "ipfsUri": "ipfs://QmXxxx",
    "timestamp": "2024-01-15T10:00:00Z"
  },
  "createdAt": "2024-01-15T10:00:00Z",
  "lockedAt": "2024-03-31T10:00:00Z",
  "lockDeadline": "2024-04-30T10:00:00Z"
}
```

### Holders & Distribution

#### Get Token Holders

```http
GET /api/tokens/{tokenId}/holders
```

**Query Parameters:**
- `skip`: Skip first N holders
- `limit`: Max holders to return
- `sort`: Sort by (balance, name)
- `verified`: Filter by KYC status (true/false)

**Response:**
```json
{
  "data": [
    {
      "address": "addr_test1qp2f27jrxnkxvh2r8cr108z3k2aty8wee8qyy0sxu57gf...",
      "name": "Investor A",
      "balance": "50000",
      "proRata": 0.05,
      "kyc": {
        "status": "verified",
        "verifiedAt": "2024-01-10T15:30:00Z"
      },
      "distributions": 2
    }
  ],
  "total": 20,
  "page": 1
}
```

#### Get Distribution History

```http
GET /api/tokens/{tokenId}/distributions
```

**Query Parameters:**
- `status`: Filter by (pending, completed, failed)
- `startDate`: ISO date
- `endDate`: ISO date

**Response:**
```json
{
  "data": [
    {
      "id": "dist-001",
      "round": 1,
      "status": "completed",
      "totalAmount": "100000",
      "currency": "USD",
      "totalAda": "500000",
      "totalTransactions": 20,
      "successfulTransactions": 20,
      "failedTransactions": 0,
      "createdAt": "2024-01-15T10:00:00Z",
      "completedAt": "2024-01-16T14:30:00Z"
    }
  ],
  "total": 1
}
```

#### Plan Distribution

```http
POST /api/tokens/{tokenId}/distributions/plan
```

**Request Body:**
```json
{
  "holders": [
    {
      "address": "addr_test1qp...",
      "amount": "100.50"
    }
  ],
  "currency": "USD",
  "description": "Q1 2024 Payout"
}
```

**Response:**
```json
{
  "planId": "plan-001",
  "status": "ready",
  "holders": 10,
  "totalAmount": "10000.00",
  "totalAda": "50000000",
  "transactions": 10,
  "estimatedFees": "2000000",
  "createdAt": "2024-01-15T10:00:00Z"
}
```

### Compliance & KYC

#### Get Allowlist

```http
GET /api/tokens/{tokenId}/allowlist
```

**Response:**
```json
{
  "data": [
    {
      "address": "addr_test1qp...",
      "name": "Investor A",
      "status": "approved",
      "kyc": {
        "status": "verified",
        "level": "enhanced",
        "verifiedAt": "2024-01-10T15:30:00Z"
      },
      "restrictions": [],
      "addedAt": "2024-01-10T10:00:00Z"
    }
  ],
  "total": 20,
  "hash": "abc123..."
}
```

#### Add Address to Allowlist

```http
POST /api/tokens/{tokenId}/allowlist
```

**Request Body:**
```json
{
  "address": "addr_test1qp2f27jrxnkxvh2r8cr108z3k2aty...",
  "name": "New Investor",
  "kycStatus": "verified",
  "kycLevel": "standard"
}
```

**Response:**
```json
{
  "success": true,
  "address": "addr_test1qp...",
  "allowlistHash": "def456...",
  "attestationUpdated": true
}
```

#### Verify Address on Allowlist

```http
GET /api/tokens/{tokenId}/allowlist/{address}/verify
```

**Response:**
```json
{
  "address": "addr_test1qp...",
  "isAllowed": true,
  "kyc": {
    "status": "verified",
    "level": "enhanced"
  },
  "verificationTimestamp": "2024-01-15T10:30:00Z"
}
```

### Evidence & Attestation

#### Get Token Attestation

```http
GET /api/tokens/{tokenId}/attestation
```

**Response:**
```json
{
  "policyId": "d7d6e6415f0e01d668a8dbb4fc3a...",
  "manifestHash": "abc123def456...",
  "allowlistHash": "def456abc123...",
  "beforeSlot": 50000000,
  "ipfsUri": "ipfs://QmXxxx",
  "signature": "sig_...",
  "createdAt": "2024-01-15T10:00:00Z",
  "evidence": {
    "ni43101": "ipfs://QmXxxx",
    "valuation": "ipfs://QmXxxx",
    "legal": "ipfs://QmXxxx"
  }
}
```

#### Upload Evidence

```http
POST /api/tokens/{tokenId}/evidence
```

**Request Body:** (multipart/form-data)
```
{
  "file": <binary>,
  "type": "ni43101|valuation|legal|other",
  "description": "NI 43-101 Technical Report"
}
```

**Response:**
```json
{
  "success": true,
  "ipfs": "ipfs://QmXxxx",
  "hash": "abc123...",
  "type": "ni43101",
  "uploadedAt": "2024-01-15T10:30:00Z"
}
```

#### Build Proof Manifest

```http
POST /api/proofs/build-manifest
```

**Request Body:**
```json
{
  "evidence": [
    {
      "name": "NI 43-101 Report",
      "ipfs": "ipfs://QmXxxx",
      "hash": "abc123..."
    }
  ]
}
```

**Response:**
```json
{
  "manifestHash": "abc123def456...",
  "manifest": {
    "files": [...],
    "timestamp": "2024-01-15T10:30:00Z",
    "version": "1.0"
  },
  "ipfs": "ipfs://QmXxxx"
}
```

### Policy Management

#### Plan Policy Lock

```http
POST /api/policy/plan-lock
```

**Request Body:**
```json
{
  "lockDays": 45,
  "network": "Preprod"
}
```

**Response:**
```json
{
  "currentSlot": 30000000,
  "lockSlot": 30000000 + (45 * 86400),
  "lockTime": "2024-03-01T10:00:00Z",
  "network": "Preprod"
}
```

#### Get Policy Status

```http
GET /api/policy/{policyId}/status
```

**Response:**
```json
{
  "policyId": "d7d6e6415f0e01d668a8dbb4fc3a...",
  "status": "locked",
  "lockSlot": 50000000,
  "currentSlot": 40000000,
  "isLocked": false,
  "canMint": true,
  "nextActionAt": "2024-03-01T10:00:00Z"
}
```

### Minting

#### Mint Tokens

```http
POST /api/mint
```

**Request Body:**
```json
{
  "policyId": "d7d6e6415f0e01d668a8dbb4fc3a...",
  "ticker": "QH-R1",
  "amount": "1000000",
  "decimals": 2,
  "name": "Quebrada Honda Royalty I",
  "ipfsUri": "ipfs://QmXxxx"
}
```

**Response:**
```json
{
  "transactionId": "tx-001",
  "status": "submitted",
  "txHash": "abcdef123456...",
  "policyId": "d7d6e6415f0e01d668a8dbb4fc3a...",
  "amount": "1000000",
  "fee": "170000",
  "submittedAt": "2024-01-15T10:30:00Z"
}
```

#### Get Mint Status

```http
GET /api/mint/{transactionId}/status
```

**Response:**
```json
{
  "transactionId": "tx-001",
  "status": "confirmed",
  "txHash": "abcdef123456...",
  "blockHeight": 9999999,
  "confirmations": 150,
  "policyId": "d7d6e6415f0e01d668a8dbb4fc3a...",
  "confirmedAt": "2024-01-15T11:00:00Z"
}
```

## Error Responses

All endpoints return errors in this format:

```json
{
  "error": "error_code",
  "message": "Human readable error message",
  "details": {
    "field": "Specific validation error"
  },
  "timestamp": "2024-01-15T10:30:00Z"
}
```

### Common Error Codes

| Code | HTTP | Meaning |
|------|------|---------|
| `invalid_token` | 401 | Authentication token invalid or expired |
| `forbidden` | 403 | User doesn't have permission |
| `not_found` | 404 | Resource doesn't exist |
| `conflict` | 409 | Resource already exists or state conflict |
| `validation_error` | 422 | Request validation failed |
| `rate_limit_exceeded` | 429 | Too many requests |
| `internal_error` | 500 | Server error |

## Rate Limiting

All endpoints are rate limited to 100 requests per minute per API key.

**Headers:**
```
X-RateLimit-Limit: 100
X-RateLimit-Remaining: 95
X-RateLimit-Reset: 1705326600
```

## Pagination

List endpoints support pagination:

**Query Parameters:**
- `skip`: Number of items to skip (default: 0)
- `limit`: Max items per page (default: 100, max: 1000)

**Response:**
```json
{
  "data": [...],
  "total": 250,
  "skip": 0,
  "limit": 100,
  "page": 1,
  "pages": 3
}
```

## Webhook Events

Subscribe to events:

```http
POST /api/webhooks
```

**Events:**
- `token.minted`: Token minting completed
- `distribution.completed`: Distribution round completed
- `allowlist.updated`: Allowlist changed
- `attestation.created`: New attestation signed

## SDKs

Official SDKs available:

- **Python**: `pip install cardano-rwa`
- **JavaScript/TypeScript**: `npm install @cardano-rwa/sdk`
- **Go**: `go get github.com/cardano-rwa/go-sdk`

## Interactive Documentation

Try the API interactively:

- **Swagger UI**: http://localhost:8080/swagger
- **Scalar**: http://localhost:8080/scalar
- **Postman**: Import collection from GitHub

---

**Last Updated**: January 2024  
**API Version**: 1.0
