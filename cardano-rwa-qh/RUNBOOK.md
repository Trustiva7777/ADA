# Sovereign Cutover Runbook

This runbook makes it copy-paste simple to bring up the sovereign stack, smoke-test, mint, and cut over. It also covers hardening and rollback.

## ✅ Success criteria
- `docker compose up -d` brings up: node (3001), ogmios (1337), kupo (1442), submit-api (8090) and healthchecks pass.
- `pnpm dev` shows issuer address + UTxOs via Ogmios/Kupo (no Blockfrost).
- `pnpm submit:health` returns 200 OK with JSON.
- `pnpm mint …` posts CBOR to Submit-API and returns a tx hash.
- You can tail logs in VS Code via the Compose/Logs tasks.

## 1) Environment matrix (.env)
### Preview / Preprod (testnets)
```
NETWORK=Preview       # or Preprod
OGMIOS_URL=wss://ogmios.yourdomain:1337
KUPO_URL=https://kupo.yourdomain:1442
SUBMIT_API_URL=https://submit.yourdomain:8090

# Fallback provider only if needed
# BLOCKFROST_API_KEY=...

# Dev wallet ONLY (testnets)
ISSUER_SEED="word1 ... word24"
#ISSUER_SK=

# Compliance (dev mock or prod)
COMPLIANCE_URL=http://127.0.0.1:8787/api/verify
COMPLIANCE_TOKEN=
```

### Mainnet
```
NETWORK=Mainnet
OGMIOS_URL=wss://ogmios.yourdomain:1337
KUPO_URL=https://kupo.yourdomain:1442
SUBMIT_API_URL=https://submit.yourdomain:8090

# No seeds in .env on mainnet → HSM/offline signing only
# BLOCKFROST_API_KEY=
COMPLIANCE_URL=https://compliance.internal/verify
COMPLIANCE_TOKEN=YOUR_JWT_OR_KEY
```

## 2) Bring up the stack (VS Code tasks or CLI)
### VS Code tasks
- Compose: up
- Submit: health
- Logs: node / ogmios / kupo / submit-api

### Shell
```bash
docker compose up -d
pnpm submit:health
docker logs -f ogmios
docker logs -f kupo
docker logs -f cardano-submit-api
```

Health endpoints: Ogmios `/health`, Kupo `/`, Submit `/health`.

## 3) Smoke test sequence
1. Provider check:
   ```bash
   pnpm dev
   ```
2. Policy lock planning:
   ```bash
   pnpm slot:deadline
   pnpm policy -- --slot-deadline <slot>
   ```
3. Proof bundle sanity:
   ```bash
   pnpm validate:proof
   ```
4. Compliance (dev): run task "Dev: mock compliance" or point to prod endpoint.
5. Mint a tiny test:
   ```bash
   pnpm mint -- --ticker QH-R1 --amount 10 --decimals 2 \
     --name "QuebradaHonda-Royalty-Phase1" \
     --doc "ipfs://<CID>" \
     --to <your_testnet_addr>
   ```
6. (Optional) ADA payout demo:
   ```bash
   pnpm distribute -- --csv ./docs/qh_r1_payouts_template.csv --mode plan
   pnpm distribute -- --csv ./docs/qh_r1_payouts_template.csv --mode send-ada --fx 0.35
   ```

## 3a) Native MintTool (.NET, offline-friendly)

For air-gapped or HSM minting, use the .NET MintTool and VS Code tasks for a fully offline, signer-ready mint bundle. This path avoids Node/TS dependencies and is recommended for mainnet.

### Steps
1. **Create policy script (sig + optional beforeSlot)**
   - VS Code task: `Cardano: Policy — script (sig + optional before)`
   - Paste your policy key hash (from signer box)
   - Optionally provide a before slot (leave blank to omit)
   - Output: `rwa-suite/chains/cardano/policy/policy.script.json`
   - Compute policyId (offline, no cardano-cli needed):
     ```bash
     dotnet run --project rwa-suite/chains/cardano/tools/MintTool/MintTool.csproj -- policy-id --from rwa-suite/chains/cardano/policy/policy.script.json
     ```
     - Output: `PolicyId: <hex>`
2. **Plan mint bundle (unsigned, offline)**
   - VS Code task: `Cardano: Mint — plan (unsigned, .NET)`
   - Fill in:
     - PolicyId (from previous step)
     - Asset name (e.g., QH-R1)
     - Amount (base units)
     - Decimals (display only)
     - ipfs://CID for docs/proofs
     - Change address (signer wallet)
   - Output:
     - `chains/cardano/out/mint/mint_unsigned.plan.json`
     - `chains/cardano/out/mint/inputs.template.json`
     - `chains/cardano/out/mint/README_SIGNER.txt`
3. **On the signer box (air-gapped)**
   - Fill `inputs.template.json` with UTxOs to spend
   - Follow `README_SIGNER.txt` for exact cardano-cli commands:
     - Build raw tx with mint, metadata label 674, and policy script
     - Calculate fee, adjust outputs, sign with policy.skey
     - Submit via relay or export signed CBOR for submission

**Notes:**
- All outputs are deterministic and auditable; no secrets or keys are ever written by MintTool.
- The README includes all metadata and label 674 fields for compliance.
- This flow is mainnet-ready and avoids any key leakage or online signing.

---

## 4) NGINX reverse-proxy stanzas
See DEPLOY.md for TLS and allowlists (Ogmios WS, Kupo HTTP, Submit-API HTTP).

## 5) Cutover & rollback
- Cutover:
  1. Keep Blockfrost while bringing up infra.
  2. Set `OGMIOS_URL`, `KUPO_URL`, `SUBMIT_API_URL`.
  3. Run smoke tests; remove `BLOCKFROST_API_KEY` to enforce sovereign mode.
  4. Mint & verify end-to-end.
- Rollback: unset `OGMIOS_URL/KUPO_URL/SUBMIT_API_URL` and set `BLOCKFROST_API_KEY` to return to provider mode.

## 6) Hardening checklist
- Keys: mint key on HSM/air-gapped; separate treasury key; document key ceremonies; rotate KES ≈90d.
- Networking: BP behind relays; firewall; mTLS/IP allowlists for Submit-API; private VPC for Ogmios/Kupo.
- Monitoring: Prometheus/Grafana; alerts for slot height, mempool failures, Kupo lag, disk.
- Audit: store SHA-256 + CID for docs; publish policy JSON + policyId; record payout CSV + payment proofs.

## 7) Troubleshooting
- Missing env: set Ogmios/Kupo or Blockfrost.
- Submit 404: check endpoint path; adjust `/api/submit/tx` vs `/api/submit/cbor` in `src/lib/submit.ts`.
- Health red: mount node socket volume; verify `--node-socket /ipc/node.socket`.
- Tx unseen: update relay peers; check topology.
- Metadata missing: confirm unit construction and CIP-25 structure.
