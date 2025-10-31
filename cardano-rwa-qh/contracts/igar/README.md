# IGAR – In-Ground Asset Royalty (Plutus V2)

Compliance-forward royalty vault for RWA royalty tokens (e.g., QH-R1):

- Time-locked series mint policy (no dilution after lock)
- Allowlist NFT gating for transfers/mint
- Reference inputs for Compliance (revocation list, policy-lock truth) and Oracle (record-date/FX)
- Governance multisig for pause/unpause and admin actions

## Build & Test (requires Plutus toolchain)

```bash
cabal update
cabal build
cabal test igar-tests
```

Notes:
- This Codespace doesn’t include the Plutus toolchain by default; treat this as scaffolding to build on locally.
- Keep private until your provisional is filed.

## Patent & Licensing

Copyright © 2025 Unykorn Global Finance. All rights reserved.
Source-available for review. Commercial use requires written license. Patent claims pending (provisional).
