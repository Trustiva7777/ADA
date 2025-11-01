# System Architecture & Diagrams

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        End Users                                 │
└──────────────────────────┬──────────────────────────────────────┘
                          │
                   ┌──────▼──────┐
                   │  Frontend   │
                   │  (Blazor)   │
                   └──────┬──────┘
                          │
     ┌────────────────────┴─────────────────────┐
     │                                          │
┌────▼──────────────┐          ┌─────────────────▼──────┐
│   Backend API    │          │   Monitoring Stack     │
│  (.NET Core)     │◄────────►│  (Prometheus/Grafana)  │
└────┬──────────────┘          └────────────────────────┘
     │
     ├──────────┬──────────┬──────────┐
     │          │          │          │
┌────▼─────┐ ┌─▼──────┐ ┌─▼──────┐ ┌─▼──────┐
│ Database │ │ IPFS   │ │Cardano │ │ Vault  │
│(Postgres)│ │ Node   │ │ Network│ │(Future)│
└──────────┘ └────────┘ └────────┘ └────────┘
```

## Component Interaction Diagram

```
User Interface Layer
│
├─ Frontend (Blazor Server)
│  ├─ Pages
│  │  ├─ FetchData.razor
│  │  ├─ Weather.razor
│  │  └─ Assets.razor
│  │
│  └─ Data Layer
│     ├─ WeatherForecastClient
│     ├─ AssetClient
│     └─ CardanoClient

API Layer
│
├─ Backend REST API (.NET Core)
│  ├─ Controllers
│  │  ├─ WeatherController
│  │  ├─ AssetsController
│  │  ├─ CardanoController
│  │  └─ IpfsController
│  │
│  └─ Services
│     ├─ CardanoService
│     ├─ IpfsService
│     ├─ AssetService
│     └─ BlockchainService

Data & Storage Layer
│
├─ PostgreSQL Database
│  ├─ Assets Table
│  ├─ Transactions Table
│  ├─ Users Table
│  └─ Audit Log Table
│
├─ IPFS Decentralized Storage
│  ├─ Document Storage
│  ├─ Metadata Storage
│  └─ Archive Storage
│
└─ Cardano Blockchain
   ├─ Ogmios (Query Layer)
   ├─ Submit API (TX Submission)
   └─ Native Tokens
```

## Data Flow Diagram

```
Asset Creation Flow
└─ User creates asset via Frontend
   └─ Frontend sends request to Backend
      └─ Backend validates input
         ├─ Store metadata in PostgreSQL
         ├─ Upload documents to IPFS
         ├─ Generate IPFS hash
         ├─ Mint token on Cardano
         └─ Store transaction hash in PostgreSQL
         └─ Return asset ID and details to Frontend
         └─ Frontend displays confirmation

Transaction Flow
└─ User submits transaction
   └─ Backend receives TX data
      ├─ Validate transaction format
      ├─ Check UTXO availability
      ├─ Submit to Cardano network
      ├─ Wait for confirmation
      └─ Store confirmation in PostgreSQL
```

## Network Topology

```
Internet
│
└─ Docker Bridge Network (app-net)
   │
   ├─ Frontend (8081)
   │  └─ Blazor Server UI
   │
   ├─ Backend (8080)
   │  └─ REST API
   │  └─ Metrics (9100)
   │
   ├─ PostgreSQL (5432)
   │  └─ Primary Database
   │
   ├─ IPFS (5001, 8080)
   │  └─ Content Storage
   │  └─ HTTP Gateway
   │
   ├─ Cardano Node (3001)
   │  └─ Blockchain Node
   │  └─ IPC Socket
   │
   ├─ Ogmios (1337)
   │  └─ Query API
   │
   ├─ Prometheus (9090)
   │  └─ Metrics Collection
   │
   └─ Grafana (3000)
      └─ Metrics Visualization
```

## Deployment Architecture

```
Production Environment (AWS)
│
├─ Load Balancer (ALB)
│  │
│  ├─ ECS Cluster 1
│  │  ├─ Frontend Container (Multiple)
│  │  └─ Backend Container (Multiple)
│  │
│  └─ RDS PostgreSQL
│     └─ Multi-AZ Replication
│
├─ Cardano Infrastructure
│  ├─ Cardano Nodes (Relay + Producer)
│  ├─ Ogmios Cluster
│  └─ Kupo Indexer
│
├─ Storage
│  ├─ S3 for Backups
│  └─ IPFS Cluster
│
└─ Monitoring
   ├─ CloudWatch
   ├─ Prometheus (Self-Hosted)
   └─ Grafana (Self-Hosted)
