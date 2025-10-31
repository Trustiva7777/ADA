import fs from 'node:fs';
import path from 'node:path';
import { Command } from 'commander';

const program = new Command();
program.requiredOption('--file <path>', 'Proof bundle JSON');
program.requiredOption('--schema <path>', 'Schema JSON');
program.parse(process.argv);

(async () => {
  const file = program.getOptionValue('file') as string;
  const schemaPath = program.getOptionValue('schema') as string;

  const schema = JSON.parse(fs.readFileSync(path.resolve(schemaPath), 'utf-8'));
  const data = JSON.parse(fs.readFileSync(path.resolve(file), 'utf-8'));

  function requirePath(obj: any, keys: string[], ctx: string) {
    let cur = obj;
    for (const k of keys) {
      if (!(k in cur)) throw new Error(`Missing required ${ctx}: ${keys.join('.')}`);
      cur = cur[k];
    }
  }

  requirePath(data, ['schema'], 'root');
  requirePath(data, ['series'], 'root');
  requirePath(data, ['asset', 'issuer'], 'asset.issuer');
  requirePath(data, ['ops', 'throughput_tpm'], 'ops.throughput_tpm');
  requirePath(data, ['reports'], 'reports');

  if (!Array.isArray(data.reports) || data.reports.length === 0) {
    throw new Error('reports[] must contain at least one item');
  }
  for (const r of data.reports) {
    if (!r.title || !r.hash_sha256 || !r.uri) throw new Error('reports[] items need title/hash/uri');
  }

  // simple schema keys exist check (optional):
  if (!schema || schema.type !== 'object') {
    console.warn('Note: schema minimal check only; for full validation use AJV/Zod in CI.');
  }

  console.log('✅ Proof bundle basic validation passed.');
})().catch(e => { console.error(e.message || e); process.exit(1); });
