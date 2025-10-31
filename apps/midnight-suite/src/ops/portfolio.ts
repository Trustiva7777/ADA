#!/usr/bin/env node
import { parseCsv, readText, writeJSON } from "../common/io.js";

const arg = process.argv.find(a => a.startsWith("--wallets")) || "";
const path = arg.split(":")[1] || "data/wallets.csv";
const rows = parseCsv(readText(path));

const grouped = rows.reduce((acc:any, r:any) => {
  (acc[r.chain] ||= []).push(r);
  return acc;
}, {});
const totals:any = {};
Object.keys(grouped).forEach(chain => {
  totals[chain] = grouped[chain].reduce((s:number, r:any) => s + (r.usdAtSnapshot || 0), 0);
});

const out = { asOf: new Date().toISOString(), totalsUsdAtSnapshot: totals, count: rows.length };
writeJSON("apps/midnight-suite/out/portfolio.json", out);
console.log("Portfolio snapshot:", out);
