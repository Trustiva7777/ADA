import { getLucid } from './lib/lucid.js';

(async () => {
  const lucid = await getLucid();
  const addr = await lucid.wallet.address();
  console.log('Network:', process.env.NETWORK);
  console.log('Address:', addr);
  const utxos = await lucid.utxosAt(addr);
  console.log('UTxOs:', utxos.length);
  for (const u of utxos.slice(0, 5)) {
    console.log(`- ${u.txHash}#${u.outputIndex} -> ${(u.assets['lovelace'] || 0n).toString()} lovelace`);
  }
})().catch(e => { console.error(e); process.exit(1); });
