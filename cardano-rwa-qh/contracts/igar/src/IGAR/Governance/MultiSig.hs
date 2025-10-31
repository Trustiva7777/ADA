{-# LANGUAGE NoImplicitPrelude #-}
-- (c) 2025 Unykorn Global Finance. All rights reserved.
module IGAR.Governance.MultiSig where

import PlutusLedgerApi.V2 (TxInfo, PubKeyHash, txInfoSignatories)
import PlutusTx.Prelude
import IGAR.Types

hasThreshold :: GovernanceParams -> TxInfo -> Bool
hasThreshold gp info =
  let sigs = txInfoSignatories info
      req  = gpSigners gp
      th   = gpThreshold gp
      hits = length (filter (\p -> any (\r -> r == p) req) sigs)
  in hits >= th
