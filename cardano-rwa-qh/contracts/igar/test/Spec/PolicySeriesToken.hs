module Spec.PolicySeriesToken where

import Spec.RoyaltyVaultState
import Spec.Governance
import Spec.NegativePaths

-- Main test runner for all IGAR contract tests
main :: IO ()
main = do
  putStrLn "Running IGAR contract test suite..."
  putStrLn ""

  putStrLn "1. Testing RoyaltyVault validator..."
  Spec.RoyaltyVaultState.main
  putStrLn ""

  putStrLn "2. Testing Governance contracts..."
  Spec.Governance.main
  putStrLn ""

  putStrLn "3. Testing Negative paths..."
  Spec.NegativePaths.main
  putStrLn ""

  putStrLn "All IGAR contract tests completed!"
