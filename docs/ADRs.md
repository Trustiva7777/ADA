# Architecture Decision Records (ADRs)

## ADR-001: Why Cardano for RWA Tokenization

**Status:** Accepted  
**Date:** 2025-01-01  
**Author:** Engineering Team

### Context
We needed to choose a blockchain platform for real-world asset tokenization that prioritizes security, regulatory alignment, and sustainability.

### Decision
Use Cardano as the primary blockchain for RWA tokenization.

### Rationale
1. **Academic rigor:** Peer-reviewed, formally verified smart contracts
2. **Sustainability:** Proof-of-stake (energy efficient, no mining waste)
3. **Native assets:** Built-in multi-asset support (no wrapper tokens needed)
4. **Community:** Strong institutional backing and developer ecosystem
5. **Regulatory readiness:** Government partnerships (e.g., Switzerland, NMKR)
6. **Cost:** Low transaction fees for high-volume asset distributions

### Consequences
- Learning curve for team (different model vs. EVM)
- Smaller DeFi ecosystem (but growing)
- Requires Plutus/Haskell knowledge for advanced contracts

### Alternatives Considered
- Ethereum: High gas costs, saturated ecosystem
- Polygon: Good performance, but less regulatory clarity
- Solana: Fast, but less formal verification

---

## ADR-002: .NET + TypeScript for Multi-Layer Backend

**Status:** Accepted  
**Date:** 2025-01-02

### Context
Backend needed to handle API orchestration, compliance logic, and Cardano transaction building.

### Decision
Use ASP.NET Core 9 for API layer and TypeScript/Node.js for Cardano operations.

### Rationale
1. **.NET strengths:** Type safety, enterprise support, async/await maturity
2. **TypeScript strengths:** Cardano tooling ecosystem (Lucid, Mesh, blockfrost.js)
3. **Separation of concerns:** API gateway (.NET) talks to Cardano engine (TS)
4. **Development velocity:** Both languages have extensive libraries
5. **Testing:** Both have mature testing frameworks (xUnit, Jest)

### Consequences
- Two runtime environments (Docker complexity)
- Team needs both skill sets
- Integration testing more involved

---

## ADR-003: IPFS for Decentralized Evidence Storage

**Status:** Accepted  
**Date:** 2025-01-03

### Context
Evidence bundles (KYC docs, NI 43-101 reports, valuations) need decentralized, immutable storage for regulatory compliance.

### Decision
Use IPFS with Pinata/Fleek for pinning and Confidential Ledger for CIDs.

### Rationale
1. **Immutability:** IPFS content-addressed (hash-based)
2. **Decentralization:** No single point of failure
3. **Regulatory:** Auditable, tamper-proof evidence trail
4. **Cost:** Free to store, pay only for pinning
5. **Availability:** Multiple pinning services ensure uptime

### Consequences
- Eventual consistency (CID propagation delay ~1 min)
- Requires off-chain pinning service
- Evidence not on-chain (links in smart contracts instead)

---

## ADR-004: PostgreSQL for Audit & Compliance Data

**Status:** Accepted  
**Date:** 2025-01-04

### Context
KYC records, sanctions screening results, and audit logs need queryable, ACID-compliant storage.

### Decision
Use PostgreSQL with Row-Level Security (RLS) for multi-tenant data isolation.

### Rationale
1. **ACID guarantees:** No partial failures
2. **Auditability:** Full transaction history
3. **Security:** RLS for data isolation, encryption at rest
4. **Performance:** Optimized for complex queries
5. **Compliance:** Meets regulatory requirements (GDPR, SOC2)

### Consequences
- Requires careful schema design
- Need DBA expertise for large-scale deployments
- Backup/restore procedures critical

---

## ADR-005: Docker Compose for Local Development, Kubernetes for Production

**Status:** Accepted  
**Date:** 2025-01-05

### Context
Development environment needs to be reproducible. Production needs auto-scaling and high availability.

### Decision
Use Docker Compose for local dev (Cardano node, IPFS, Postgres, backend, frontend, monitoring).  
Use Kubernetes in production (EKS, GKE, or AKS).

