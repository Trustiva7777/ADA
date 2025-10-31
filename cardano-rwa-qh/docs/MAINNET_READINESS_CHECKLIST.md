# Mainnet Readiness Checklist (QH-R1)

This checklist helps ensure your Cardano-native RWA issuance (QH-R1) is safe, compliant, and repeatable on Mainnet.

## 1. Environment and Secrets
- [ ] Choose network: Preprod smoke test → Mainnet
- [ ] Copy and fill .env from examples:
  - [ ] .env.preprod.example → .env (Preprod)
  - [ ] .env.mainnet.example → .env (Mainnet)
- [ ] Provider configuration (choose ONE mode):
  - [ ] Sovereign: OGMIOS_URL, KUPO_URL, SUBMIT_API_URL reachable and healthy
  - [ ] Blockfrost fallback: BLOCKFROST_API_KEY set
- [ ] Compliance API configured and reachable: COMPLIANCE_URL, COMPLIANCE_TOKEN
- [ ] CI secrets set: BF_KEY, COMPLIANCE_URL, COMPLIANCE_TOKEN (as used in workflow)

## 2. Proof Bundle and Governance
- [ ] Complete proof bundle files and hashes (sha256) with CIDs where applicable
- [ ] Build SHA-256 manifest: “Proofs: build sha256 manifest” task (outputs docs/sha256-manifest.json)
- [ ] Validate bundle against schema: “Proof: validate bundle” task
- [ ] Generate issuance attestation JSON: “Attestation: generate issuance attestation” task (outputs docs/attestation.json)
- [ ] Attach proof manifest hash to issuance docs; publish link in data room
 - [ ] Hash allowlist snapshot (CSV/JSON): “Allowlist: hash snapshot (.NET)” → outputs docs/allowlist.sha256.json (includes raw and canonical hashes)
   - Tip: You can pass the allowlist file directly to “Attestation: policy/lock/proofs (.NET)” and it will compute the canonical hash automatically.
- [ ] Policy lock certificate drafted with before-slot and time window rationale
- [ ] Governance: multisig/approvals recorded; investor pack updated

## 3. Policy Planning
- [ ] Compute lock slot: “Policy: plan lock slot (+45d)” task
- [ ] Create native policy JSON (sig + before-slot) and verify policyId
- [ ] Publish policyId and policy JSON to repo/data room
- [ ] Dry-run lock time and feasibility; double-check time in UTC

## 4. Compliance Preflight
- [ ] Run “Compliance: preflight” without --skip-api (live endpoint)
- [ ] Ensure allowlist responds with expected wallets and statuses
- [ ] Freeze allowlist snapshot with sha256 and store in data room

## 5. Mint and Distribution
- [ ] Dry-run mint to one allowlisted wallet (test amount) on Preprod
- [ ] Verify on-chain metadata and policyId
- [ ] Generate distribution plan; review totals and dust handling
- [ ] Execute final mint; record TX hash; export mint report JSON
- [ ] Distribute allocations; export distribution report JSON

## 6. Lock and Post-Issuance
- [ ] Submit policy lock transaction at/near before-slot
- [ ] Publish lock TX hash and lock certificate PDF
- [ ] Update investor docs and data room with final artifacts
- [ ] Archive any sensitive secrets outside repo; rotate API keys

## 7. IGAR Contract (optional for QH-R1)
- [ ] Implement allowlist NFT checks and reference input parsing
- [ ] Compile and unit test the validators
- [ ] Record script hashes and reference script UTxOs

## 8. Midnight Suite (optional planning)
- [ ] Run NIGHT/DUST planners and unlock schedule; publish outputs in ops folder
- [ ] Review Scavenger planner output vs. buy scenario; document decision

## 9. Final Sign-off
- [ ] All CI checks green (build, lint, compliance)
- [ ] Internal sign-offs logged; board/committee approvals attached
- [ ] Runbook updated with exact TX ids and timing

Notes:
- Keep all hashes and CIDs in the data room index for durability.
- Minimize re-mints; lock policy on schedule.
- Favor sovereign stack for independence; keep Blockfrost as safe fallback.
