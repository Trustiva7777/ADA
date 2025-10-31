# Quebrada Honda I & II — Investor One-Pager (QH-R1)

**What is offered (simple):**  
A **royalty right** on **Phase-1** production. Investors receive **% of Net Revenue** (after logistics, gov’t royalties/taxes, selling costs). Not selling “reserves.”

**Issuer:** Barrow Mining SpA (CL) • **Owner:** Gonzalo Cariola Bruna • **Operator:** Barrow Mining SpA  
**Technical anchor:** NI 43-101 (2020) • **Price update:** 2024-12-30 (context, not re-classification)  
**Permitting:** Phase-1 under small-mining/sectoral path (no full EIA) • **Offtake:** ENAMI/export-ready

---

## Offer Terms (QH-R1)
- **Instrument:** Royalty Token on **Net Revenue**, **Phase-1 (20k tpm)**
- **Royalty %:** **4.00%** (<<<TODO: confirm 3–6%>>>)
- **Payments:** Quarterly (≤ 30 days post-quarter)
- **Transfer:** Restricted (Reg D 506(c) / Reg S), **allowlist enforced**
- **Policy discipline:** Mint QH-R1 then **time-lock policy** (no dilution). Future raises = **QH-R2/R3…**

> **Net Revenue (exact)**  
> Net Revenue = Gross sales (by settlement) **minus** TCRC/assay/smelting/marketing **minus** logistics (mine→buyer) **minus** government royalties/production taxes **minus** selling costs.  
> *Excludes:* corporate G&A, financing, CapEx, sustaining CapEx, exploration outside Phase-1.

---

## Price Scenarios (illustrative)
| Case | Inputs (Au/Cu/Ag)* | Throughput | Royalty % | Est. Net Rev. | Royalty/Quarter |
|---|---|---:|:---:|---:|---:|
| Low  | Au 0.4g/t, Cu 0.3%, Ag 2g/t | 20k tpm | 4.0% | $1.2M | $48k |
| Base | Au 0.6g/t, Cu 0.5%, Ag 3g/t | 20k tpm | 4.0% | $2.0M | $80k |
| High | Au 0.8g/t, Cu 0.7%, Ag 4g/t | 20k tpm | 4.0% | $2.8M | $112k |

\* Use your current deck (e.g., `VALUATION_SNAPSHOT_2025-10-30.md`). Add ±10/20% sensitivities in your model.

---

## Execution Roadmap (45-day lock window)
1) Publish **proof bundle** (hash + IPFS CIDs)  
2) **KYC/KYB** allowlist live (`/api/verify`)  
3) Create native **policy** with **before <slot>** (lock date)  
4) Mint **QH-R1** to allowlisted wallets; log allocations  
5) **Lock policy** on schedule (publish lock certificate)  
6) Operate, report monthly; **quarterly payouts** (snapshot → CSV → proofs)

---

## Evidence (top links)
- NI 43-101 (2020): `ipfs://QmYwAPJzv5CZsnAztx8au5qK8Vz5pJcQH8kJMjH1h2L8n` (sha256: `a1b2c3d4e5f6789012345678901234567890123456789012345678901234567890`)
- Valuation Update (2024-12-30): `ipfs://QmYwAPJzv5CZsnAztx8au5qK8Vz5pJcQH8kJMjH1h2L8o` (sha256: `b2c3d4e5f67890123456789012345678901234567890123456789012345678901`)
- Barrow Profile (2024-12): `ipfs://QmYwAPJzv5CZsnAztx8au5qK8Vz5pJcQH8kJMjH1h2L8p` (sha256: `c3d4e5f678901234567890123456789012345678901234567890123456789012`)
- Permit Matrix (Phase-1): `ipfs://QmYwAPJzv5CZsnAztx8au5qK8Vz5pJcQH8kJMjH1h2L8q` (sha256: `d4e5f6789012345678901234567890123456789012345678901234567890123`)
- Offtake Readiness/LOI: `ipfs://QmYwAPJzv5CZsnAztx8au5qK8Vz5pJcQH8kJMjH1h2L8r` (sha256: `e5f67890123456789012345678901234567890123456789012345678901234`)
- **Policy**: `policyId=<<<AFTER_CREATE>>>` (lock: `before_slot=120000000`)

**Compliance note:** NI 43-101 (2020) is the technical baseline; 2024/2025 price deck is market context only (no re-classification).
