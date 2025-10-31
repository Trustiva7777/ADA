import 'dotenv/config';

(async () => {
  const base = (process.env.SUBMIT_API_URL || '').replace(/\/$/, '');
  if (!base) {
    console.error('SUBMIT_API_URL not set');
    process.exit(1);
  }
  const r = await fetch(base + '/health');
  console.log('HTTP', r.status, r.statusText);
  const body = await r.text();
  console.log(body);
})().catch(e => { console.error(e); process.exit(1); });
