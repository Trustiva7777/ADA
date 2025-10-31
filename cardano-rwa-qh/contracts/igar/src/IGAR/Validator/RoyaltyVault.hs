{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}
-- (c) 2025 Unykorn Global Finance. All rights reserved.
module IGAR.Validator.RoyaltyVault (validator) where

import PlutusLedgerApi.V2
import PlutusTx
import PlutusTx.Prelude
import IGAR.Types
import IGAR.Governance.MultiSig (hasThreshold)

{-# INLINABLE checkComplianceRef #-}
checkComplianceRef :: TxInfo -> Bool
checkComplianceRef info =
  case findRefInput info of
    Just datum -> not (cdPolicyLocked datum) && null (cdRevokedHolders datum)
    Nothing    -> False
  where
    findRefInput :: TxInfo -> Maybe ComplianceDatum
    findRefInput txInfo = do
      let refInputs = txInfoReferenceInputs txInfo
      -- Find the first reference input with ComplianceDatum
      case filter (\ri -> case txOutDatum (txInInfoResolved ri) of
                           OutputDatum (Datum d) -> case fromBuiltinData d of
                                                     Just cd -> True
                                                     Nothing -> False
                           _ -> False) refInputs of
        (ri:_) -> case txOutDatum (txInInfoResolved ri) of
                   OutputDatum (Datum d) -> fromBuiltinData d
                   _ -> Nothing
        [] -> Nothing

{-# INLINABLE checkOracleRef #-}
checkOracleRef :: TxInfo -> BuiltinByteString -> Bool
checkOracleRef info quarterId =
  case findOracleRef info of
    Just datum -> odQuarterId datum == quarterId && lengthOfByteString (odIssuerSig datum) > 0
    Nothing    -> False
  where
    findOracleRef :: TxInfo -> Maybe OracleDatum
    findOracleRef txInfo = do
      let refInputs = txInfoReferenceInputs txInfo
      -- Find the first reference input with OracleDatum
      case filter (\ri -> case txOutDatum (txInInfoResolved ri) of
                           OutputDatum (Datum d) -> case fromBuiltinData d of
                                                     Just od -> True
                                                     Nothing -> False
                           _ -> False) refInputs of
        (ri:_) -> case txOutDatum (txInInfoResolved ri) of
                   OutputDatum (Datum d) -> fromBuiltinData d
                   _ -> Nothing
        [] -> Nothing

{-# INLINABLE mkValidator #-}
mkValidator :: VaultDatum -> VaultAction -> ScriptContext -> Bool
mkValidator datum action ctx =
  let info       = scriptContextTxInfo ctx
      params     = vdParams datum
      govOK      = hasThreshold (rpGovernance params) info
      compOK     = checkComplianceRef info
      _beforeLock = contains (to (POSIXTime (rpBeforeSlot params))) (txInfoValidRange info)
  in case (vdState datum, action) of
      (Init, Activate)                     -> traceIfFalse "GOV" govOK && traceIfFalse "COMP" compOK
      (Active, StartPayout q)              -> traceIfFalse "GOV" govOK && traceIfFalse "COMP" compOK && traceIfFalse "ORACLE" (checkOracleRef info q)
      (PayoutPending q, FinalizePayout q2) -> traceIfFalse "GOV" govOK && traceIfFalse "COMP" compOK && traceIfFalse "QID" (q == q2)
      (_, Pause)                           -> traceIfFalse "GOV" govOK
      (_, Unpause)                         -> traceIfFalse "GOV" govOK

validator :: Validator
validator = mkValidatorScript $$(PlutusTx.compile [|| wrap ||])
  where
    wrap = mkUntypedValidator mkValidator

{-# INLINABLE mkUntypedValidator #-}
mkUntypedValidator :: (UnsafeFromData d, UnsafeFromData r)
                   => (d -> r -> ScriptContext -> Bool)
                   -> BuiltinData -> BuiltinData -> BuiltinData -> ()
mkUntypedValidator f d r c = if f (unsafeFromBuiltinData d) (unsafeFromBuiltinData r) (unsafeFromBuiltinData c)
                              then () else traceError "INVALID"
