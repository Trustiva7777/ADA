import { getLucid } from '../lib/lucid.js';
import { Command } from 'commander';

const program = new Command();
program.option('--days <n>', 'Days from now to lock', '30');
program.parse(process.argv);

(async () => {
  const lucid = await getLucid();
  const now = await lucid.currentSlot();
  const nowSlot = BigInt(now);
  const days = Number(program.getOptionValue('days'));
  const deadline = nowSlot + BigInt(days * 86400);
  console.log('Current slot:', nowSlot.toString());
  console.log(`Deadline (+${days}d):`, deadline.toString());
  console.log('Use: pnpm policy -- --slot-deadline', deadline.toString());
})().catch(e => { console.error(e); process.exit(1); });
