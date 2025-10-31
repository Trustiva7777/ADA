# Signer steps (offline, air-gapped)
# 1) Have on signer:
#    - policy.script.json  (and the matching policy.skey)
#    - inputs.template.json  (fill UTxOs)
#    - mint_unsigned.plan.json (this file)
# 2) Build body (example using cardano-cli; adjust paths):
cardano-cli transaction build-raw \
  --alonzo-era \
  --fee 0 \
  --tx-in <TXHASH>#<IX> \
  --tx-out addr_test1qplchng3+<CHANGE_LOVELACE> \
  --mint="1000000 TESTPOLICY.51482d5231" \
  --minting-script-file policy.script.json \
  --metadata-json-file metadata.json \
  --out-file mint.body

# 3) Create metadata.json for label 674:
cat > metadata.json <<EOF
{
  "674": {
    "attestation": "rwa-suite/chains/cardano/docs/token/attestation.Preprod.json",
    "doc": "ipfs://TESTCID",
    "decimals": 2,
    "name": "QH-R1"
  }
}
EOF

# 4) Calculate fee & adjust outputs (recommended to use build instead of build-raw in practice)
#    Or rebuild with `transaction build` using --testnet-magic 1 and --change-address

# 5) Sign:
cardano-cli transaction sign \
  --testnet-magic 1 \
  --tx-body-file mint.body \
  --signing-key-file policy.skey \
  --out-file mint.signed

# 6) Submit (on relay host):
curl -sS -X POST "$SUBMIT_API/api/tx/submit" -H 'Content-Type: application/cbor' --data-binary @mint.signed