```

## Security Architecture

```
Users
│
├─ API Gateway (Authentication)
│  ├─ JWT Verification
│  ├─ Rate Limiting
│  └─ CORS Policy
│
├─ Backend Services
│  ├─ Role-Based Access Control
│  ├─ Input Validation
│  └─ SQL Injection Prevention
│
├─ Data Encryption
│  ├─ TLS/HTTPS
│  ├─ Database Encryption (at-rest)
│  └─ Secrets Management (Vault)
│
└─ Blockchain Security
   ├─ Signature Verification
   ├─ Address Validation
   └─ Transaction Authorization
```

## Database Schema Overview

```
Users
├─ id (UUID)
├─ email (String)
├─ walletAddress (String)
└─ createdAt (DateTime)

Assets
├─ id (UUID)
├─ name (String)
├─ symbol (String)
├─ policyId (String)
├─ ipfsHash (String)
├─ status (Enum)
└─ createdAt (DateTime)

Transactions
├─ id (UUID)
├─ assetId (FK)
├─ txHash (String)
├─ type (Enum)
├─ status (Enum)
└─ createdAt (DateTime)

AuditLog
├─ id (UUID)
├─ userId (FK)
├─ action (String)
├─ resource (String)
├─ timestamp (DateTime)
└─ details (JSON)
```

## Sequence Diagrams

### Asset Minting Flow

```
User → Frontend → Backend → PostgreSQL
  │       │        │          │
  │       │──GET──►│          │
  │       │        │──INSERT──►
  │       │        │          │
  │       │        ├─IPFS────►(Upload)
  │       │        │          │
  │       │        ├─Cardano──►(Submit)
  │       │        │          │
  │       │◄──RES──┤          │
  │◄──OK──┤        │          │
  │       │        │          │
```

### Query Asset Details

```
User → Frontend → Backend → PostgreSQL
  │       │        │          │
  │       │─GET───►│          │
  │       │        │──SELECT─►
  │       │        │          │
  │       │        │◄─Result──
  │       │◄──200──┤          │
  │◄──UI──┤        │          │
  │       │        │          │
```

### IPFS Upload Flow

```
Backend → IPFS API → IPFS Node → Blockchain
   │         │          │          │
   │─POST───►│          │          │
   │         │──Store──►│          │
   │         │          │──Pin────►
   │         │          │          │
   │◄─Hash───┤◄─Confirm─┤◄─Confirm─
   │         │          │          │
```

## Monitoring Metrics

### Key Metrics by Component

**Frontend:**
- Page Load Time
- API Response Time
- Error Rate
- User Sessions

**Backend:**
- Request Rate
- Response Time (p50, p95, p99)
- Error Rate (4xx, 5xx)
- Database Query Time

**Database:**
- Connections
- Query Execution Time
- Replication Lag
- Disk Usage

**Blockchain:**
- Block Height
- Slot Number
- Transaction Confirmation Time
- Network Connectivity

**IPFS:**
- File Upload Time
- File Retrieval Time
- Node Peers
- Disk Usage

## Deployment Pipeline

```
Developer Push
│
├─ GitHub Commit
│  └─ Trigger CI/CD
│
├─ Build Stage
│  ├─ .NET Build
│  ├─ Unit Tests
│  └─ Code Analysis
│
├─ Docker Build
│  ├─ Backend Image
│  ├─ Frontend Image
│  └─ Push to Registry
│
├─ Test Stage
│  ├─ Integration Tests
│  ├─ Smoke Tests
│  └─ Security Scan
│
├─ Deploy Stage
│  ├─ Dev Environment
│  ├─ Staging Environment
│  └─ Production Environment
│
└─ Monitoring
   ├─ Health Checks
   ├─ Performance Metrics
   └─ Error Alerts
```

## Scalability Architecture

```
Multiple Frontend Instances
│
├─ Frontend 1 (Blazor)
├─ Frontend 2 (Blazor)
├─ Frontend 3 (Blazor)
│
└─ Load Balancer

Multiple Backend Instances
│
├─ Backend 1 (API)
├─ Backend 2 (API)
├─ Backend 3 (API)
│
└─ Load Balancer

Shared Services
│
├─ PostgreSQL (Read Replicas)
├─ Redis (Distributed Cache)
├─ IPFS Cluster (Multiple Nodes)
└─ Cardano Infrastructure
```

## Disaster Recovery

```
Primary Data Center
│
├─ Active Databases
├─ Running Services
└─ Real-time Backups
   │
   ├─ S3 Backup (AWS)
   ├─ Backup Database (Standby)
   └─ IPFS Replication
   │
   └─ Failover Trigger
      │
      └─ Secondary Data Center
         ├─ Restore from Backup
         ├─ Update DNS
         └─ Resume Operations
```

---

**Last Updated:** November 2025
**Version:** 1.0
