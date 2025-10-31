## Summary
Describe the change and its purpose.

## Compliance checklist
- [ ] Policy-as-code reviewed (compliance-policy.json)
- [ ] COMPLIANCE_URL secret configured in repo/Org
- [ ] Proof bundle updated and validated (docs/qh_r1_proof.template.json)
- [ ] Compliance preflight run locally (pnpm compliance:check)
- [ ] If distribution: CSV screened via compliance API
- [ ] No secrets committed (.env ignored)
- [ ] Mint policy time-lock plan documented

## Risk/Impact
- [ ] No change to on-chain policy
- [ ] No change to compliance gates

## Approvals
- [ ] Compliance
- [ ] Legal
