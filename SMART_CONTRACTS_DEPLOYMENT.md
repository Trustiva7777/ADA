# QH I & II Smart Contract System — Deployment & Integration Guide

**Version:** 1.0.0  
**Date:** October 31, 2025  
**Copyright © 2025 Trustiva / Quebrada Honda Project**

---

## 📋 Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Contract Deployment](#contract-deployment)
3. [Integration with .NET Backend](#integration-with-net-backend)
4. [Multi-Stablecoin Settlement](#multi-stablecoin-settlement)
5. [CBDC Adapter Pattern](#cbdc-adapter-pattern)
6. [Monthly Distribution Flow](#monthly-distribution-flow)
7. [Security & Audits](#security--audits)
8. [Mainnet Checklist](#mainnet-checklist)

---

## 🏗️ Architecture Overview

### Core System Components

```
┌──────────────────────────────────────────────────────┐
│         QHSecurityToken (Main Token)                 │
│  - ERC-20 compliant                                  │
│  - UUPS Upgradeable (timelocked)                     │
│  - Compliance-gated (allowlist + sanctions)          │
│  - Snapshot-enabled (cap-table)                      │
│  - Distribution-triggered                           │
└──────────────────────────────────────────────────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
    ┌────▼──────┐  ┌─────▼──────┐  ┌────▼──────┐
    │Attestation│  │ Valuation  │  │Settlement │
    │ Registry  │  │   Engine   │  │  Router   │
    └────┬──────┘  └─────┬──────┘  └────┬──────┘
         │               │              │
         │  (immutable)   │ (NSR calc)  │ (multi-coin)
         │               │              │
    ┌────▼──────────────────────────────▼──────┐
    │      Compliance Registry                  │
    │  - Allowlist                              │
    │  - Sanctions screening                    │
    │  - Lockup tracking                        │
    └───────────────────────────────────────────┘
```

### Data Flow (Monthly Cycle)

```
Operations (Chile)
    │
    ├─ Production CSV (ROM, grades, recoveries)
    ├─ Assay CSV (concentrate analysis)
    ├─ Shipment CSV (destination, weight)
    └─ Payment CSV (smelter receipt, value)
         │
         ▼
.NET Backend (Validation & Hashing)
         │
         ├─ SHA-256 hash each CSV
         ├─ IPFS upload (immutable storage)
         └─ Merkle tree construction
         │
         ▼
AttestationRegistry.submitAttestation()
         │
         ├─ Record dataHash
         ├─ Link to IPFS CID
         └─ Emit events
         │
         ▼
Independent Reviewer (QP/Engineer)
         │
         └─ AttestationRegistry.verifyCycle()
         │
         ▼
ValuationEngine.executeDistribution()
         │
         ├─ Decode production data
         ├─ Pull commodity prices (oracle)
         ├─ Calculate waterfall (10-step)
         └─ Return: tokeholderShare, reserves
         │
         ▼
SettlementRouter.queueDistribution()
         │
         ├─ Queue in USDC / USDT / USDE / EURC
         └─ Or bridge to CBDC (future)
         │
         ▼
Tokenholders.claimDistribution()
         │
         └─ Receive in preferred stablecoin
```

---

## 🚀 Contract Deployment

### Prerequisites

```bash
# Node.js 18+
node --version

# Hardhat
npm install --global hardhat

# Git
git --version
```

### Step 1: Install Dependencies

```bash
cd /workspaces/dotnet-codespaces/contracts
npm install

# OpenZeppelin contracts & upgradeable
npm install @openzeppelin/contracts-upgradeable @openzeppelin/hardhat-upgrades

# Ethers.js v6
npm install ethers@6

# Chainlink Oracle
npm install @chainlink/contracts
```

### Step 2: Configure Environment

```bash
cp .env.example .env
```

Fill in `.env`:

```env
# Network RPC
MAINNET_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY
POLYGON_RPC_URL=https://polygon-mainnet.g.alchemy.com/v2/YOUR_KEY
SEPOLIA_RPC_URL=https://eth-sepolia.alchemyapi.io/v2/YOUR_KEY

# Private Keys (never commit!)
DEPLOYER_PRIVATE_KEY=0x...
ADMIN_PRIVATE_KEY=0x...

# Addresses
USDC_MAINNET=0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
USDT_MAINNET=0xdAC17F958D2ee523a2206206994597C13D831ec7
USDE_MAINNET=0x4c9EDD5852cd905f23a3e62f018B1D14766f6b3c
EURC_MAINNET=0x60a3E35Cc302bFA44Cb288Bc5a4F3873666843cb

# External Services
ETHERSCAN_API_KEY=YOUR_KEY
IPFS_GATEWAY=https://gateway.pinata.cloud
AWS_S3_BUCKET=qh-attestations-prod
```

### Step 3: Compile Contracts

```bash
npx hardhat compile

# Output should show:
# ✓ Compiled 7 contracts successfully
```

### Step 4: Run Tests

```bash
# Unit tests
npx hardhat test

# With coverage
npx hardhat coverage

# Expected output: >95% coverage
```

### Step 5: Deploy to Testnet (Sepolia)

```bash
npx hardhat run scripts/deployTestnet.js --network sepolia

# Output:
# Deploying QHSecurityToken...
# QHSecurityToken deployed to: 0x...
#
# Deploying ValuationEngine...
# ValuationEngine deployed to: 0x...
#
# Deploying SettlementRouter...
# SettlementRouter deployed to: 0x...
#
# Deploying AttestationRegistry...
# AttestationRegistry deployed to: 0x...
#
# All contracts deployed successfully!
```

### Step 6: Verify on Etherscan

```bash
npx hardhat verify --network sepolia 0xQHSecurityToken_ADDRESS
npx hardhat verify --network sepolia 0xValuationEngine_ADDRESS
npx hardhat verify --network sepolia 0xSettlementRouter_ADDRESS
npx hardhat verify --network sepolia 0xAttestationRegistry_ADDRESS
```

### Step 7: Deploy to Mainnet

```bash
# Review deployment params
cat scripts/deploy-mainnet-params.json

# Deploy (requires multi-sig approval)
npx hardhat run scripts/deploy.js --network mainnet

# Monitor transactions
# (Use Etherscan to verify all calls succeed)
```

---

## 🔗 Integration with .NET Backend

### API Endpoints (Cardano RWA Backend)

The `.NET/SampleApp/BackEnd` exposes REST APIs for contract interaction:

#### 1. Submit Attestation

```
POST /api/attestations/submit

Request Body:
{
  "cycleId": 202410,
  "productionData": {
    "rom": 25000,
    "headGradeCu": 6.2,
    "headGradeAu": 10.5,
    "headGradeAg": 51,
    "recoveryCu": 84,
    "recoveryAu": 85,
    "recoveryAg": 82,
    "concTonnes": 2150,
    "concGradeCu": 22.1
  },
  "assayData": "IPFS://QmXxxx...",
  "shipmentData": "IPFS://QmYyyy...",
  "paymentData": "IPFS://QmZzzz..."
}

Response:
{
  "attestationHash": "0x...",
  "ipfsCID": "QmAbcd1234...",
  "transactionHash": "0x...",
  "blockNumber": 18901234,
  "contractAddress": "0xAttestationRegistry..."
}
```

#### 2. Execute Distribution

```
POST /api/distributions/execute

Request Body:
{
  "cycleId": 202410,
  "attestationHash": "0x...",
  "commodityPrices": {
    "cuPrice": 1094900,  // $10,949/tonne in cents
    "auPrice": 401668,   // $4,016.68/oz in cents
    "agPrice": 4884,     // $48.84/oz in cents
    "fxRate": 950        // USD/CLP
  }
}

Response:
{
  "cycleId": 202410,
  "grossValue": 143500000,
  "tokeholderShare": 83800000,
  "reservedAmount": 7300000,
  "waterfall": {
    "tcrc": 21500000,
    "penalties": 1400000,
    "logistics": 500000,
    "siteOpex": 2800000,
    "corporateTax": 26200000,
    "dividendWithholding": 13600000
  },
  "transactionHash": "0x...",
  "blockNumber": 18901235
}
```

#### 3. Process Claim

```
POST /api/distributions/claim

Request Body:
{
  "cycleId": 202410,
  "holderAddress": "0x...",
  "preferredStablecoin": "USDC",
  "walletAddress": "0x..."
}

Response:
{
  "cycleId": 202410,
  "amount": 1234567890,  // In stablecoin units
  "stablecoin": "USDC",
  "transactionHash": "0x...",
  "claimId": "CLAIM_202410_0x..."
}
```

#### 4. Query Valuation (Real-Time)

```
GET /api/valuations/current

Response:
{
  "tokenNAV": 22.45,  // USD per token
  "grossMetal": 143500000,
  "netDistributable": 91100000,
  "tokenholderShare": 83800000,
  "commodityPrices": {
    "cu": 10949,
    "au": 4016.68,
    "ag": 48.84
  },
  "lastUpdate": "2025-10-31T16:30:00Z",
  "scenarioAnalysis": {
    "low": 16.84,   // 25% price decline
    "base": 22.45,
    "high": 28.06   // 25% price increase
  }
}
```

### Backend Integration Code (Example)

```csharp
// BackEnd/Services/BlockchainService.cs

public class BlockchainService
{
    private readonly IWeb3 _web3;
    private readonly QHSecurityTokenContract _tokenContract;
    private readonly ValuationEngineContract _valuationContract;
    private readonly AttestationRegistryContract _attestationContract;

    public async Task<AttestationResponse> SubmitAttestationAsync(
        int cycleId,
        ProductionData productionData,
        string ipfsCID)
    {
        // Hash production data
        var dataHash = Sha256Hash(JsonConvert.SerializeObject(productionData));

        // Call AttestationRegistry.submitAttestation()
        var tx = await _attestationContract.SubmitAttestationAsync(
            cycleId,
            "Production",
            dataHash,
            ipfsCID,
            "" // s3Uri
        );

        await tx.WaitForReceiptAsync();

        return new AttestationResponse
        {
            AttestationHash = dataHash,
            IpfsCID = ipfsCID,
            TransactionHash = tx.TransactionHash,
            BlockNumber = tx.BlockNumber.ToString()
        };
    }

    public async Task<DistributionResponse> ExecuteDistributionAsync(
        int cycleId,
        CommodityPrices prices)
    {
        // Call ValuationEngine.executeDistribution()
        var (tokeholderShare, reservedAmount) = await _valuationContract
            .ExecuteDistributionAsync(
                cycleId,
                "0x...", // attestationData (packed)
                new[] { prices.Cu, prices.Au, prices.Ag, prices.FxRate }
            );

        return new DistributionResponse
        {
            CycleId = cycleId,
            TokeholderShare = tokeholderShare,
            ReservedAmount = reservedAmount
        };
    }

    public async Task<ClaimResponse> ProcessClaimAsync(
        int cycleId,
        string holderAddress,
        string preferredStablecoin)
    {
        // Call SettlementRouter.processClaim()
        var tx = await _settlementContract.ProcessClaimAsync(
            cycleId,
            holderAddress,
            preferredStablecoin
        );

        await tx.WaitForReceiptAsync();

        return new ClaimResponse
        {
            CycleId = cycleId,
            TransactionHash = tx.TransactionHash
        };
    }
}
```

---

## 💵 Multi-Stablecoin Settlement

### Supported Stablecoins (V1.0)

| Stablecoin | Chain | Address | Liquidity | Holder Choice |
|-----------|-------|---------|-----------|---------------|
| USDC | Ethereum | 0xA0b8... | $100M+ | ✅ Yes |
| USDT | Ethereum | 0xdAC1... | $100M+ | ✅ Yes |
| USDE | Ethereum | 0x4c9E... | $50M+ | ✅ Yes |
| EURC | Ethereum | 0x60a3... | $20M+ | ✅ Yes |
| USDC | Polygon | 0x2791... | $50M+ | ✅ Yes |
| USDT | Polygon | 0xc2D0... | $50M+ | ✅ Yes |

### Settlement Flow

```
Tokenholder (e.g., 100 tokens)
    │
    ├─ Requests: claimDistribution(cycleId=202410, stablecoin=USDC)
    │
    ▼
QHSecurityToken.claimDistribution()
    │
    ├─ Get balance at snapshot: 100 tokens
    ├─ Get total supply at snapshot: 1,000,000 tokens
    ├─ Pro-rata share: 100/1,000,000 × 83,800,000 USD = 8,380 USD
    │
    ▼
SettlementRouter.processClaim()
    │
    ├─ Check USDC liquidity: ✅ (has $10M+)
    ├─ Deduct settlement fee (0.1%): 8.38 USD
    ├─ Net to holder: 8,371.62 USDC
    │
    ▼
USDC Transfer to Holder Wallet
    │
    └─ 8,371.62 USDC received in ~15 seconds
```

### Liquidity Management

Issuer must maintain adequate liquidity for all supported stablecoins:

```bash
# Check USDC balance
Balance: 100,000,000 USDC = $100M
Monthly distribution: $83,800,000 (peak case)
Required buffer: 20% = $16,760,000
Current reserve: 100M - 83.8M = 16.2M ✅ Sufficient
```

For scale-up (Phase 2–4 scenarios with 300k–2000k t/month):
- Monitor cash outflows monthly
- Maintain 30-day runway ($100M+ liquidity pool)
- Use multi-stablecoin diversification to avoid single-coin concentration

---

## 🏦 CBDC Adapter Pattern

### Future Digital Currency Support

```solidity
// Future: Integration with Federal Reserve digital dollar

interface IFedDigitalDollarBridge {
    function bridgeToFedNow(
        address holder,
        uint256 amount,
        string calldata bankRoutingNumber
    ) external returns (bool);
}

// Usage in SettlementRouter:
// processClaimViaCBDC(202410, holder, 8380, "USD")
// → routes to FedNow bridge → holder's bank account (real-time settlement)
```

### Supported Future CBDCs (Roadmap)

| Currency | Status | Expected Launch | Integration |
|----------|--------|-----------------|-------------|
| Digital USD (FedNow) | 🔄 Planned | 2026 | IFedDigitalDollarBridge |
| Digital Euro (eEUR) | 🔄 Planned | 2025 | IDigitalEuroBridge |
| Bank of Canada CBDC | 📋 Design | 2027 | ICADCBridge |

---

## 📅 Monthly Distribution Flow

### Full Cycle Example (October 2025)

**T+0 (Oct 1–31): Operations**
- Mine ROM: 25,000 tonnes
- Process and concentrate
- Generate assays, shipments, payments CSVs

**T+1 (Nov 1, Morning):** .NET Backend
- Hash all CSVs (SHA-256)
- Upload to IPFS
- Call `AttestationRegistry.submitAttestation()`

**T+2 (Nov 1, Afternoon): Independent Review**
- QP/Engineer verifies data
- Calls `AttestationRegistry.verifyCycle(202410)`
- Merkle tree built; cycle approved

**T+3 (Nov 1, Evening): Distribution Execution**
- Call `ValuationEngine.executeDistribution(202410, ...)`
  - Pull commodity prices from oracle
  - Calculate 10-step waterfall
  - Returns: $83.8M tokeholder share, $7.3M reserves

**T+4 (Nov 2): Settlement Queue**
- Call `SettlementRouter.queueDistribution(202410, 83.8M, [USDC, USDT, ...])`
- Distributions queued in stablecoins

**T+5 (Nov 2–30): Tokenholders Claim**
- Each holder calls `claimDistribution(202410, USDC)` (or USDT, USDE, EURC)
- Receives pro-rata share in preferred stablecoin
- ~15 second confirmation per claim

**T+6 (Nov 30, Close):** Month closed
- All distributions settled
- Reserves ($7.3M) transferred to RWA treasury
- Monthly audit trail immutable on-chain

### Monthly Operating Costs

| Cost | Amount | Payer |
|------|--------|-------|
| Ethereum gas (attestation) | $500 | Issuer |
| Ethereum gas (distribution) | $2,000 | Issuer |
| Settlement fees (0.1%) | $83,800 | Distributed from payout |
| Merkle tree construction | $0 | On-chain (free) |
| **Total Monthly:** | **~$86,300** | — |

Annualized cost: ~$1M / year for on-chain settlement (negligible vs $1B+ annual distributions)

---

## 🔒 Security & Audits

### Audit Phases

#### Phase 1: Internal Review (Completed)
- ✅ Code walkthrough by technical team
- ✅ Reentrancy guard checks
- ✅ Integer overflow/underflow coverage (native to Solidity 0.8.24)
- ✅ Access control role hierarchy

#### Phase 2: OpenZeppelin Formal Audit (8 weeks)
- [ ] Full Solidity code review
- [ ] ERC-20 compliance verification
- [ ] UUPS upgrade pattern audit
- [ ] Gas optimization analysis
- [ ] Remediation & retesting

#### Phase 3: RWA Specialist Auditor (4 weeks)
- [ ] Waterfall calculation accuracy
- [ ] Tax handling correctness
- [ ] Oracle integration security
- [ ] Settlement router atomic safety
- [ ] Remediation & final report

#### Phase 4: Live Monitoring (Ongoing)
- [ ] Real-time anomaly detection
- [ ] Daily balance reconciliation
- [ ] Monthly audit report publication

### Known Risks & Mitigations

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Oracle price manipulation | HIGH | Use Chainlink CCIP + time-weighted averages |
| Stablecoin depegging | MEDIUM | Multi-stablecoin diversification + manual intervention |
| Contract upgrade exploit | MEDIUM | Timelocked UUPS + multi-sig approval (3-of-5) |
| Reentrancy in settlement | LOW | Checks-effects-interactions + ReentrancyGuard |
| Attestation data falsification | HIGH | Independent reviewer + Merkle tree audit trail |

---

## ✅ Mainnet Checklist

### Pre-Deployment (2 weeks before)

- [ ] All audits completed & remediation done
- [ ] Testnet deployment verified on Sepolia/Mumbai
- [ ] .NET backend integration tested (end-to-end)
- [ ] Compliance registry seeded with allowlist
- [ ] Sanctions list feeds active (OFAC, PEP, adverse media)
- [ ] Settlement liquidity confirmed:
  - [ ] USDC: $100M+ available
  - [ ] USDT: $100M+ available
  - [ ] USDE: $50M+ available
  - [ ] EURC: $20M+ available
- [ ] Oracle feeds live:
  - [ ] Chainlink Cu/Au/Ag prices active
  - [ ] FX rate (USD/CLP) updating
  - [ ] Staleness checks configured (<24h)
- [ ] Legal review complete:
  - [ ] Securities opinion signed
  - [ ] PPM/OM finalized
  - [ ] Risk disclosures approved
- [ ] Governance vote passed:
  - [ ] >50% tokenholder approval for mainnet launch
- [ ] Monitoring infrastructure ready:
  - [ ] Real-time alerts configured
  - [ ] Distribution failure notifications active
  - [ ] Daily reconciliation scripts running

### Deployment Day (Mainnet Go-Live)

- [ ] Multi-sig (3-of-5) approval for deployment
- [ ] Deploy QHSecurityToken proxy
- [ ] Deploy ValuationEngine implementation
- [ ] Deploy SettlementRouter implementation
- [ ] Deploy AttestationRegistry implementation
- [ ] Link all contracts via setters
- [ ] Verify Etherscan contracts
- [ ] Seed attestation registry with test entry
- [ ] Execute test distribution (small amount)
- [ ] Process test claim (verify USDC transfer works)
- [ ] Publish mainnet launch announcement
- [ ] Monitor for first 48 hours:
  - [ ] No contract errors
  - [ ] No anomalous transactions
  - [ ] Oracle feeds healthy
  - [ ] Settlement system stable

### Post-Deployment (First Month)

- [ ] Monthly attestation submitted on schedule
- [ ] Independent review cycle completed
- [ ] First distribution executed (Oct 2025 cycle)
- [ ] All tokenholders claims processed successfully
- [ ] Monthly audit report published
- [ ] Governance vote on reserve percentage (confirm 8%)
- [ ] Sensitivity analysis published (low/base/high scenarios)
- [ ] Performance metrics tracked:
  - [ ] Claim processing time: <30 seconds
  - [ ] Gas costs: within budget
  - [ ] Stablecoin settlement rates: <0.5% failures
  - [ ] Claim accuracy: 100% match to expected amounts

---

## 🎯 Success Criteria

By end of Phase 1 (Q4 2025):

✅ Mainnet deployment complete  
✅ First monthly distribution executed ($80M+)  
✅ All tokenholders successfully claimed  
✅ Zero settlement failures  
✅ <1% total transaction costs vs. distributions  
✅ Audit reports published  
✅ Governance framework operational  
✅ CBDC adapter designed (not yet integrated)  

---

## 📞 Support & Escalation

**Technical Issues:**
- Slack: #qh-smart-contracts
- Email: contracts@trustiva.io

**Urgent (Gas price spike, oracle failure):**
- PagerDuty: #on-call-blockchain
- Emergency line: [Contact]

---

**END OF DEPLOYMENT GUIDE**

---

*Last Updated: October 31, 2025*  
*Next Review: January 31, 2026*

