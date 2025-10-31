import fs from 'node:fs';
import path from 'node:path';
import { Command } from 'commander';

/*
Simple compliance preflight:
- Validates policy JSON and required fields
- Validates proof bundle (basic shape)
- Validates mint params (ticker, decimals, doc uri)
- Pings COMPLIANCE_URL
- For distributions: iterates CSV rows and calls compliance API per address
*/

function readJson(p: string) {
  return JSON.parse(fs.readFileSync(path.resolve(p), 'utf-8')) as any;
}

async function pingCompliance(): Promise<void> {
  const url = process.env.COMPLIANCE_URL;
  if (!url) throw new Error('COMPLIANCE_URL not set');
  const r = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ address: 'addr_test1qp9m3x...', series: 'health' }) });
  if (!r.ok) throw new Error(`COMPLIANCE_URL health failed: HTTP ${r.status}`);
}

function validatePolicy(policy: any, series: string) {
  const required = ['series','allowedRegs','requireProof','evidenceReportsMin','decimals'];
  for (const k of required) if (!(k in policy)) throw new Error(`policy missing ${k}`);
  if (policy.series !== series) throw new Error(`policy.series mismatch: ${policy.series} != ${series}`);
  if (!Array.isArray(policy.allowedRegs) || policy.allowedRegs.length === 0) throw new Error('allowedRegs must be non-empty');
  if (typeof policy.requireProof !== 'boolean') throw new Error('requireProof must be boolean');
  if (typeof policy.evidenceReportsMin !== 'number' || policy.evidenceReportsMin < 1) throw new Error('evidenceReportsMin must be >=1');
  if (!policy.decimals || typeof policy.decimals.min !== 'number' || typeof policy.decimals.max !== 'number') throw new Error('decimals.min/max required');
}

function validateProof(proof: any, policy: any) {
  const required = ['schema','series','asset','ops','reports'];
  for (const k of required) if (!(k in proof)) throw new Error(`proof missing ${k}`);
  if (policy.requireProof && (!Array.isArray(proof.reports) || proof.reports.length < policy.evidenceReportsMin)) {
    throw new Error(`proof requires at least ${policy.evidenceReportsMin} report(s)`);
  }
}

function isIpfsUri(u?: string) {
  return !!u && /^ipfs:\/\//i.test(u);
}

async function complianceCheckAddress(addr: string, series: string): Promise<{allowed:boolean, reason?:string}> {
  const url = process.env.COMPLIANCE_URL!;
  const token = process.env.COMPLIANCE_TOKEN;
  const r = await fetch(url, {
    method: 'POST', headers: { 'content-type': 'application/json', ...(token?{authorization:`Bearer ${token}`}:{}) },
    body: JSON.stringify({ address: addr, series })
  });
  const out = (await r.json().catch(() => null)) as any;
  return out && typeof out.allowed === 'boolean' ? out : { allowed: false, reason: 'bad response' };
}

async function run() {
  const program = new Command();
  program
    .requiredOption('--series <s>')
    .requiredOption('--policy <path>')
    .requiredOption('--action <mint|distribute>')
    .option('--proof <path>')
    .option('--ticker <s>')
    .option('--decimals <n>')
    .option('--doc <uri>')
    .option('--csv <path>', 'required for distribute')
    .option('--skip-api', 'skip compliance API calls (for CI smoke)');
  program.parse(process.argv);

  const series = program.getOptionValue('series') as string;
  const policyPath = program.getOptionValue('policy') as string;
  const action = program.getOptionValue('action') as string;
  const proofPath = program.getOptionValue('proof') as string | undefined;
  const ticker = program.getOptionValue('ticker') as string | undefined;
  const decimals = program.getOptionValue('decimals') ? Number(program.getOptionValue('decimals')) : undefined;
  const doc = program.getOptionValue('doc') as string | undefined;
  const csvPath = program.getOptionValue('csv') as string | undefined;

  const policy = readJson(policyPath);
  validatePolicy(policy, series);

  if (policy.requireProof) {
    if (!proofPath) throw new Error('proof path required by policy');
    const proof = readJson(proofPath);
    validateProof(proof, policy);
  }

  if (action === 'mint') {
    if (!ticker) throw new Error('ticker required for mint action');
    if (decimals === undefined) throw new Error('decimals required for mint action');
    if (decimals < policy.decimals.min || decimals > policy.decimals.max) throw new Error(`decimals ${decimals} out of bounds`);
    if (doc && !isIpfsUri(doc)) throw new Error('doc must be ipfs:// URI when provided');
  }

  const skipApi = !!program.getOptionValue('skipApi');
  if (!skipApi) await pingCompliance();

  if (action === 'distribute') {
    if (!csvPath) throw new Error('--csv required for distribute');
    // quick CSV reader (header: wallet_address,...)
    const raw = fs.readFileSync(path.resolve(csvPath), 'utf-8').trim().split(/\r?\n/);
    const header = raw.shift()?.split(',') || [];
    const idx = header.indexOf('wallet_address');
    if (idx === -1) throw new Error('CSV must contain wallet_address column');
    let allowed = 0, blocked = 0;
    for (const line of raw) {
      const cols = line.split(',');
      const addr = cols[idx];
      if (!addr) continue;
      const verdict = skipApi ? { allowed: true } : await complianceCheckAddress(addr, series);
      if (verdict.allowed) allowed++; else blocked++;
    }
    if (blocked > 0) throw new Error(`distribution blocked: ${blocked} address(es) failed compliance`);
    console.log(`distribution compliance OK (${allowed} addresses)`);
  }

  console.log('✅ compliance preflight passed');
}

run().catch(e => { console.error(e.message || e); process.exit(1); });
