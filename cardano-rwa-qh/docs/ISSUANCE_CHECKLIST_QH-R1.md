# Issuance & Audit Checklist — QH-R1

## A. Evidence (PASS/FAIL)
- [ ] SHA-256 computed for all docs (see sha256_manifest.csv)
- [ ] All docs pinned to IPFS; CIDs recorded
- [ ] Proof_Bundle_QH-R1.json validated (schema + links)

## B. Compliance
- [ ] COMPLIANCE_URL points to prod /api/verify
- [ ] Allowlist blocks non-eligible wallets (Reg D / Reg S)
- [ ] Transfer restrictions summarized in data room

## C. Policy Discipline
- [ ] Lock slot computed (slot: ______, ~date: ______)
- [ ] Policy created; PolicyId: ______________________
- [ ] Policy JSON published to /token/
- [ ] Internal sign-off on no-mint after lock

## D. Mint & Allocation
- [ ] Dry-run mint succeeded (tx: ____________________)
- [ ] Allocations minted only to allow-listed wallets
- [ ] Allocation ledger saved: /reports/allocations-YYYYQX.csv
- [ ] Policy locked at deadline; lock proof published

## E. Parallel Financing (optional)
- [ ] Offtake/Stream LOI executed (ENAMI/Buyer)
- [ ] Terms reflected in proof bundle (attachments)

## F. Operations & Reporting
- [ ] Monthly report template ready (/ops/Monthly_Reports)
- [ ] Quarterly payout flow rehearsed (snapshot → CSV → plan)
- [ ] Investor statement template prepared

## G. Security & Infra
- [ ] Mint key in HSM/offline; treasury key separate
- [ ] Sovereign endpoints (Ogmios/Kupo/Submit-API) healthy
- [ ] Rollback to provider documented
