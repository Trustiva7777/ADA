# Mainnet Readiness — QH-R1

This file mirrors the primary checklist and names where to find the outputs. See also `./MAINNET_READINESS_CHECKLIST.md` for the detailed list.

Key steps and where to run them:

1) Env presets
- Open: `.env.preprod.example` or `.env.mainnet.example` and copy to `.env`

2) Proofs
- Task: "Proofs: build sha256 manifest (.NET)" → writes `docs/sha256-manifest.json`
- Task: "Attestation: generate issuance attestation (.NET)" → writes `docs/attestation.json`
 - Task: "Allowlist: hash snapshot (.NET)" → writes `docs/allowlist.sha256.json` (raw and canonical)
	- Tip: Instead of hashing separately, pass the allowlist file to "Attestation: policy/lock/proofs (.NET)" and it will compute the canonical hash automatically.

3) Policy and lock
- Task: "Policy: plan lock slot (+45d)" (already wired)
- Task: "Hash: policy.json (.NET)" → writes `docs/policy.sha256.json`
- Task: "Attestation: policy/lock/proofs (.NET)" → writes `docs/token/attestation.<Network>.json`

4) Compliance
- Task: "Compliance: preflight" (configure env/CI secrets beforehand)

5) Mint / Distribute
- Run mint dry-run per the README, then finalize and lock

Artifacts to publish in the data room:
- `docs/sha256-manifest.json`
- `docs/attestation.json` (issuance-wide)
- `docs/token/attestation.<Network>.json` (policy+lock+proofs)
 - `docs/allowlist.sha256.json` (raw+canonical allowlist hash)
- Policy JSON and policyId
- Lock TX hash and lock certificate
