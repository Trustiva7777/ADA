# 🚀 Production Deployment Checklist

Use this checklist before deploying to production mainnet.

## Pre-Deployment Phase

### Infrastructure Preparation

- [ ] **Hardware Review**
  - [ ] Production server specifications meet requirements (8+ GB RAM, 100GB+ disk)
  - [ ] Network bandwidth: ≥50 Mbps for Cardano sync
  - [ ] Redundant power supply configured
  - [ ] Backup storage available (500GB+ for node database)

- [ ] **Network Setup**
  - [ ] Firewall rules configured (only allow required ports)
  - [ ] DDoS protection enabled (CloudFlare or similar)
  - [ ] SSL/TLS certificates obtained (Let's Encrypt or CA)
  - [ ] DNS records configured and verified
  - [ ] VPN/bastion host setup for secure access

- [ ] **Access Control**
  - [ ] SSH keys rotated (no password-based access)
  - [ ] IP whitelisting configured
  - [ ] VPN access setup for team
  - [ ] MFA enabled on all accounts

### Software Preparation

- [ ] **Code Review**
  - [ ] All changes reviewed and approved
  - [ ] No hardcoded credentials in codebase
  - [ ] All secrets in secure vault
  - [ ] Security audit completed
  - [ ] Penetration testing passed

- [ ] **Testing Complete**
  - [ ] Unit tests pass (100% critical path coverage)
  - [ ] Integration tests pass
  - [ ] Load tests completed and results reviewed
  - [ ] Security scanning passed
  - [ ] Staging environment mirrors production

- [ ] **Dependencies**
  - [ ] Docker images built and scanned for vulnerabilities
  - [ ] All packages at pinned, known-good versions
  - [ ] License compliance verified
  - [ ] Dependency audit clean

### Compliance & Documentation

- [ ] **Legal & Compliance**
  - [ ] Terms of Service reviewed
  - [ ] Privacy policy in place
  - [ ] KYC/AML procedures documented
  - [ ] Regulatory requirements confirmed
  - [ ] Insurance/bonding verified

- [ ] **Documentation**
  - [ ] Runbooks written for common operations
  - [ ] Disaster recovery plan documented
  - [ ] Backup/restore procedures tested
  - [ ] On-call procedures established
  - [ ] Architecture diagram current

- [ ] **Monitoring & Alerting**
  - [ ] Prometheus configured and tested
  - [ ] Grafana dashboards created
  - [ ] Alert thresholds set appropriately
  - [ ] PagerDuty/alerting system configured
  - [ ] Log aggregation setup (ELK/Splunk)

## Deployment Day

### Pre-Deployment Checks (3 hours before)

- [ ] **System Health**
  - [ ] Run `./verify-system.sh` - all checks pass
  - [ ] Network latency acceptable
  - [ ] Disk space available (>20% free)
  - [ ] Memory available (>2GB free)
  - [ ] Load average normal

- [ ] **Backups**
  - [ ] Full backup created
  - [ ] Backup verified (restore test)
  - [ ] Backup stored securely offsite
  - [ ] Backup retention policy active

- [ ] **Communication**
  - [ ] Team notified of deployment window
  - [ ] Status page updated
  - [ ] Incident commander assigned
  - [ ] On-call team ready

### Deployment Steps

#### Phase 1: Pull and Validate

- [ ] Stop old services: `./docker-manage.sh down`
- [ ] Backup current volumes: `./docker-manage.sh backup`
- [ ] Pull latest code: `git pull origin main`
- [ ] Review latest changes: `git log --oneline -10`
- [ ] Build new images: `./docker-manage.sh build`
- [ ] Scan images for vulnerabilities: `docker scan <image>`

#### Phase 2: Start Services (Gradual)

- [ ] Start Cardano node: `docker-compose up -d cardano-node`
- [ ] Wait 2 minutes for startup
- [ ] Verify node health: `curl http://localhost:1337/health`

- [ ] Start Ogmios: `docker-compose up -d ogmios`
- [ ] Wait 1 minute for startup
- [ ] Verify Ogmios health: `curl http://localhost:1337/health`

- [ ] Start Kupo: `docker-compose up -d kupo`
- [ ] Wait 1 minute for startup
- [ ] Verify Kupo health: `curl http://localhost:1442`

- [ ] Start backend: `docker-compose up -d backend`
- [ ] Wait 30 seconds
- [ ] Verify API health: `curl http://localhost:8080/health`

- [ ] Start frontend: `docker-compose up -d frontend`
- [ ] Wait 30 seconds
- [ ] Verify frontend loads: `curl http://localhost:8081`

- [ ] Start monitoring: `docker-compose up -d prometheus grafana`

#### Phase 3: Validation

- [ ] Run verification script: `./verify-system.sh`
- [ ] Check all services healthy
- [ ] Check logs for errors: `docker-compose logs`
- [ ] Verify API endpoints responding
- [ ] Check Grafana dashboards
- [ ] Smoke test critical workflows

#### Phase 4: Monitoring (30 minutes)

- [ ] Monitor error rates in Prometheus
- [ ] Check application logs for warnings
- [ ] Verify transaction processing
- [ ] Monitor CPU/memory/disk usage
- [ ] Verify backup processes

### Post-Deployment

- [ ] **Immediate (within 1 hour)**
  - [ ] All services healthy and responding
  - [ ] No error spikes in logs
  - [ ] Transactions processing normally
  - [ ] Database backups running
  - [ ] Monitoring alerts not firing

- [ ] **Ongoing (24 hours)**
  - [ ] No issues reported by users
  - [ ] All metrics normal
  - [ ] Cardano node fully synced
  - [ ] UTxO index complete (Kupo)
  - [ ] Performance metrics acceptable

- [ ] **Follow-up (1 week)**
  - [ ] Conduct post-mortem if any issues
  - [ ] Update runbooks with learnings
  - [ ] Document any configuration changes
  - [ ] Review monitoring effectiveness
  - [ ] Assess resource utilization

## Rollback Procedure

If critical issues occur:

### Immediate Actions

- [ ] **Declare incident** via established channels
- [ ] **Assemble team** (incident commander, DBA, DevOps)
- [ ] **Assess severity** (can continue or need rollback?)

### Rollback Steps

```bash
# 1. Stop all services
./docker-manage.sh down

# 2. Restore from backup
./docker-manage.sh restore -s backups/<TIMESTAMP>

# 3. Verify restored state
./verify-system.sh

# 4. Start services
./docker-manage.sh up

# 5. Validate
./verify-system.sh

# 6. Document incident
# Create incident report with timeline and root cause
```

### Post-Rollback

- [ ] Services operational
- [ ] Data integrity verified
- [ ] No data loss
- [ ] Users notified
- [ ] Incident report created
- [ ] Root cause analysis completed
- [ ] Fix implemented and tested
- [ ] Schedule re-deployment

## Security Validation

### Before Production

- [ ] **Secrets Management**
  - [ ] No secrets in git history
  - [ ] Environment variables used for all secrets
  - [ ] Secrets rotated within last 90 days
  - [ ] Secrets stored in secure vault

- [ ] **Access Control**
  - [ ] Minimum privilege enforced
  - [ ] No shared credentials
  - [ ] All access logged
  - [ ] SSH key-based auth only

- [ ] **Network Security**
  - [ ] TLS 1.2+ enforced
  - [ ] Only required ports exposed
  - [ ] Rate limiting enabled
  - [ ] WAF rules configured

- [ ] **Application Security**
  - [ ] Input validation on all endpoints
  - [ ] SQL injection protections active
  - [ ] CSRF tokens present
  - [ ] Security headers configured

## Performance Baseline

Document expected performance metrics:

| Metric | Target | Current |
|--------|--------|---------|
| API Response Time (p99) | <100ms | _____ |
| Transaction Throughput | >100 tx/sec | _____ |
| Cardano Node Sync Time | <24 hours | _____ |
| Uptime | >99.9% | _____ |
| Error Rate | <0.1% | _____ |

## Sign-Off

- [ ] **Lead Developer**: _________________ Date: _______
- [ ] **DevOps Lead**: _________________ Date: _______
- [ ] **Security Lead**: _________________ Date: _______
- [ ] **Product Owner**: _________________ Date: _______

## Notes & Issues

```
Issues encountered:
- 
- 

Resolutions applied:
-
-

Additional notes:
```

---

**Deployment Started**: _________________ Date: _______  
**Deployment Completed**: _________________ Date: _______  
**Total Duration**: _______  
**Status**: [ ] Success [ ] Rollback [ ] Partial

