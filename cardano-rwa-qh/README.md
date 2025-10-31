# Cardano RWA — QH-R1 (Quebrada Honda I & II)

This workspace mints and manages the QH-R1 Royalty Token on Cardano:
- Mint / lock a native policy (key-locked + optional time-lock).
- Attach evidence via an IPFS proof bundle (NI 43-101, valuation, corp profile).
- Gate mints & distributions via a KYC allowlist.
- Quarterly payouts: compute per-address royalty amounts from CSV inputs.

## Quick start (offline-first, zero downloads)

1. **Env**

  * Copy `.env.preprod.example` → `.env` (or `.env.mainnet.example` when ready).
  * Set `BLOCKFROST_API_KEY` **or** your own infra endpoints (Ogmios/Kupo/Submit-API) below.

2. **Freeze evidence & inputs**

  * **Proof manifest** → VS Code Task: **“Proofs: build sha256 manifest (.NET)”**
    *Output:* `docs/sha256-manifest.json`
  * **Plan lock** → **“Policy: plan lock slot (.NET)”** (or **with current slot** to compute `beforeSlot`)
    *Output:* `reports/lock_plan.json` (+ `reports/lock_plan.beforeSlot` if current slot was provided)
  * **Allowlist**: Use your CSV/JSON (no pre-hash needed).

3. **Attest issuance (single step)**

  * Task: **“Attestation: policy/lock/proofs (.NET)”**
    Provide: `policyId`, `network` (Preprod/Mainnet), `policy JSON`, optional `beforeSlot`, and your **allowlist file**.
    *Output:* `docs/token/attestation.<Network>.json` (binds policyId, manifest hash, canonical allowlist hash, timing).

4. **Policy create/lock (Preprod first)**

  * If you’re using your Node scripts, run those here; otherwise follow your policy JSON + lock flow from the checklist.

5. **Mint (Preprod)**

  * Dry-run your mint. Confirm policy, attestation, and proof bundle CID line up.

6. **Flip to Mainnet**

  * Update `.env` to Mainnet; repeat **Lock/Attest** with final policyId; then mint.

> Want fewer clicks? Use the chain task **“Policy: plan lock ➜ attestation (auto) (.NET)”**. It computes `beforeSlot`, then immediately runs the attestation with the right value injected.

## Game plan and investor pack
- Full phased plan: see `./docs/PLAN_QH_R1.md`
- Evidence bundle template: `./docs/PROOF/qh_r1_proof.bundle.json`
- Term sheet: `./legal/term_sheet_royalty_QH-R1.md`
- Risk factors: `./legal/risk_factors_QH.md`
- Subscription outline: `./legal/subscription_agreement_outline.md`

## Use your own Cardano infra

Bring up Ogmios, Kupo, and Submit-API (sample compose included).

```
OGMIOS_URL=wss://ogmios.yourdomain:1337
KUPO_URL=https://kupo.yourdomain:1442
SUBMIT_API_URL=https://submit.yourdomain:8090   # optional; for POSTing signed CBOR
```

The toolkit prefers Ogmios+Kupo when present; otherwise it falls back to Blockfrost.

## Proofs & attestations (two paths)

* **.NET (recommended here)**

  * **Proofs:** “Proofs: build sha256 manifest (.NET)” → `docs/sha256-manifest.json`
  * **Attest:** “Attestation: policy/lock/proofs (.NET)”
    Accepts **allowlist file directly**; computes canonical SHA-256.

* **Node/TS (optional, on machines with Node)**

  * “Proofs: build sha256 manifest”
  * “Attestation: generate issuance attestation”

See `docs/MAINNET_READINESS_CHECKLIST.md` for an end-to-end preflight.

## Payouts & distributions

1. **Plan**

   * Fill `./docs/qh_r1_payouts_template.csv` (`wallet_address,tokens_held,pro_rata_share,payout_amount_usd`).
   * Task: **“Payouts: plan (.NET)”** → `reports/payout_plan.json` (prints totals)

2. **ADA ledger**

   * Task: **“Payouts: ADA ledger (.NET)”** → prompts USD→ADA `fx`
     *Output:* `reports/ada_ledger.csv` (`wallet_address,ada,lovelace`)

