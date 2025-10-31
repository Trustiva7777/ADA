{-# LANGUAGE NoImplicitPrelude #-}
-- (c) 2025 Unykorn Global Finance. All rights reserved.
module IGAR.Utils.DatumCodec where

import PlutusLedgerApi.V2
import PlutusTx.Prelude

{-# INLINE fromDatum #-}
fromDatum :: (UnsafeFromData a) => Datum -> a
fromDatum (Datum d) = unsafeFromBuiltinData d
