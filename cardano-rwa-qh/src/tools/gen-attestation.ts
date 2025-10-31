#!/usr/bin/env tsx
import { createHash } from 'crypto';
import { Command } from 'commander';
import { promises as fs } from 'fs';
import path from 'path';
import dotenv from 'dotenv';

dotenv.config();

interface ManifestEntry { path: string; size: number; sha256: string; }
interface ManifestFile {
  generatedAt: string;
  rootDir: string;
  ignore: string[];
  entries: ManifestEntry[];
  totals: { files: number; bytes: number };
}

function sha256String(input: string): string {
  const h = createHash('sha256');
  h.update(input);
  return h.digest('hex');
}

async function fileSha256(filePath: string): Promise<string> {
  const buf = await fs.readFile(filePath);
  const h = createHash('sha256');
  h.update(buf);
  return h.digest('hex');
}

async function main() {
  const program = new Command();
  program
    .requiredOption('--policy <policyId>', 'Policy ID for the series')
    .requiredOption('--network <network>', 'Network (Preprod|Mainnet)')
    .requiredOption('--manifest <file>', 'Path to sha256 manifest JSON created by hash-manifest')
    .option('--allowlist-sha <sha256>', 'SHA-256 of frozen allowlist snapshot JSON/CSV')
    .option('--compliance-url <url>', 'Compliance API base URL (defaults to env COMPLIANCE_URL)')
    .option('--out <file>', 'Output attestation file', './docs/attestation.json')
    .option('--series <name>', 'Series name', 'QH-R1');

  program.parse(process.argv);
  const opts = program.opts<{
    policy: string; network: string; manifest: string; out: string; allowlistSha?: string; complianceUrl?: string; series: string;
  }>();

  const manifestPath = path.resolve(process.cwd(), opts.manifest);
  const manifestRaw = await fs.readFile(manifestPath, 'utf8');
  const manifest: ManifestFile = JSON.parse(manifestRaw);
  const manifestSha = sha256String(manifestRaw);

  const now = new Date().toISOString();
  const complianceUrl = opts.complianceUrl || process.env.COMPLIANCE_URL || '';

  const attestation = {
    series: opts.series,
    network: opts.network,
    policyId: opts.policy,
    timestamp: now,
    proofs: {
      manifest: {
        path: path.relative(process.cwd(), manifestPath),
        sha256: manifestSha,
        totals: manifest.totals,
        generatedAt: manifest.generatedAt,
      },
      allowlistSnapshotSha256: opts.allowlistSha || null,
    },
    compliance: {
      url: complianceUrl || null,
    },
    build: {
      tool: 'cardano-rwa-qh/gen-attestation 1.0',
    },
  };

  const outPath = path.resolve(process.cwd(), opts.out);
  await fs.mkdir(path.dirname(outPath), { recursive: true });
  await fs.writeFile(outPath, JSON.stringify(attestation, null, 2));
  console.log(`Wrote attestation: ${outPath}`);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
