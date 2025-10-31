# Midnight Suite (NIGHT/DUST)

Tools to:
- Check **Glacier snapshot** eligibility across chains (self-custody + ≥$100 @ 2025-06-11).
- Generate a **fresh Cardano receive address** placeholder (replace with HSM/hardware in prod).
- Build a **randomized unlock calendar** (4 events over ~360 days by default).
- Model **NIGHT → DUST** sizing for app workloads.

Run from VS Code tasks or CLI:
- Eligibility: `pnpm --dir apps/midnight-suite night:eligibility -- --wallets file:apps/midnight-suite/data/wallets.csv --snapshot 2025-06-11 --threshold 100`
- Fresh address: `pnpm --dir apps/midnight-suite night:fresh-addr`
- Unlocks: `pnpm --dir apps/midnight-suite night:unlocks -- --start 2025-10-15 --events 4 --days 360`
- DUST model: `pnpm --dir apps/midnight-suite night:dust -- --tps 0.5 --duration-days 90 --safety 1.5`

Note: These scripts are offline planners—no network calls. Replace the fresh address stub with your secure wallet flow when ready.

## Scavenger Mine Planner
Run a quick “work-for-allocation” model:
```bash
pnpm --dir apps/midnight-suite night:scavenger -- --days 14 --hashrate 50 --unit-hashrate 1 --diff 1.0 --cap 1000000 --rng 0.25
```

Outputs `out/scavenger-plan.json` with expected and banded NIGHT.
Not real PoW; parameters are placeholders. Update `--cap`, `--diff`, and `--rng` as official details emerge.
