#!/usr/bin/env node
/**
 * Scavenger Mine Planner
 * Models a WORK-for-ALLOCATION phase (not true PoW mining).
 * Outputs a JSON plan with expected & banded NIGHT outcomes.
 *
 * Inputs (flags):
 *   --days <int>                Horizon days (default 14)
 *   --hashrate <num>            Your normalized work units/sec (default 50)
 *   --unit-hashrate <num>       Baseline work unit/sec per “unit rig” (default 1)
 *   --diff <num>                Network difficulty scalar (default 1.0)
 *   --cap <num>                 Remaining NIGHT in Scavenger pool (default 1_000_000)
 *   --rng <num>                 RNG volatility 0..1 (default 0.25)
 *
 * Model (simple):
 *   share = (yourHashrate / (yourHashrate + unitHashrate * diff * 100))
 *   finds/day ~ share * k  (k is a tuned constant for event frequency)
 *   NIGHT/day ~ (remainingPool / days) * share * rngAdjustment
 */
import { writeFileSync, mkdirSync } from "fs";
import path from "path";

type Num = number;
const args = new Map(process.argv.slice(2).map(x => {
  const [k, v] = x.replace(/^--/,'').split(/=| /);
  return [k, v ?? "1"];
}));

const horizonDays: Num = Number(args.get("days") || 14);
const yourHashrate: Num = Number(args.get("hashrate") || 50);
const unitHashrate: Num = Number(args.get("unit-hashrate") || 1);
const difficulty: Num = Number(args.get("diff") || 1.0);
const remainingPool: Num = Number(args.get("cap") || 1_000_000);
const rngVol: Num = Math.max(0, Math.min(1, Number(args.get("rng") || 0.25)));

const networkHash = unitHashrate * difficulty * 100;     // crude network size proxy
const share = yourHashrate / (yourHashrate + networkHash);
const poolPerDay = remainingPool / horizonDays;

// RNG band: +/- rngVol around mean with asymmetry bias to the downside
const rngAdjMean = 1.0;
const rngAdjP10  = Math.max(0, 1.0 - 1.5 * rngVol);
const rngAdjP90  = Math.min(2.0, 1.0 + 0.5 * rngVol);

// Expected NIGHT over horizon
const expectedNight = poolPerDay * share * rngAdjMean * horizonDays;
const p10Night      = poolPerDay * share * rngAdjP10  * horizonDays;
const p90Night      = poolPerDay * share * rngAdjP90  * horizonDays;

// “Finds” heuristic: frequency k = 12 events/day network-wide
const k = 12;
const expectedFindsPerDay = share * k;
const expectedFinds = expectedFindsPerDay * horizonDays;

const plan = {
  horizonDays,
  assumptions: {
    networkDifficulty: difficulty,
    rngVolatility: rngVol,
    remainingPool,
    unitHashrate
  },
  yourHashrate,
  expectedFinds: Number(expectedFinds.toFixed(2)),
  expectedNight: Number(expectedNight.toFixed(2)),
  p10Night: Number(p10Night.toFixed(2)),
  p90Night: Number(p90Night.toFixed(2)),
  notes: [
    "This is a planning heuristic, not a guarantee.",
    "Scavenger Mine resembles a time-boxed work-for-allocation event, not open-ended PoW.",
    "Tune --diff, --cap, and --rng as the team publishes real parameters."
  ]
};

const outDir = "apps/midnight-suite/out";
mkdirSync(outDir, { recursive: true });
const outPath = path.join(outDir, "scavenger-plan.json");
writeFileSync(outPath, JSON.stringify(plan, null, 2));
console.log("Wrote", outPath);
console.table({
  share: Number(share.toFixed(6)),
  "exp finds": Number(expectedFinds.toFixed(2)),
  "exp NIGHT": Number(expectedNight.toFixed(2)),
  "p10 NIGHT": Number(p10Night.toFixed(2)),
  "p90 NIGHT": Number(p90Night.toFixed(2))
});
