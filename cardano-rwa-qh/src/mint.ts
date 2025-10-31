import { getLucid } from './lib/lucid.js';
import { Command } from 'commander';
import { checkAllowlist } from './lib/compliance.js';
import { submitSignedTx } from './lib/submit.js';

const program = new Command();
program
  .requiredOption('--ticker <code>', 'Token ticker (e.g., QH-R1)')
  .requiredOption('--amount <n>', 'Amount to mint (negative = burn)')
  .option('--decimals <n>', 'Decimals (default 2)', '2')
  .option('--name <s>', 'Human name (e.g., QuebradaHonda-Royalty-Phase1)')
  .option('--doc <uri>', 'Evidence bundle URI (ipfs://CID)')
  .option('--to <addr>', 'Receiver address (default: issuer wallet)');
program.parse(process.argv);

(async () => {
  const lucid = await getLucid();
  const issuer = await lucid.wallet.address();

  const ticker = program.getOptionValue('ticker') as string;
  const amount = BigInt(program.getOptionValue('amount'));
  const decimals = Number(program.getOptionValue('decimals')||'2');
  const name = (program.getOptionValue('name') as string) || ticker;
  const doc = (program.getOptionValue('doc') as string) || '';
  const to = (program.getOptionValue('to') as string) || issuer;

  const allow = await checkAllowlist(to, ticker);
  if (!allow.allowed) throw new Error('Compliance blocked: ' + allow.reason);

  const pkh = lucid.utils.getAddressDetails(issuer).paymentCredential?.hash!;
  const script: any = { type: 'sig', keyHash: pkh };
  const policyId = lucid.utils.mintingPolicyToId(script);
  const unit = policyId + Buffer.from(ticker).toString('hex');

  const metadata: any = {
    [policyId]: {
      [ticker]: {
        name, ticker, decimals,
        description: 'Royalty token on Net Revenue from Quebrada Honda I & II (Phase 1)',
        docs: doc ? [doc] : []
      }
    }
  };

  const tx = await lucid.newTx()
    .attachMetadata(721, metadata)
    .mintAssets({ [unit]: amount }, script)
    .payToAddress(to, { [unit]: amount > 0n ? amount : 0n })
    .complete();

  const signed = await tx.sign().complete();
  const txHash = await submitSignedTx(signed);
  console.log('TX:', txHash);
  console.log('PolicyId:', policyId);
  console.log('Unit:', unit);
})().catch(e => { console.error(e); process.exit(1); });
