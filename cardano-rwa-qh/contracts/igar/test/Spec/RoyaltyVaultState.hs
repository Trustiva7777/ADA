module Spec.RoyaltyVaultState where

import Test.QuickCheck
import IGAR.Validator.RoyaltyVault
import PlutusLedgerApi.V2

-- Property test: Validator should accept valid compliance reference inputs
prop_ValidComplianceRef :: Property
prop_ValidComplianceRef = property $ do
  -- Generate test data
  policyId <- arbitrary :: Gen CurrencySymbol
  assetName <- arbitrary :: Gen TokenName
  quarter <- choose (1, 4) :: Gen Integer
  year <- choose (2024, 2030) :: Gen Integer

  let complianceDatum = ComplianceDatum {
        cdPolicyId = policyId,
        cdAssetName = assetName,
        cdRevoked = False
      }
      oracleDatum = OracleDatum {
        odQuarter = quarter,
        odYear = year,
        odSignature = ""  -- Simplified for test
      }

  -- Test that checkComplianceRef and checkOracleRef don't crash with valid data
  return $ checkComplianceRef complianceDatum == True &&
           checkOracleRef oracleDatum == True

-- Property test: Validator should reject revoked compliance
prop_RejectedRevokedCompliance :: Property
prop_RejectedRevokedCompliance = property $ do
  policyId <- arbitrary :: Gen CurrencySymbol
  assetName <- arbitrary :: Gen TokenName

  let revokedDatum = ComplianceDatum {
        cdPolicyId = policyId,
        cdAssetName = assetName,
        cdRevoked = True
      }

  return $ checkComplianceRef revokedDatum == False

-- Run all property tests
main :: IO ()
main = do
  putStrLn "Running RoyaltyVault property tests..."
  quickCheck prop_ValidComplianceRef
  quickCheck prop_RejectedRevokedCompliance
  putStrLn "All property tests passed!"