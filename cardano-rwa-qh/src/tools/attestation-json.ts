#!/usr/bin/env tsx
import { createHash } from 'crypto';
import { promises as fs } from 'fs';
import path from 'path';

function sha256Hex(buf: Buffer) {
  return createHash('sha256').update(buf).digest('hex');
}

async function main() {
  const a = process.argv.slice(2);
  function get(flag: string, req = false) {
    const i = a.indexOf(flag);
    const v = i >= 0 ? a[i + 1] : undefined;
    if (req && !v) {
      console.error(`Missing ${flag}`);
      process.exit(2);
    }
    return v;
  }

  const series = get('--series') || 'QH-R1';
  const network = get('--network', true)!;
  const policyId = get('--policy-id', true)!;
  const policyJsonPath = get('--policy-json', true)!;
  const manifestPath = get('--manifest', true)!;
  const beforeSlot = get('--before-slot');
  const allowSha = get('--allowlist-sha');
  const outPath = get('--out') || `./docs/token/attestation.${network}.json`;

  const absPolicy = path.resolve(process.cwd(), policyJsonPath);
  const absManifest = path.resolve(process.cwd(), manifestPath);
  const [policyRaw, manifestRaw] = await Promise.all([
    fs.readFile(absPolicy),
    fs.readFile(absManifest, 'utf8'),
  ]);

  const policySha = sha256Hex(policyRaw);
  const manifestSha = sha256Hex(Buffer.from(manifestRaw, 'utf8'));
  let manifest;
  try { manifest = JSON.parse(manifestRaw); } catch (e) {
    console.error('Manifest file must be JSON produced by hash-manifest');
    process.exit(2);
  }

  const attestation = {
    series,
    network,
    policyId,
    policyJson: {
      path: path.relative(process.cwd(), absPolicy),
      sha256: policySha,
    },
    lock: {
      beforeSlot: beforeSlot ? Number(beforeSlot) : null,
    },
    proofs: {
      manifest: {
        path: path.relative(process.cwd(), absManifest),
        sha256: manifestSha,
        totals: manifest?.totals ?? null,
        generatedAt: manifest?.generatedAt ?? null,
      },
      allowlistSnapshotSha256: allowSha || null,
    },
    timestamp: new Date().toISOString(),
    build: { tool: 'attestation-json.ts 1.0' },
  };

  const absOut = path.resolve(process.cwd(), outPath);
  await fs.mkdir(path.dirname(absOut), { recursive: true });
  await fs.writeFile(absOut, JSON.stringify(attestation, null, 2));
  console.log(`Wrote attestation: ${absOut}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
