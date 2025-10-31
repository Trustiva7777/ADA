{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}
-- (c) 2025 Unykorn Global Finance. All rights reserved.
module IGAR.Policy.SeriesToken (mkPolicy) where

import PlutusLedgerApi.V2
import PlutusTx
import PlutusTx.Prelude

newtype SeriesRedeemer = SeriesRedeemer BuiltinByteString
PlutusTx.unstableMakeIsData ''SeriesRedeemer

{-# INLINABLE policy #-}
policy :: Integer -> (BuiltinData -> BuiltinData -> ())
policy beforeSlot _redeemer _ctx =
  let ctx  = unsafeFromBuiltinData @ScriptContext _ctx
      info = scriptContextTxInfo ctx
   in if contains (to (POSIXTime beforeSlot)) (txInfoValidRange info)
        then ()
        else traceError "MINT_AFTER_LOCK"

mkPolicy :: Integer -> Script
mkPolicy slot = mkMintingPolicyScript $ $$(PlutusTx.compile [|| policy ||]) `PlutusTx.applyCode` PlutusTx.liftCode slot
