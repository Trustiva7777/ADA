{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}
-- (c) 2025 Unykorn Global Finance. All rights reserved.
module IGAR.Validator.ComplianceRef where

import PlutusLedgerApi.V2
import PlutusTx
import PlutusTx.Prelude
import IGAR.Types

{-# INLINABLE mkComplianceRef #-}
mkComplianceRef :: ComplianceDatum -> ()
mkComplianceRef _ = ()

mkValidator :: BuiltinData -> BuiltinData -> BuiltinData -> ()
mkValidator _datum _redeemer _ctx = ()

validator :: Validator
validator = mkValidatorScript $$(PlutusTx.compile [|| mkValidator ||])
