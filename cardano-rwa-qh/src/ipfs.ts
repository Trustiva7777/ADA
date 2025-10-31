import { Command } from 'commander';

const program = new Command();
program.requiredOption('--file <path>', 'File to upload (pdf/json/etc.)');
program.parse(process.argv);

(async () => {
  const path = program.getOptionValue('file') as string;
  console.log('Upload stub:', path);
  console.log('Plug this into your preferred IPFS pinning (Web3.Storage/Pinata) and record CID in docs/proof bundle.');
  // Keep hashes (sha256) of source files in your off-chain registry for audit.
})().catch(e => { console.error(e); process.exit(1); });