### Rationale
1. **Local dev:** Docker Compose is simple, requires no cloud account
2. **Production:** K8s handles scaling, self-healing, rolling updates
3. **CI/CD:** Single container image builds for both environments
4. **Infrastructure as Code:** Helm charts for K8s deployments

### Consequences
- K8s complexity for operators
- Need DevOps expertise
- Requires additional monitoring (K8s metrics)

---

## ADR-006: Prometheus + Grafana for Observability

**Status:** Accepted  
**Date:** 2025-01-06

### Context
Production system needs metrics, alerting, and visualization for SLA compliance.

### Decision
Use Prometheus for metrics collection and Grafana for dashboards.  
Add OpenTelemetry for distributed tracing (Jaeger backend).

### Rationale
1. **Industry standard:** Prometheus is de facto for K8s monitoring
2. **Grafana:** Beautiful dashboards, easy alerting
3. **OpenTelemetry:** Vendor-neutral tracing standard
4. **Cost:** All open-source, self-hosted option available

### Consequences
- Storage overhead (retention = retention window)
- Requires alerting rules configuration
- Need on-call rotation for critical alerts

---

## ADR-007: Semantic Versioning for APIs and Releases

**Status:** Accepted  
**Date:** 2025-01-07

### Context
Breaking changes can break downstream integrations. Need clear versioning strategy.

### Decision
Adopt Semantic Versioning (MAJOR.MINOR.PATCH) for all releases.  
API versioning via URL path (v1, v2) with deprecation windows.

### Rationale
1. **Clarity:** Version numbers communicate breaking changes
2. **Deprecation:** 6-month window before removing old API versions
3. **Tooling:** Automated version bumping in CI/CD
4. **Changelog:** Automated generation from commit messages

### Consequences
- Requires discipline in commit messages
- Need deprecation warnings on old endpoints
- Multiple versions must be supported simultaneously

---

## ADR-008: GitOps for Infrastructure & Deployments

**Status:** Accepted  
**Date:** 2025-01-08

### Context
Infrastructure drift and manual deployments cause outages. Need single source of truth.

### Decision
Use Git as source of truth. ArgoCD for continuous deployment. All infrastructure in Git.

### Rationale
1. **Auditability:** Every change tracked in Git
2. **Rollback:** Revert commit = instant rollback
3. **Automation:** ArgoCD syncs desired state automatically
4. **Accountability:** Commit author = change owner

### Consequences
- All changes must go through Git (no manual kubectl)
- Requires Git branch protection rules
- Need to educate team on GitOps workflow

---

## ADR-009: End-to-End (E2E) Testing for Critical Flows

**Status:** Accepted  
**Date:** 2025-01-09

### Context
Unit tests miss integration bugs. Need confidence that mint → distribute → audit works end-to-end.

### Decision
Implement E2E tests for critical flows:
- Mint → distribute → audit
- KYC submit → approve → mint
- Compliance check → block → escalate

### Rationale
1. **Risk mitigation:** Catches integration bugs early
2. **Regression detection:** Prevents breaking existing flows
3. **Documentation:** Tests serve as live documentation
4. **Confidence:** Team can deploy with confidence

### Consequences
- Tests are slower (full system required)
- Flaky tests if infrastructure is unstable
- Need test data management

---

## ADR-010: Resilience4j (C#) for Circuit Breakers & Retry Logic

**Status:** Accepted  
**Date:** 2025-01-10

### Context
External dependencies (Blockfrost, Ogmios, IPFS) can fail. Need graceful degradation.

### Decision
Use Resilience4j (Polly in C#) for circuit breakers, retry strategies, and timeouts.

### Rationale
1. **Fault isolation:** Prevents cascade failures
2. **Auto-recovery:** Exponential backoff with jitter
3. **Observability:** Metrics on circuit state
4. **Testability:** Easy to mock failures

### Consequences
- Configuration complexity
- Need metrics dashboards for circuit health
- Requires fallback strategies for each dependency

---

## Versioning & Governance

**Last Updated:** 2025-01-15  
**Review Cycle:** Quarterly  
**Change Process:** New ADRs require team consensus, 2 approvals minimum
