# Quebrada Honda I & II — Investor-Ready Scenario (QH-R1)

## Core Premise
You are offering economic rights (a royalty stream) tied to Phase 1 production at Quebrada Honda I & II. You are not selling reserves.

Evidence anchors
- Ownership: Gonzalo Cariola → Barrow Mining SpA (issuer)
- NI 43-101 Technical Report (2020) — technical baseline
- Updated price-based valuation (2024-12-30) — market context only
- Permitting: Phase 1 pathway without full EIA; verify sectoral/small-mining scope
- Offtake readiness: ENAMI or export channels

## Two Tracks

### Track 1 — Token Issuance (Investor-Facing)
Routes to build in `/apps/investor-portal`:

```
/login           # KYC/accreditation
/offering/QH-R1  # proof-bundle, term sheet, risk factors
/subscribe       # allocation request (wallet + compliance)
/holdings        # units, policyId, explorer links
/reports         # monthly ops, quarterly payouts
```

Token mechanics
- Ticker/Series: QH-R1
- Right: 4.00% royalty on Net Revenue from Phase 1 (<<<TODO: adjust 3–6%>>>)
- Offering: Reg D 506(c) (US accredited) + Reg S (non-US)
- Transfer: allowlist-gated via Compliance API
- Policy discipline: time-locked policy; new raises use new policyId (QH-R2, R3…)

### Track 2 — Operational Execution (Issuer-Facing)
- Fill and pin proof bundle (CIDs + SHA-256)
- Wire Compliance API (mock → prod)
- Create policy + before <slot> lock schedule
- Mint allocations to whitelisted wallets, publish policy JSON + deal room
- Parallel financing lane (optional): Prepaid Offtake or Stream
- Monthly ops → Quarterly payout plan (CSV) → Proof of distributions (txids/receipts)

## Definitions
Gross Revenue = (Payable metal × price) – TCRC/assay/smelting/marketing (per offtake).

Net Revenue (a.k.a. Netback) = Gross Revenue – Logistics (mine→buyer) – Government royalties/production taxes – Selling costs.
(Explicit excludes: corporate overhead, interest/financing, CapEx and sustaining CapEx, exploration outside Phase 1.)

Royalty Due (quarter) = Royalty % × Net Revenue (quarter).

## Compliance guardrails
- NI 43-101 (2020) = technical anchor; 2024 valuation = price snapshot; do not imply new resource categories.
- Reg D/Reg S disclosures with risk factors; transfer restrictions enforced by allowlist.
- Publish policyId, proof-bundle CID, and payout proofs.
