# Deploying Your Sovereign Cardano App Endpoints

This guide summarizes what you need to run bp/relays + Ogmios + Kupo + Submit-API and point the CLI at them.

## DNS
- bp.internal.yourdomain (private)
- relay1.yourdomain, relay2.yourdomain
- ogmios.yourdomain, kupo.yourdomain (can colocate on a relay)
- submit.yourdomain (on relay; IP-allowlist)

## Ports
- cardano-node: 3001/tcp (relays public, bp private)
- ogmios: 1337/tcp (TLS behind proxy)
- kupo: 1442/tcp (TLS behind proxy)
- submit-api: 8090/tcp (private; allowlist)

## Security
- Mint key offline/HSM; treasury key separate.
- Submit-API: IP-allowlist CI/ops only; prefer mTLS internally.
- Rotate KES ~ every 90 days.

## Compose (dev/staging)
```
docker compose up -d
```

## App wiring (.env)
```
OGMIOS_URL=wss://ogmios.yourdomain:1337
KUPO_URL=https://kupo.yourdomain:1442
SUBMIT_API_URL=https://submit.yourdomain:8090  # optional
```
- CLI prefers Ogmios+Kupo when both set; otherwise uses Blockfrost.
- If SUBMIT_API_URL is set, submissions POST to Submit-API; else submit via provider.

## Health Checks
- Ogmios: GET /health
- Kupo: GET /
- Submit-API: GET /health

## Nginx (example)
```
server {
  listen 443 ssl;
  server_name ogmios.yourdomain;
  location / {
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_pass http://127.0.0.1:1337;
  }
}

server {
  listen 443 ssl;
  server_name kupo.yourdomain;
  location / {
    proxy_pass http://127.0.0.1:1442;
  }
}

server {
  listen 443 ssl;
  server_name submit.yourdomain;
  allow 203.0.113.10; deny all;
  location / {
    proxy_pass http://127.0.0.1:8090;
  }
}
```

## Cutover Steps
1. Keep Blockfrost in `.env` until your endpoints are green.
2. Set OGMIOS_URL+KUPO_URL (and SUBMIT_API_URL if desired).
3. Run CLI as usual; transactions will flow through your infra.
4. Monitor CPU/disk/net; tune peers/topology; add a second relay before mainnet.
