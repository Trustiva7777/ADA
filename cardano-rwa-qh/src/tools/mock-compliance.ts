/**
 * DEV-ONLY mock compliance server
 * POST /api/verify  { address, series, regs?: string[] }
 * returns { allowed: boolean, reason: string }
 *
 * Rules (tweak as you like):
 * - allow any addr that looks like a Cardano bech32 (addr1... or addr_test1...)
 * - block if series not in whitelist (e.g., only "QH-R1" during pilot)
 * - optional sanctions denylist (exact match)
 */
import http from 'node:http';

const PORT = Number(process.env.MOCK_COMPLIANCE_PORT || 8787);
const SERIES_ALLOW = new Set((process.env.MOCK_SERIES || 'QH-R1').split(',').map(s => s.trim()));
const SANCTIONS_DENY = new Set(
  (process.env.MOCK_DENYLIST || '').split(',').map(s => s.trim()).filter(Boolean)
);

function ok(res: http.ServerResponse, allowed: boolean, reason = 'ok') {
  res.writeHead(200, { 'content-type': 'application/json' });
  res.end(JSON.stringify({ allowed, reason }));
}

function looksLikeCardano(addr: string) {
  return /^addr(_test)?1[0-9a-z]+$/i.test(addr);
}

http
  .createServer((req, res) => {
    if (req.method === 'POST' && (req.url || '').startsWith('/api/verify')) {
      let body = '';
      req.on('data', c => (body += c));
      req.on('end', () => {
        try {
          const { address, series } = JSON.parse(body || '{}');
          if (!address || !series) return ok(res, false, 'missing fields');

          if (!SERIES_ALLOW.has(series)) return ok(res, false, 'series not allowed in mock');
          if (!looksLikeCardano(address)) return ok(res, false, 'address format');
          if (SANCTIONS_DENY.has(address)) return ok(res, false, 'sanctioned');

          return ok(res, true, 'dev-allow');
        } catch {
          return ok(res, false, 'bad json');
        }
      });
      return;
    }
    res.writeHead(404);
    res.end();
  })
  .listen(PORT, () => {
    console.log(`Mock compliance running on http://127.0.0.1:${PORT}`);
    console.log(`Allowed series: ${[...SERIES_ALLOW].join(', ') || '(none)'}`);
  });
