export async function submitSignedTx(signed: any): Promise<string> {
  const submitUrl = process.env.SUBMIT_API_URL;
  // If no submit-api configured, use provider default
  if (!submitUrl) return await signed.submit();

  // cardano-submit-api expects raw CBOR in the body with content-type: application/cbor
  const hex: string = signed.toString();
  const buf = Buffer.from(hex, 'hex');

  const endpoint = submitUrl.replace(/\/$/, '') + '/api/submit/tx';
  const r = await fetch(endpoint, {
    method: 'POST',
    headers: { 'content-type': 'application/cbor' },
    body: buf
  });
  const text = await r.text().catch(() => '');
  if (!r.ok) throw new Error(`submit-api HTTP ${r.status}: ${text || r.statusText}`);

  // Some submit-api builds return JSON, some return plain tx hash; try to parse
  try {
    const j = JSON.parse(text);
    const hash = j?.SubmitSuccess || j?.txId || j?.txid || j?.hash || text.trim();
    if (!hash) throw new Error('no hash');
    return String(hash);
  } catch {
    return text.trim();
  }
}