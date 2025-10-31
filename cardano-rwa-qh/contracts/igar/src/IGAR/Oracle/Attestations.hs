{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}
-- (c) 2025 Unykorn Global Finance. All rights reserved.
module IGAR.Oracle.Attestations where

import PlutusLedgerApi.V2
import PlutusTx
import PlutusTx.Prelude
import IGAR.Types

{-# INLINABLE mkOracleRef #-}
mkOracleRef :: OracleDatum -> ()
mkOracleRef _ = ()

mkValidator :: BuiltinData -> BuiltinData -> BuiltinData -> ()
mkValidator _ _ _ = ()

validator :: Validator
validator = mkValidatorScript $$(PlutusTx.compile [|| mkValidator ||])
