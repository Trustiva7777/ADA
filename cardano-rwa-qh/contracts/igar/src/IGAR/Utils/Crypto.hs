{-# LANGUAGE NoImplicitPrelude #-}
-- (c) 2025 Unykorn Global Finance. All rights reserved.
module IGAR.Utils.Crypto where

import PlutusLedgerApi.V2 (PubKeyHash)
import PlutusTx.Prelude

-- Placeholder threshold check; replace with robust signature validation as needed
checkThreshold :: Integer -> [PubKeyHash] -> [PubKeyHash] -> Bool
checkThreshold threshold required present =
  let hits = length (filter (\pk -> any (\r -> r == pk) required) present)
  in  hits >= threshold
