#!/usr/bin/env tsx
import { createHash } from 'crypto';
import { Command } from 'commander';
import { promises as fs } from 'fs';
import path from 'path';

interface ManifestEntry {
  path: string;
  size: number;
  sha256: string;
}

interface ManifestFile {
  generatedAt: string; // ISO timestamp
  rootDir: string; // as provided
  ignore: string[];
  entries: ManifestEntry[];
  totals: {
    files: number;
    bytes: number;
  };
}

async function fileSha256(filePath: string): Promise<{ sha256: string; size: number }> {
  const hash = createHash('sha256');
  const data = await fs.readFile(filePath);
  hash.update(data);
  return { sha256: hash.digest('hex'), size: data.length };
}

async function walk(dir: string, ignore: Set<string>): Promise<string[]> {
  const out: string[] = [];
  const items = await fs.readdir(dir, { withFileTypes: true });
  for (const it of items) {
    const p = path.join(dir, it.name);
    const name = it.name;
    if (ignore.has(name)) continue;
    if (it.isDirectory()) {
      out.push(...(await walk(p, ignore)));
    } else if (it.isFile()) {
      out.push(p);
    }
  }
  return out;
}

async function main() {
  const program = new Command();
  program
    .requiredOption('--dir <dir>', 'Directory to hash')
    .requiredOption('--out <file>', 'Output manifest JSON path')
    .option('--ignore <list>', 'Comma-separated names to ignore (top-level each dir)', '')
    .option('--relative', 'Store relative paths', true);

  program.parse(process.argv);
  const opts = program.opts<{ dir: string; out: string; ignore: string; relative?: boolean }>();

  const rootDir = path.resolve(process.cwd(), opts.dir);
  const ignore = new Set((opts.ignore || '').split(',').map((s) => s.trim()).filter(Boolean));

  const files = await walk(rootDir, ignore);
  const entries: ManifestEntry[] = [];
  let totalBytes = 0;

  for (const f of files) {
    const { sha256, size } = await fileSha256(f);
    totalBytes += size;
    const rel = path.relative(rootDir, f) || path.basename(f);
    entries.push({ path: opts.relative ? rel : f, size, sha256 });
  }

  entries.sort((a, b) => a.path.localeCompare(b.path));

  const manifest: ManifestFile = {
    generatedAt: new Date().toISOString(),
    rootDir: opts.relative ? path.basename(rootDir) : rootDir,
    ignore: Array.from(ignore),
    entries,
    totals: { files: entries.length, bytes: totalBytes },
  };

  const outPath = path.resolve(process.cwd(), opts.out);
  await fs.mkdir(path.dirname(outPath), { recursive: true });
  await fs.writeFile(outPath, JSON.stringify(manifest, null, 2));
  // Also print a short summary
  console.log(`Wrote manifest: ${outPath}`);
  console.log(`Files: ${manifest.totals.files}, Bytes: ${manifest.totals.bytes}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
