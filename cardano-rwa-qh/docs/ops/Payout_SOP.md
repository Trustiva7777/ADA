# Quarterly Royalty Payout SOP — QH-R1

1) **Compute Net Revenue** (per term sheet) by product and month; aggregate to quarter.  
2) **Royalty Due** = Royalty % × Net Revenue.  
3) **Snapshot holders** on record date:

```
pnpm snapshot -- --policy <POLICY_ID> --asset 51482d5231
```

4) Build `payout_plan.csv`:
`wallet_address,tokens_held,pro_rata_share,payout_amount_usd`

5) **Plan** off-chain payouts (USDC/fiat):  

```
pnpm distribute -- --csv ./docs/qh_r1_payouts_template.csv --mode plan
```

6) **Execute** payouts (bank/USDC). Collect receipts/txids.  
7) Publish **proofs** under `/docs/reports/quarterly-YYYYQX/` (snapshot, plan, receipts).
