#!/usr/bin/env node
import { readText, writeJSON, parseCsv } from "../common/io.js";

const args = process.argv.slice(2);
const walletsArg = args.find(a => a.startsWith("--wallets")) || "";
const snapshotArg = args.find(a => a.startsWith("--snapshot")) || "";
const thresholdArg = args.find(a => a.startsWith("--threshold")) || "";

const walletsPath = walletsArg.split(":")[1] || "data/wallets.csv";
const snapshotDate = snapshotArg.split(" ")[1] || snapshotArg.split("=")[1] || "2025-06-11";
const threshold = Number(thresholdArg.split(" ")[1] || thresholdArg.split("=")[1] || 100);

const rows = parseCsv(readText(walletsPath));
const eligible = rows.map((r:any) => ({
  chain: r.chain,
  address: r.address,
  usdAtSnapshot: r.usdAtSnapshot,
  selfCustody: !!r.selfCustody,
  eligible: r.selfCustody && r.usdAtSnapshot >= threshold
}));

const report = { snapshotDate, thresholdUsd: threshold, wallets: eligible };
writeJSON("apps/midnight-suite/out/claim-eligibility.json", report);
console.log("Eligible count:", eligible.filter((w:any)=>w.eligible).length);
