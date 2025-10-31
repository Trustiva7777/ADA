export type ComplianceVerdict = { allowed: boolean; reason?: string };

export async function checkAllowlist(address: string, series: string): Promise<ComplianceVerdict> {
  const url = process.env.COMPLIANCE_URL;
  const token = process.env.COMPLIANCE_TOKEN;

  // Dev fallback: if no URL is set, allow (but log loudly)
  if (!url) {
    console.warn('[compliance] No COMPLIANCE_URL set → DEV ALLOW for', address, series);
    return { allowed: true, reason: 'dev-allow (no endpoint)' };
  }

  const r = await fetch(url, {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {})
    },
    body: JSON.stringify({ address, series, regs: ['RegD', 'RegS'] })
  });

  if (!r.ok) {
    const msg = `[compliance] HTTP ${r.status} ${r.statusText}`;
    console.error(msg);
    return { allowed: false, reason: msg };
  }

  const out = (await r.json().catch(() => null)) as ComplianceVerdict | null;
  if (!out || typeof out.allowed !== 'boolean') {
    return { allowed: false, reason: 'bad response' };
  }
  if (!out.allowed) console.warn('[compliance] blocked:', address, series, out.reason);
  return out;
}
