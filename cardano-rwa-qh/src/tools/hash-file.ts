#!/usr/bin/env tsx
import { createHash } from 'crypto';
import { promises as fs } from 'fs';
import path from 'path';

async function main() {
  const args = process.argv.slice(2);
  const fileIdx = args.indexOf('--file');
  const outIdx = args.indexOf('--out');
  if (fileIdx === -1 || !args[fileIdx + 1]) {
    console.error('Usage: tsx src/tools/hash-file.ts --file <path> [--out <json>]');
    process.exit(2);
  }
  const file = path.resolve(process.cwd(), args[fileIdx + 1]);
  const out = outIdx !== -1 && args[outIdx + 1] ? path.resolve(process.cwd(), args[outIdx + 1]) : undefined;
  const data = await fs.readFile(file);
  const sha = createHash('sha256').update(data).digest('hex');
  const result = { file: path.basename(file), path: file, size: data.length, sha256: sha };
  if (out) {
    await fs.writeFile(out, JSON.stringify(result, null, 2));
    console.log(`Wrote ${out}`);
  } else {
    console.log(JSON.stringify(result, null, 2));
  }
}

main().catch((e) => { console.error(e); process.exit(1); });
