param(
  [Parameter(Mandatory=$true)][string]$Plan,
  [Parameter(Mandatory=$false)][string]$Inputs,
  [Parameter(Mandatory=$true)][string]$Change,
  [Parameter(Mandatory=$true)][string]$SKey,
  [Parameter(Mandatory=$true)][string]$NetworkFlag,
  [string]$BeforeSlot,
  [string]$Out = "tx_batch_001",
  [string]$SubmitApi
)

$Unsigned = "$Out.unsigned"
$Signed   = "$Out.signed"
$Cbor     = "$Out.signed.cbor"
$Meta     = "$Out.metadata.json"

# 1) Metadata (label 674)
try {
  $metaObj = (& jq -n --argfile p $Plan '{ "674": { attestation: $p.meta.auxiliary.label_674.attestation, policy: $p.meta.auxiliary.label_674.policy }}')
  if (-not $metaObj) { throw "fallback" }
  $metaObj | Out-File -Encoding ascii $Meta
} catch {
  (& jq '{ "674": .auxiliary.label_674 }' $Plan) | Out-File -Encoding ascii $Meta
}

# 2) Inputs/Outputs
if ($Inputs -and (Test-Path $Inputs)) {
  $TxIns = (& jq -r '.inputs[] | "\(.txHash)#\(.index)"' $Inputs)
} else {
  $TxIns = (& jq -r '.inputs[] | "\(.txHash)#\(.index)"' $Plan)
}
$TxOuts = (& jq -r '.outputs[] | "\(.address)+\(.lovelace)"' $Plan)

if ($TxIns -match '<FILL-IN>') {
  Write-Error "Inputs contain <FILL-IN> placeholders. Provide --Inputs with filled hashes/indexes or edit the plan."; exit 2
}

# 3) Build
$build = @("transaction","build",$NetworkFlag,"--conway-era")
$build += $TxIns | ForEach-Object { "--tx-in",$_.ToString() }
$build += $TxOuts | ForEach-Object { "--tx-out",$_.ToString() }
$build += @("--change-address",$Change,"--metadata-json-file",$Meta,"--out-file",$Unsigned)
if ($BeforeSlot) { $build += @("--invalid-hereafter",$BeforeSlot) }

& cardano-cli $build

# 4) Sign
& cardano-cli transaction sign $NetworkFlag --tx-body-file $Unsigned --signing-key-file $SKey --out-file $Signed
Copy-Item $Signed $Cbor -Force

if ($SubmitApi) {
  curl -sS -X POST "$SubmitApi/api/tx/submit" -H 'Content-Type: application/cbor' --data-binary "@$Cbor"
}
