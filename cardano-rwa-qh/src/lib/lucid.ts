import 'dotenv/config';
import { Lucid, Blockfrost, Kupmios } from 'lucid-cardano';

export type Network = 'Preview' | 'Preprod' | 'Mainnet';

export async function getLucid() {
  const network = (process.env.NETWORK as Network) || 'Preview';

  const ogmios = process.env.OGMIOS_URL;
  const kupo = process.env.KUPO_URL;
  let lucid: Lucid;

  if (ogmios && kupo) {
    // Use self-hosted Ogmios + Kupo
    const provider = new Kupmios(ogmios, kupo);
    lucid = await Lucid.new(provider, network === 'Mainnet' ? 'Mainnet' : (network as any));
  } else {
    // Fallback to Blockfrost during pilot
    const apiKey = process.env.BLOCKFROST_API_KEY;
    if (!apiKey) throw new Error('Missing BLOCKFROST_API_KEY or OGMIOS_URL+KUPO_URL');
    const endpoint =
      network === 'Mainnet'
        ? 'https://cardano-mainnet.blockfrost.io/api/v0'
        : network === 'Preprod'
        ? 'https://cardano-preprod.blockfrost.io/api/v0'
        : 'https://cardano-preview.blockfrost.io/api/v0';
    lucid = await Lucid.new(new Blockfrost(endpoint, apiKey), network === 'Mainnet' ? 'Mainnet' : (network as any));
  }

  const seed = process.env.ISSUER_SEED;
  const sk = process.env.ISSUER_SK;
  if (seed) {
    await lucid.selectWalletFromSeed(seed.trim());
  } else if (sk) {
    await lucid.selectWalletFromPrivateKey(sk.trim());
  } else {
    throw new Error('Provide ISSUER_SEED or ISSUER_SK in .env');
  }

  return lucid;
}
