{-# LANGUAGE DeriveAnyClass #-}
{-# LANGUAGE DeriveGeneric  #-}
{-# LANGUAGE DataKinds      #-}
{-# LANGUAGE NoImplicitPrelude #-}
{-# LANGUAGE TemplateHaskell #-}
-- (c) 2025 Unykorn Global Finance. All rights reserved.

module IGAR.Types where

import           GHC.Generics              (Generic)
import           PlutusLedgerApi.V2        (BuiltinByteString, PubKeyHash, CurrencySymbol, TokenName)
import           PlutusTx
import           PlutusTx.Prelude          hiding (Semigroup(..))

newtype ProofBundleHash = ProofBundleHash BuiltinByteString
  deriving stock (Generic)
PlutusTx.unstableMakeIsData ''ProofBundleHash
PlutusTx.makeLift ''ProofBundleHash

data GovernanceParams = GovernanceParams
  { gpSigners      :: [PubKeyHash]
  , gpThreshold    :: Integer
  , gpPauseEnabled :: Bool
  } deriving (Generic)
PlutusTx.unstableMakeIsData ''GovernanceParams
PlutusTx.makeLift ''GovernanceParams

data ComplianceDatum = ComplianceDatum
  { cdPolicyLocked    :: Bool
  , cdRevokedHolders  :: [PubKeyHash]
  , cdAllowlistSymbol :: CurrencySymbol
  } deriving (Generic)
PlutusTx.unstableMakeIsData ''ComplianceDatum
PlutusTx.makeLift ''ComplianceDatum

data OracleDatum = OracleDatum
  { odQuarterId   :: BuiltinByteString
  , odRecordSlot  :: Integer
  , odFxUsdPerAda :: Integer
  , odIssuerSig   :: BuiltinByteString
  } deriving (Generic)
PlutusTx.unstableMakeIsData ''OracleDatum
PlutusTx.makeLift ''OracleDatum

data RoyaltyParams = RoyaltyParams
  { rpSeriesPolicy    :: CurrencySymbol
  , rpSeriesAsset     :: TokenName
  , rpProofHash       :: ProofBundleHash
  , rpRoyaltyBps      :: Integer
  , rpBeforeSlot      :: Integer
  , rpPayoutFrequency :: Integer
  , rpGovernance      :: GovernanceParams
  } deriving (Generic)
PlutusTx.unstableMakeIsData ''RoyaltyParams
PlutusTx.makeLift ''RoyaltyParams

data VaultState = Init | Active | PayoutPending BuiltinByteString | Settled BuiltinByteString
  deriving (Generic)
PlutusTx.unstableMakeIsData ''VaultState
PlutusTx.makeLift ''VaultState

data VaultDatum = VaultDatum
  { vdParams :: RoyaltyParams
  , vdState  :: VaultState
  } deriving (Generic)
PlutusTx.unstableMakeIsData ''VaultDatum
PlutusTx.makeLift ''VaultDatum

data VaultAction = Activate | StartPayout BuiltinByteString | FinalizePayout BuiltinByteString | Pause | Unpause
  deriving (Generic)
PlutusTx.unstableMakeIsData ''VaultAction
PlutusTx.makeLift ''VaultAction
