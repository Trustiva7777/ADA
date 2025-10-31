import { Command } from 'commander';
import { readCsv } from './lib/utils.js';
import { getLucid } from './lib/lucid.js';
import { submitSignedTx } from './lib/submit.js';

const program = new Command();
program
  .requiredOption('--csv <path>', 'CSV with address, tokens_held, pro_rata_share, payout_amount_usd')
  .option('--mode <plan|send-ada>', 'Plan = compute only; send-ada = pay ADA instead of USDC', 'plan')
  .option('--fx <n>', 'USD→ADA fx rate (only for send-ada mode)', '0');
program.parse(process.argv);

(async () => {
  const mode = program.getOptionValue('mode') as string;
  const csvPath = program.getOptionValue('csv') as string;
  const fx = Number(program.getOptionValue('fx') || '0');

  const rows = await readCsv(csvPath);
  if (mode === 'plan') {
    let total = 0;
    for (const r of rows) {
      const a = Number(r.payout_amount_usd || 0);
      total += a;
      console.log(`${r.wallet_address}, USD ${a.toFixed(2)}, units=${r.tokens_held}, share=${r.pro_rata_share}`);
    }
    console.log('TOTAL USD:', total.toFixed(2));
    console.log('Export this plan to your USDC/USD payment processor.');
    return;
  }

  if (mode === 'send-ada') {
    if (!fx || fx <= 0) throw new Error('Provide a positive --fx USD→ADA rate');
    const lucid = await getLucid();

    const builder = lucid.newTx();
    let count = 0, totalAda = 0;
    for (const r of rows) {
      const usd = Number(r.payout_amount_usd || 0);
      const ada = usd * fx;                // simplistic: you choose the rate/reporting externally
      const lovelace = BigInt(Math.round(ada * 1_000_000));
      if (lovelace > 0n) {
        builder.payToAddress(r.wallet_address, { lovelace });
        totalAda += ada; count++;
        console.log(`Paying ~${ada.toFixed(6)} ADA to ${r.wallet_address}`);
      }
    }
  const tx = await builder.complete();
  const signed = await tx.sign().complete();
  const hash = await submitSignedTx(signed);
    console.log(`Sent ${count} outputs, ~${totalAda.toFixed(6)} ADA total`);
    console.log('TX:', hash);
    console.log('Note: This sends ADA, not USDC. For USDC, stay in --mode plan and use off-chain rails.');
    return;
  }

  throw new Error('Unknown mode');
})().catch(e => { console.error(e); process.exit(1); });
