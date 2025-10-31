# Security Hardening Guide — QH-R1 RWA Infrastructure

## Input Validation

### API Endpoints
- All API inputs must be validated using JSON schema validation
- Implement rate limiting (100 requests/minute per IP)
- Use parameterized queries to prevent SQL injection
- Validate all CBOR-encoded data before processing
- Implement bounds checking for numeric inputs

### Smart Contract Parameters
- Validate policy IDs are 56-character hex strings
- Check slot numbers are within reasonable ranges
- Verify asset names conform to Cardano standards
- Validate oracle signatures using proper cryptographic verification

## Secret Management

### Key Rotation Procedures
1. Generate new keys using air-gapped signer
2. Update policy scripts with new key hashes
3. Test new policy IDs on testnet before mainnet
4. Archive old keys securely (encrypted, offline storage)
5. Update all dependent systems (monitoring, backups)

### Environment Variables
- Never commit secrets to version control
- Use `.env` files with proper permissions (600)
- Rotate API keys quarterly
- Use different keys for testnet/mainnet environments

## Network Security

### Container Security
- Run containers as non-root users
- Use read-only root filesystems where possible
- Implement network segmentation between services
- Use secrets management for sensitive configuration

### Monitoring & Alerting
- Monitor for unusual transaction patterns
- Alert on policy violations or unauthorized minting attempts
- Log all compliance API calls with IP addresses
- Implement SIEM integration for security events

## Compliance Controls

### On-Chain Validation
- All transactions must reference compliance datums
- Oracle signatures must be verified before processing
- Policy locks must be enforced at the protocol level
- Maintain audit trails of all compliance decisions

### Access Controls
- Implement role-based access control (RBAC)
- Require multi-signature for critical operations
- Use hardware security modules (HSM) for key storage
- Implement session timeouts and concurrent session limits

## Incident Response

### Breach Procedures
1. Immediately isolate affected systems
2. Notify relevant stakeholders within 1 hour
3. Preserve evidence for forensic analysis
4. Execute recovery procedures from backups
5. Conduct post-mortem and implement fixes

### Backup Security
- Encrypt all backups with strong keys
- Store backups in multiple geographic locations
- Test backup restoration procedures quarterly
- Implement immutable backup storage to prevent ransomware

## Mainnet Deployment Checklist

### Pre-Deployment
- [ ] Complete security audit by external firm
- [ ] Legal review of all documentation
- [ ] Testnet validation of all flows (45+ days)
- [ ] Performance testing under load
- [ ] Backup and disaster recovery testing

### Deployment Day
- [ ] Final policy ID generation on air-gapped system
- [ ] Multi-signature policy creation
- [ ] Compliance API deployment with monitoring
- [ ] Infrastructure provisioning with security hardening
- [ ] Initial allowlist population

### Post-Deployment
- [ ] 24/7 monitoring activation
- [ ] Incident response team readiness
- [ ] Stakeholder communication plan
- [ ] Quarterly security assessments