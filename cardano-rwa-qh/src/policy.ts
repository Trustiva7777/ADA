import { getLucid } from './lib/lucid.js';
import { Command } from 'commander';

const program = new Command();
program.option('--slot-deadline <n>', 'Absolute slot to stop minting (optional)');
program.parse(process.argv);

(async () => {
  const lucid = await getLucid();
  const addr = await lucid.wallet.address();
  const pkh = lucid.utils.getAddressDetails(addr).paymentCredential?.hash!;
  const slotDeadline = program.getOptionValue('slotDeadline');

  let script: any = { type: 'sig', keyHash: pkh };
  if (slotDeadline) script = { type: 'all', scripts: [ { type: 'sig', keyHash: pkh }, { type: 'before', slot: BigInt(slotDeadline) } ] };

  const policyId = lucid.utils.mintingPolicyToId(script);

  console.log('PolicyId:', policyId);
  console.log('Native Script JSON:\n', JSON.stringify(script, null, 2));
  console.log('Tip: publish this JSON & policyId in your data room before mint day.');
})().catch(e => { console.error(e); process.exit(1); });
