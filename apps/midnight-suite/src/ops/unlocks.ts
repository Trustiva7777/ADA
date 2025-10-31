#!/usr/bin/env node
import { addDays } from "../common/dates.js";
import { writeJSON } from "../common/io.js";

const a = new Map(process.argv.slice(2).map(x => x.split("=").map(s=>s.replace(/^--/,"")) as [string,string]));
const start = a.get("start") || "2025-10-15";  // adjust as needed
const totalDays = Number(a.get("days") || 360);
const events = Number(a.get("events") || 4);

const gap = Math.floor(totalDays / events);
const schedule = Array.from({length: events}, (_,i) => ({
  label: `Unlock ${i+1}`,
  date: addDays(start, (i+1)*gap),
  percent: Math.round(10000 / events) / 100
}));

const out = { startDate: start, events: schedule };
writeJSON("apps/midnight-suite/out/unlock-schedule.json", out);
console.log("Unlock schedule:", out);
