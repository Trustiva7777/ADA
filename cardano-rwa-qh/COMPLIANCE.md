# Regulatory Compliance Framework

This repository includes technical controls and checklists to help ensure every build and operation follows applicable rules and internal policies. It does not constitute legal advice.

Key pillars:
- Policy-as-code: `compliance-policy.json` defines guardrails per series.
- Automated gates: CLI tool `compliance-check` validates inputs and external services.
- Evidence: proof bundle JSON (NI 43-101, valuation, etc.) must be present and hashed.
- Separation of duties: approvals are codified in PR templates and CODEOWNERS.
- Auditability: logs and artifacts retained in repo or external archive.

## Responsibilities
- Legal/Compliance: Own jurisdictional mapping, exemptions (Reg D/Reg S), disclosures.
- Issuer Ops: Maintain proof bundles, payout ledgers, IPFS CIDs, time-lock plans.
- Engineering: Maintain policy-as-code, enforcement tools, CI gates.

## Policy-as-code
See `./compliance-policy.json` for a template. Customize per series:
- series: e.g., QH-R1
- allowedRegs: e.g., ["RegD", "RegS"]
- requireProof: true/false
- evidenceReportsMin: minimum number of reports
- decimals: min/max precision
- requireTimeLock: whether mint policy must be locked post-allocation
- allowJurisdictions / denyCountries: lists you maintain; use ISO-3166 codes

## Automated checks
Run the tool before any mint/distribution and in CI:
- Validates policy JSON shape and values
- Validates proof bundle structure (basic)
- Pings COMPLIANCE_URL and verifies it responds
- For distributions: checks every address via COMPLIANCE_URL
- Ensures ticker/series consistency and doc URI format (ipfs://)

Example:
```
pnpm exec tsx src/tools/compliance-check.ts \
  --series QH-R1 \
  --policy ./compliance-policy.json \
  --proof ./docs/qh_r1_proof.template.json \
  --action mint \
  --ticker QH-R1 \
  --decimals 2 \
  --doc ipfs://CID
```

## Process controls
- Use PR template checklist; require Compliance and Legal reviewers (CODEOWNERS)
- Keep `.env` out of version control and rotate keys routinely
- Run `compliance-check` in CI on every PR
- Lock policy after allocation; publish policy JSON + ID in the data room

## Jurisdictional caveat
Blockchain addresses alone do not determine user location or status. Use your compliance provider to enforce KYC/AML/PEP/sanctions/geo policies.
