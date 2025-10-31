#!/usr/bin/env bash
set -euo pipefail

# Usage:
#  build_sign_submit.sh \
#    --plan tx_batch_001.json \
#    --inputs tx_batch_001.inputs.template.json \
#    --change <TREASURY_RETURN_ADDRESS> \
#    --skey payment.skey \
#    --network-flag "--testnet-magic 1" | "--mainnet" \
#    [--before-slot N] [--out tx_batch_001] [--submit-api http://localhost:8090]

PLAN=""
INPUTS=""
CHANGE_ADDR=""
SKEY=""
NETWORK_FLAG=""
BEFORE_SLOT=""
OUT="tx_batch_001"
SUBMIT_API=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plan) PLAN="$2"; shift 2;;
    --inputs) INPUTS="$2"; shift 2;;
    --change) CHANGE_ADDR="$2"; shift 2;;
    --skey) SKEY="$2"; shift 2;;
    --network-flag) NETWORK_FLAG="$2"; shift 2;;
    --before-slot) BEFORE_SLOT="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    --submit-api) SUBMIT_API="$2"; shift 2;;
    *) echo "Unknown arg: $1" >&2; exit 2;;
  esac
done

[[ -n "$PLAN" && -n "$CHANGE_ADDR" && -n "$SKEY" && -n "$NETWORK_FLAG" ]] || {
  echo "Missing required args. See header for usage." >&2; exit 2;
}

# Derive file names
UNSIGNED="$OUT.unsigned"
SIGNED="$OUT.signed"
CBOR="$OUT.signed.cbor"
META="$OUT.metadata.json"

jq --version >/dev/null 2>&1 || { echo "jq is required on signer host" >&2; exit 2; }
command -v cardano-cli >/dev/null 2>&1 || { echo "cardano-cli not found in PATH" >&2; exit 2; }

# 1) Metadata (label 674)
# Prefer plan.meta.auxiliary.label_674; fallback to plan.auxiliary.label_674
if ! jq -e '.meta.auxiliary.label_674 // empty' "$PLAN" >/dev/null; then
  jq -r '.auxiliary.label_674 // {}' "$PLAN" | jq '{ "674": . }' > "$META"
else
  jq -n --argfile p "$PLAN" '{ "674": { attestation: $p.meta.auxiliary.label_674.attestation, policy: $p.meta.auxiliary.label_674.policy } }' > "$META"
fi

# 2) Inputs/Outputs
# Prefer INPUTS file if provided and exists; otherwise read from PLAN
if [[ -n "$INPUTS" && -f "$INPUTS" ]]; then
  mapfile -t TX_INS < <(jq -r '.inputs[] | "\(.txHash)#\(.index)"' "$INPUTS")
else
  mapfile -t TX_INS < <(jq -r '.inputs[] | "\(.txHash)#\(.index)"' "$PLAN")
fi
mapfile -t TX_OUTS < <(jq -r '.outputs[] | "\(.address)+\(.lovelace)"' "$PLAN")

# Basic validation for placeholders
if printf '%s\n' "${TX_INS[@]}" | grep -q "<FILL-IN>"; then
  echo "Inputs contain <FILL-IN> placeholders. Provide --inputs with filled hashes/indexes or edit the plan." >&2; exit 2;
fi

# 3) Build (auto fee; default Conway era)
BUILD_ARGS=(transaction build $NETWORK_FLAG --conway-era)
for tin in "${TX_INS[@]}"; do BUILD_ARGS+=(--tx-in "$tin"); done
for tout in "${TX_OUTS[@]}"; do BUILD_ARGS+=(--tx-out "$tout"); done
BUILD_ARGS+=(--change-address "$CHANGE_ADDR" --metadata-json-file "$META" --out-file "$UNSIGNED")

if [[ -n "$BEFORE_SLOT" ]]; then
  BUILD_ARGS+=(--invalid-hereafter "$BEFORE_SLOT")
fi

echo "+ cardano-cli ${BUILD_ARGS[*]}"
cardano-cli "${BUILD_ARGS[@]}"

# 4) Sign
cardano-cli transaction sign $NETWORK_FLAG \
  --tx-body-file "$UNSIGNED" \
  --signing-key-file "$SKEY" \
  --out-file "$SIGNED"

# 5) Normalize to CBOR
if [[ "${SIGNED##*.}" == "cbor" ]]; then
  cp "$SIGNED" "$CBOR"
else
  cp "$SIGNED" "$CBOR"
fi

echo "Built & signed:"
echo "  Body : $UNSIGNED"
echo "  Signed: $SIGNED"
echo "  CBOR : $CBOR"

# 6) Optional submit via submit-api
if [[ -n "$SUBMIT_API" ]]; then
  echo "+ curl -X POST $SUBMIT_API/api/tx/submit ..."
  curl -sS -X POST "$SUBMIT_API/api/tx/submit" \
    -H 'Content-Type: application/cbor' \
    --data-binary "@${CBOR}"
  echo
fi
