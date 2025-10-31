import 'dotenv/config';
import { Command } from 'commander';

const program = new Command();
program.requiredOption('--policy <id>', 'Policy ID');
program.requiredOption('--asset <hexName>', 'Asset name in hex (e.g., 51482d5231 for QH-R1)');
program.option('--limit <n>', 'Max pages to fetch', '50');
program.parse(process.argv);

(async () => {
  const policy = program.getOptionValue('policy') as string;
  const assetHex = program.getOptionValue('asset') as string;
  const apiKey = process.env.BLOCKFROST_API_KEY!;
  const network = process.env.NETWORK || 'Preview';
  const base =
    network === 'Mainnet'
      ? 'https://cardano-mainnet.blockfrost.io/api/v0'
      : network === 'Preprod'
      ? 'https://cardano-preprod.blockfrost.io/api/v0'
      : 'https://cardano-preview.blockfrost.io/api/v0';

  const assetId = `${policy}${assetHex}`;
  let page = 1;
  const limitPages = Number(program.getOptionValue('limit'));

  const holders = new Map<string, bigint>();

  while (page <= limitPages) {
    const res = await fetch(`${base}/assets/${assetId}/addresses?page=${page}`, {
      headers: { project_id: apiKey }
    });
    if (!res.ok) break;
    const items: any[] = await res.json();
    if (items.length === 0) break;
    for (const it of items) {
      const qty = BigInt(it.quantity);
      holders.set(it.address, (holders.get(it.address) || 0n) + qty);
    }
    page++;
  }

  let total = 0n;
  for (const v of holders.values()) total += v;

  console.log('Asset:', assetId);
  console.log('Holders:', holders.size);
  console.log('Total units:', total.toString());
  console.log('address,units');
  for (const [addr, qty] of holders) {
    console.log(`${addr},${qty.toString()}`);
  }
})().catch(e => { console.error(e); process.exit(1); });
