# Security Policy

## 🔒 Security Overview

The Cardano RWA platform is built with security-first principles covering cryptography, compliance, and operational security.

## Reporting Security Vulnerabilities

**IMPORTANT:** If you discover a security vulnerability, please email `security@trustiva.io` instead of using the public issue tracker.

Include:
- Description of the vulnerability
- Steps to reproduce
- Potential impact
- Suggested fix (if available)

We will acknowledge receipt within 24 hours and provide updates every 5 days. Please allow 90 days for resolution before public disclosure.

## 🛡️ Security Architecture

### Policy Security

```
┌─────────────────────────────────────┐
│  Minting Policy (Time-Locked)       │
├─────────────────────────────────────┤
│  • Multi-signature authorization    │
│  • Time-lock (45+ days after lock)  │
│  • No premature minting possible    │
│  • Cryptographic policy validation  │
└─────────────────────────────────────┘
```

### Evidence Integrity

- **SHA-256 manifests** bind policy to evidence
- **IPFS pinning** prevents tampering
- **Canonical hashing** of allowlists
- **Immutable audit trails** of all operations

### Access Control

- **Allowlist gating** for minting and distribution
- **KYC verification** required before participation
- **Role-based access** to operations
- **Signature verification** for all transactions

## 🔐 Key Management

### Best Practices

1. **Never share private keys** over email or messaging
2. **Use hardware wallets** for mainnet operations
3. **Air-gap signing boxes** for high-value transactions
4. **Encrypted key storage** with strong passphrases
5. **Key rotation policies** (annually recommended)

### Seed Phrase Protection

```bash
# ✅ SECURE: Hardware wallet stored offline
# ❌ INSECURE: Plaintext files in version control
# ❌ INSECURE: Cloud storage without encryption
# ❌ INSECURE: Shared in documentation
```

### Wallet Generation

Use the provided secure wallet generation task:

```bash
# VS Code Task: "Wallet: generate (SeedGen, .NET)"
# Output:
#   - Encrypted seed: Cardano/Dev/Wallet/*/seed.enc (AES-256-GCM)
#   - Public addresses: Cardano/Dev/Wallet/*/addr_*.txt
#   - Extended keys: Cardano/Dev/Wallet/{pay,stake}.xpub
```

The plaintext mnemonic is **never written to disk**.

## 🚨 Container Security

### Security Measures

- **Non-root users**: All services run as UID 1000
- **Read-only filesystems**: Where possible for integrity
- **No new privileges**: Prevents privilege escalation
- **Resource limits**: Prevents DoS attacks
- **Health checks**: Automatic restart on failure
- **Logging**: All operations logged for audit

### Network Isolation

```yaml
networks:
  cardano-net:
    driver: bridge
    internal: true  # Isolated from external access
```

Services are bound to localhost only:
- Ogmios: `127.0.0.1:1337`
- Kupo: `127.0.0.1:1442`
- Submit API: `127.0.0.1:8090`

## 🔍 Code Security

### Dependency Management

```bash
# Check for known vulnerabilities
npm audit

# Update dependencies safely
npm update

# Audit production dependencies
npm audit --production
```

### Type Safety

- **Strict TypeScript**: No implicit `any`
- **Input validation**: All external inputs validated
- **Error handling**: Proper exception handling throughout

## 📋 Compliance & Audit

### Regulatory Standards

- **NI 43-101**: Mining technical reports
- **CIP-20**: Cardano metadata standards
- **CBOR**: Canonical transaction format
- **Audit trails**: Complete operation history

### Evidence Management

All evidence stored with SHA-256 verification:

```json
{
  "ni_43_101_report": "ipfs://QmXxxx",
  "sha256": "abc123def456...",
  "signature": "ed25519_sig",
  "timestamp": "2024-01-15T10:30:00Z"
}
```

## 🔄 Transaction Security

### Offline Signing

For high-value or mainnet transactions:

```bash
# 1. Create transaction plan on connected box
docker run ... payout:draft --csv data.csv

# 2. Export bundle to air-gapped signer
docker run ... signer:export --batch tx_001.json

# 3. Sign on offline box
./scripts/signer/build_sign_submit.sh --pay-skey /secure/key.skey

# 4. Submit from connected box
./submit_batch_001.curl.sh
```

### Fee Management

- **Automatic fee calculation** prevents overpayment
- **Min-fee templates** for each operation
- **Batch fee optimization** for distributions

## 🌐 Network Security

### DNS & TLS

- **TLS 1.2+**: For all remote connections
- **Certificate verification**: Always enabled
- **DNSSEC**: When available
- **No MITM**: Validates certificate chains

### DDoS Protection

- **Rate limiting**: On API endpoints
- **Request validation**: Rejects malformed requests
- **Connection limits**: Prevents resource exhaustion

## 📝 Audit & Monitoring

### Logging

All operations logged with:
- **Timestamp**: ISO 8601 format
- **Operation**: Clear action description
- **User/Address**: Identity of actor
- **Result**: Success/failure with details
- **Hash**: Transaction/policy hash

### Monitoring

```
┌──────────────┐
│ Application  │
└──────┬───────┘
       │
   ┌───▼──────────────┐
   │   Prometheus    │
   │   (metrics)     │
   └───┬──────────────┘
       │
   ┌───▼──────────────┐
   │    Grafana      │
   │  (dashboards)   │
   └─────────────────┘
```

Key metrics monitored:
- Transaction success rates
- Policy lock status
- Allowlist usage
- Distribution progress
- Infrastructure health

## 🚨 Incident Response

### Process

1. **Detection**: Automated alerts or manual report
2. **Triage**: Assess severity (P1=critical, P4=info)
3. **Isolation**: Contain impact (pause operations if needed)
4. **Investigation**: Root cause analysis
5. **Remediation**: Fix and deploy
6. **Notification**: Inform stakeholders
7. **Post-mortem**: Document learnings

### Emergency Contacts

- **Security**: security@trustiva.io
- **Operations**: ops@trustiva.io
- **Emergency**: incident@trustiva.io

## ✅ Security Checklist

### Before Mainnet Launch

- [ ] All security reviews completed
- [ ] Penetration testing done
- [ ] Third-party audit passed
- [ ] Hardware wallet integration tested
- [ ] Key rotation procedure documented
- [ ] Disaster recovery plan tested
- [ ] Incident response plan activated
- [ ] Monitoring alerts configured
- [ ] Compliance audit passed
- [ ] Insurance/bonding in place

### Before Each Distribution

- [ ] Policy lock verified
- [ ] Allowlist finalized and hashed
- [ ] Evidence bundle pinned to IPFS
- [ ] Attestation document signed
- [ ] Distribution amounts calculated
- [ ] Fee estimates confirmed
- [ ] Signer hardware tested
- [ ] Backup signer available
- [ ] Audit log archived

## 📚 Additional Resources

- **Cardano Security**: https://cardano.org/security/
- **Cryptography Best Practices**: https://cheatsheetseries.owasp.org/
- **Supply Chain Security**: https://slsa.dev/
- **Infrastructure as Code**: https://cis.docker.com/cis-docker-benchmark/

## Version History

| Date | Version | Changes |
|------|---------|---------|
| 2024-01-15 | 1.0 | Initial security policy |

---

**Last Updated**: January 2024  
**Maintained By**: Trustiva Security Team
