# QH-R1 — Full Cardano Game Plan (Phased)

This plan maps directly to the VS Code tasks and CLI in this workspace.

---

## Phase 0 — Choose mode & wire environments (Day 0)

Pick provider or sovereign mode by setting `.env`.

Provider mode
- `BLOCKFROST_API_KEY=...`
- Leave `OGMIOS_URL`, `KUPO_URL`, `SUBMIT_API_URL` empty

Sovereign mode
- `OGMIOS_URL=wss://ogmios.yourdomain:1337`
- `KUPO_URL=https://kupo.yourdomain:1442`
- `SUBMIT_API_URL=https://submit.yourdomain:8090`
- Leave `BLOCKFROST_API_KEY` empty

Success: `pnpm dev` prints address and UTxOs without errors.

---

## Phase 1 — Evidence & compliance (Days 1–3)

1) Proof bundle — edit `docs/PROOF/qh_r1_proof.bundle.json` and fill SHA-256 + ipfs:// CIDs
- Task: Docs: validate proof bundle → `pnpm validate:proof`

2) Compliance API — set `COMPLIANCE_URL` (mock for dev; prod for live)
- Task: Dev: mock compliance → serves `/api/verify`
- `src/lib/compliance.ts` enforces allowlist (Reg D / Reg S)

Success:
- Proof validator passes
- `/api/verify` allows approved wallet and rejects non-eligible

---

## Phase 2 — Policy discipline & series definition (Days 2–4)

1) Plan lock deadline
- Task: Royalty: plan lock slot (+45d) → `pnpm slot:deadline`

2) Create policy (with optional before <slot>)
- `pnpm policy -- --slot-deadline <slot>`
- Publish policy JSON + PolicyId to the data room

3) Series conventions
- QH-R1 = Phase-1 royalty; future raises use new series (QH-R2, R3…)

Success:
- PolicyId generated & published
- Lock plan approved (no post-lock mints)

---

## Phase 3 — Mint & allocate (Days 4–10)

1) Dry-run mint (tiny)
```
pnpm mint -- --ticker QH-R1 --amount 10 --decimals 2 \
  --name "QuebradaHonda-Royalty-Phase1" --doc "ipfs://<CID>" \
  --to <test_addr>
```
- Sovereign: ensure Submit-API is healthy (task: Submit: health)

2) Allocation mints (per allowlist)
- Keep CSV ledger of allocations (`/reports/allocations-YYYYQX.csv`): wallet, units, tx hash

3) Close and lock
- Time-lock policy at deadline; publish lock evidence

Success:
- All allocations minted without compliance errors
- Policy locked; total supply matches the raise

---

## Phase 4 — Raise & parallel financing (Days 7–30)

1) Investor pack
- `/legal/term_sheet_royalty_QH-R1.md` (default 4.0% → adjust)
- `/legal/subscription_agreement_outline.md`
- `/legal/risk_factors_QH.md`
- Pitch deck + one-pager

2) Investor portal (MVP routes)
- `/offering/QH-R1`, `/subscribe`, `/holdings`, `/reports`

3) Optional: Prepaid Offtake / Stream (off-chain)
- Reflect counterparties in proof bundle

Success:
- Subscriptions closed; funds received
- If used, offtake prepay executed

---

## Phase 5 — Operations & reporting (steady state)

Monthly ops
- Production, grades, shipments, receivables → `/reports/monthly-YYYY-MM.md`

Quarterly distributions (token side)
1) Compute Gross → Net Revenue (per term sheet)
2) Royalty = % × Net Revenue
3) Snapshot holders:
```
pnpm snapshot -- --policy <POLICY_ID> --asset 51482d5231
```
4) Build payout CSV: `wallet_address,tokens_held,pro_rata_share,payout_amount_usd`
5) Plan only (USDC off-chain):
```
pnpm distribute -- --csv ./docs/qh_r1_payouts_template.csv --mode plan
```
6) ADA demo (testnet):
```
pnpm distribute -- --mode send-ada --fx <usd_to_ada_rate>
```
7) Publish payout proofs (bank/USDC receipts or txids + CSV) → `/reports/quarterly-YYYYQX/`

Success:
- Quarterly payout plan + proofs published ≤ +30 days post-quarter

---

## Security, custody, ops
- Separate keys: mint (policy) vs. treasury (payouts)
- Node roles: BP behind relays; Ogmios/Kupo/Submit-API over TLS and allowlists/mTLS
- Monitoring: height/mempool, Kupo lag, disk, submit health

Rollback
- To provider mode: unset `OGMIOS_URL/KUPO_URL/SUBMIT_API_URL`, set `BLOCKFROST_API_KEY`

---

## KPIs & gates
- T-0: proof valid & pinned; KYC/allowlist live; policy lock plan; smoke mint OK
- Post-raise: offtake countersigned or ENAMI intake live; permits in hand; 1st ops report on schedule
- Quarterly: snapshot → payout plan → proofs

---

## Data room pack
- Technical: NI43-101 (2020 PDF), 2024 price update, maps, plant plan
- Legal: term sheet, subscription, risk factors, policy JSON, transfer restrictions
- Ops: tranche plan, build schedule, offtake LOI/contract
- Token: policyId, proof-bundle CID, allocation ledger (anonymized), payout proofs

---

## VS Code one-key controls
- Docs: validate proof → `pnpm validate:proof`
- Royalty: plan lock slot → `pnpm slot:deadline`
- Mint → `pnpm mint …`
- Snapshot → `pnpm snapshot …`
- Payouts → `pnpm distribute …`
- Sovereign infra → Compose up/down, logs, submit health tasks
