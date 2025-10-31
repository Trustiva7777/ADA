#!/usr/bin/env node
import fs from "fs";
const line = { ts: new Date().toISOString(), event: process.argv[2] || "note", data: process.argv.slice(3).join(" ") };
fs.mkdirSync("apps/midnight-suite/out", { recursive: true });
fs.appendFileSync("apps/midnight-suite/out/attest-log.jsonl", JSON.stringify(line) + "\n");
console.log("Logged:", line);