3. **Unsigned tx batches (no chain libs)**

   * Task: **“Distribute: draft ADA tx batches (.NET)”**
     *Output:* `out/tx_batches/tx_batch_*.json` (unsigned plans), `*.inputs.template.json`, `submit_batch_*.curl.sh`, `SUMMARY.json`
   * Move a batch plan to your signer box, build/sign into CBOR, drop back as `tx_batch_001.signed.cbor`, then:

     ```
     bash out/tx_batches/submit_batch_001.curl.sh
     ```

     Set `SUBMIT_API` to your relay if needed.

> USDC distributions are typically off-chain; leave CLI in **plan** mode and use the exported ledger with your payment processor.

### Optional (Node-based distributor)

If you prefer the Node/TS path and have Node inside your environment, you can use the distributor script directly. From the repo root use the VS Code task:

- "Distribute (Node): plan" — runs `pnpm --dir cardano-rwa-qh distribute -- --csv ./docs/qh_r1_payouts_template.csv --mode plan`

This fixes the common error when running `pnpm distribute` at the root (no package.json at the root). The script lives under `cardano-rwa-qh`.

---

## Example (Node script path, optional)

```bash
pnpm install
pnpm dev

# Policy (example deadline)
pnpm policy -- --slot-deadline 99999999

# Prepare + pin proof JSON → get ipfs://CID
pnpm mint -- --ticker "QH-R1" --amount 1000000 --decimals 2 \
  --name "QuebradaHonda-Royalty-Phase1" --doc "ipfs://<CID>"
```

---

## Safety rails (do these every time)

* Recompute a couple of file hashes manually and compare to `docs/sha256-manifest.json`:

  ```
  sha256sum docs/<file>
  ```
* Confirm `attestation.<Network>.json` references:

  * the exact **policyId** you’ll lock,
  * the correct **manifest sha256**, and
  * the canonical **allowlist sha256**.
* Tag the repo at mint: commit `attestation.Mainnet.json` and tag that commit.

---

### What changed vs your original text (so you see the deltas)

* Promoted the **.NET tasks** to first-class (no Node required in this container).
* Documented **allowlist-file ingestion** (no manual SHA copying).
* Added **lock→attest chain task** and the new **ADA batch drafts** flow.
* Tightened the order of operations to mirror your CI-ish workflow.

If you want the next sugar layer, I can add a tiny **fee-fitter** for the ADA drafts and a **Signer Helper** template (reads a batch plan, constructs CBOR via `cardano-cli`, signs with a hardware or file key, and emits the digest)—still keeping your “zero random downloads” vibe.

## Wallet generation (local, encrypted)

Use the VS Code task "Wallet: generate (SeedGen, .NET)" to create a 24-word seed, derive Mainnet/Preprod/Preview base addresses, and write:

- `Cardano/Dev/Wallet/mainnet/addr_mainnet.txt`
- `Cardano/Dev/Wallet/preprod/addr_preprod.txt`
- `Cardano/Dev/Wallet/preview/addr_preview.txt`
- `Cardano/Dev/Wallet/pay.xpub`, `stake.xpub`
- `Cardano/Dev/Wallet/*/seed.enc` — AES-256-GCM, PBKDF2-SHA512 200k rounds

Notes:
- The plaintext mnemonic is never written to disk; only `seed.enc` is stored.
- `.gitignore` is updated to exclude `Cardano/Dev/Wallet/` and local draft/ledger outputs. Do not commit secrets.

## Signer Helper (offline sign box)

Use these helper scripts on your signer host (with `cardano-cli` and `jq`):

- Bash: `scripts/signer/build_sign_submit.sh`
- PowerShell: `scripts/signer/build_sign_submit.ps1`

They take a batch plan (`tx_batch_001.json`) and inputs template, build the transaction with auto fee (`--conway-era`), sign with your payment key, write `tx_batch_001.signed.cbor`, and optionally POST to a Submit API.

Quick path:
1) Export a bundle from the dev container:
  - Task: "Signer: export bundle for batch 001"
  - This packages the plan, inputs template, attestation pointer, and a README, plus copies the scripts if present.
2) On signer host:
  - Edit `CHANGE_ADDR.txt` and `NETWORK_FLAG.txt`
  - Run `build_sign_submit.sh` (or `.ps1`) with your key and flags.
3) Submit from signer (`--submit-api`) or copy `*.signed.cbor` back and run the generated `submit_batch_001.curl.sh`.

Notes:
- `--network-flag` is explicit: use `--testnet-magic 1` for preprod (adjust magic to environment) or `--mainnet` for mainnet.
- Metadata label 674 (CIP-20 style) is built from your plan’s `auxiliary.label_674`.