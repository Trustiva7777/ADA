#!/usr/bin/env node
import { writeJSON } from "../common/io.js";

const a = new Map(process.argv.slice(2).map(x => x.split("=").map(s=>s.replace(/^--/,"")) as [string,string]));
const tps = Number(a.get("tps") || 0.5);
const durationDays = Number(a.get("duration-days") || 90);
const safety = Number(a.get("safety") || 1.5);

const assumptions = {
  dustPerTx: 1.0,
  dustGenPerNightPerDay: 0.02,
  decayRatePerDay: 0.005
};

const txCount = tps * 86400 * durationDays;
const dustConsumed = txCount * assumptions.dustPerTx * safety;

const requiredNight = dustConsumed / (assumptions.dustGenPerNightPerDay * durationDays);
const dustProduced = requiredNight * assumptions.dustGenPerNightPerDay * durationDays;
const headroom = dustProduced - dustConsumed;

const plan = { tps, durationDays, safetyFactor: safety, assumptions, requiredNight, dustProduced, dustConsumed, headroom };
writeJSON("apps/midnight-suite/out/dust-plan.json", plan);
console.log("Required NIGHT (approx):", Math.ceil(requiredNight));
