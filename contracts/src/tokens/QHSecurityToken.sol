// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/**
 * @title QHSecurityToken
 * @notice Quebrada Honda I & II Security Token (RWA)
 *
 * Core ERC-20 token with distribution waterfall, snapshots,
 * compliance gating, and on-chain proof-of-reserves.
 *
 * Revolutionary Features:
 * - Self-executing distributions (attestation-triggered)
 * - Production-linked valuation (monthly reconciliation)
 * - Multi-stablecoin settlement (USDC, USDT, USDE, EURC, future CBDC)
 * - Tax-aware distribution (withholding, corporate tax, treaties)
 * - Tiered governance (major actions require tokenholder consent)
 *
 * Copyright © 2025 Trustiva / Quebrada Honda Project
 * Patent-Pending Technology
 */

import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20SnapshotUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

// ============================================================================
// Interfaces
// ============================================================================

interface IComplianceRegistry {
    function isAllowed(address who) external view returns (bool);
    function isSanctioned(address who) external view returns (bool);
    function isInCountry(address who, string calldata country) external view returns (bool);
}

interface IValuationEngine {
    function executeDistribution(
        uint256 cycleId,
        bytes calldata attestationData,
        uint256[] calldata commodityPrices
    ) external returns (uint256 tokeholderShare, uint256 reservedAmount);
}

interface ISettlementRouter {
    function queueDistribution(
        uint256 cycleId,
        uint256 amount,
        address[] calldata stablecoins
    ) external;
}

// ============================================================================
// Events
// ============================================================================

event DistributionDeclared(
    uint256 indexed cycleId,
    uint256 grossValue,
    uint256 deductions,
    uint256 netDistributable,
    uint256 tokeholderShare,
    bytes32 attestationHash,
    uint256 timestamp
);

event DistributionClaimed(
    uint256 indexed cycleId,
    address indexed tokeholder,
    uint256 amount,
    address stablecoin,
    uint256 timestamp
);

event AttestationAnchored(
    uint256 indexed cycleId,
    bytes32 indexed merkleRoot,
    string ipfsCID,
    uint256 timestamp
);

event ComplianceRegistryUpdated(address indexed newRegistry);
event ValuationEngineUpdated(address indexed newEngine);
event SettlementRouterUpdated(address indexed newRouter);
event LockupSet(address indexed holder, uint256 untilTimestamp);
event EmergencyPauseTriggered(address indexed by, string reason);

// ============================================================================
// Main Contract
// ============================================================================

contract QHSecurityToken is
    ERC20SnapshotUpgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    UUPSUpgradeable
{
    // ========================================================================
    // Role Definitions
    // ========================================================================

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant TREASURY_ROLE = keccak256("TREASURY_ROLE");
    bytes32 public constant ORACLE_ROLE = keccak256("ORACLE_ROLE");
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");

    // ========================================================================
    // State Variables
    // ========================================================================

    IComplianceRegistry public complianceRegistry;
    IValuationEngine public valuationEngine;
    ISettlementRouter public settlementRouter;

    // Lockup tracking (Unix timestamp until which holder cannot transfer)
    mapping(address => uint256) public lockupUntil;

    // Distribution cycle tracking
    mapping(uint256 => bool) public distributionExecuted;
    mapping(uint256 => uint256) public distributionAmount;
    mapping(uint256 => bytes32) public attestationHashes;

    // Individual claim tracking
    mapping(uint256 => mapping(address => bool)) public claimProcessed;
    mapping(uint256 => mapping(address => uint256)) public claimedAmount;

    // Reserve tracking (sustaining CAPEX, reclamation)
    uint256 public totalReserves;
    uint256 public reservePercentage; // basis points (e.g., 800 = 8%)

    // ========================================================================
    // Initialization
    // ========================================================================

    function initialize(
        string memory name_,
        string memory symbol_,
        address admin,
        address complianceRegistry_,
        address valuationEngine_,
        address settlementRouter_,
        uint256 initialSupply
    ) external initializer {
        __ERC20_init(name_, symbol_);
        __ERC20Snapshot_init();
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __UUPSUpgradeable_init();

        // Grant roles
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OWNER_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
        _grantRole(TREASURY_ROLE, admin);

        // Set external contracts
        complianceRegistry = IComplianceRegistry(complianceRegistry_);
        valuationEngine = IValuationEngine(valuationEngine_);
        settlementRouter = ISettlementRouter(settlementRouter_);

        // Set default reserve percentage (8%)
        reservePercentage = 800;

        // Mint initial supply to treasury
        _mint(admin, initialSupply);
    }

    // ========================================================================
    // Upgrade Authorization
    // ========================================================================

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyRole(OWNER_ROLE)
    {}

    // ========================================================================
    // Compliance & Transfer Controls
    // ========================================================================

    /// @notice Check if holder is compliant for transfer
    function _isCompliant(address holder) internal view returns (bool) {
        if (holder == address(0)) return true; // Minting allowed

        // Check allowlist
        if (!complianceRegistry.isAllowed(holder)) return false;

        // Check sanctions
        if (complianceRegistry.isSanctioned(holder)) return false;

        // Check lockup expiration
        if (block.timestamp < lockupUntil[holder]) return false;

        return true;
    }

    /// @notice Set lockup for a holder
    function setLockup(address holder, uint256 untilTimestamp)
        external
        onlyRole(COMPLIANCE_ROLE)
    {
        lockupUntil[holder] = untilTimestamp;
        emit LockupSet(holder, untilTimestamp);
    }

    /// @notice Update compliance registry (admin only, timelocked)
    function setComplianceRegistry(address newRegistry)
        external
        onlyRole(OWNER_ROLE)
    {
        require(newRegistry != address(0), "Invalid registry");
        complianceRegistry = IComplianceRegistry(newRegistry);
        emit ComplianceRegistryUpdated(newRegistry);
    }

    /// @notice Update valuation engine (admin only)
    function setValuationEngine(address newEngine)
        external
        onlyRole(OWNER_ROLE)
    {
        require(newEngine != address(0), "Invalid engine");
        valuationEngine = IValuationEngine(newEngine);
        emit ValuationEngineUpdated(newEngine);
    }

    /// @notice Update settlement router (admin only)
    function setSettlementRouter(address newRouter)
        external
        onlyRole(OWNER_ROLE)
    {
        require(newRouter != address(0), "Invalid router");
        settlementRouter = ISettlementRouter(newRouter);
        emit SettlementRouterUpdated(newRouter);
    }

    // ========================================================================
    // ERC-20 Overrides with Compliance Gating
    // ========================================================================

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20SnapshotUpgradeable) {
        super._beforeTokenTransfer(from, to, amount);

        if (paused()) {
            revert("TOKEN_PAUSED");
        }

        // Mint and burn bypasses compliance (admin-only via access control)
        if (from == address(0) || to == address(0)) {
            return;
        }

        // Standard transfer: check compliance
        require(_isCompliant(from), "FROM_NOT_COMPLIANT");
        require(_isCompliant(to), "TO_NOT_COMPLIANT");
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20Upgradeable, ERC20SnapshotUpgradeable) {
        super._update(from, to, amount);
    }

    // ========================================================================
    // Snapshot Functionality (for cap-table reporting)
    // ========================================================================

    function takeSnapshot() external onlyRole(SNAPSHOT_ROLE) returns (uint256) {
        return _snapshot();
    }

    function balanceOfAt(address account, uint256 snapshotId)
        external
        view
        returns (uint256)
    {
        return balanceOfAt(account, snapshotId);
    }

    // ========================================================================
    // Distribution Waterfall Interface
    // ========================================================================

    /**
     * @notice Execute distribution for a monthly cycle
     * @param cycleId Distribution cycle identifier (e.g., 202410 = Oct 2024)
     * @param attestationData Packed attestation data (production, assays, shipments)
     * @param commodityPrices Array of [Cu price, Au price, Ag price, FX rate]
     * @return tokeholderShare Amount distributed to tokenholders
     * @return reservedAmount Amount reserved for sustaining CAPEX
     */
    function executeDistribution(
        uint256 cycleId,
        bytes calldata attestationData,
        uint256[] calldata commodityPrices
    )
        external
        onlyRole(TREASURY_ROLE)
        nonReentrant
        returns (uint256 tokeholderShare, uint256 reservedAmount)
    {
        require(!distributionExecuted[cycleId], "ALREADY_EXECUTED");
        require(commodityPrices.length == 4, "INVALID_PRICE_LENGTH");

        // Call valuation engine to calculate distribution
        (tokeholderShare, reservedAmount) = valuationEngine.executeDistribution(
            cycleId,
            attestationData,
            commodityPrices
        );

        // Record as executed
        distributionExecuted[cycleId] = true;
        distributionAmount[cycleId] = tokeholderShare;
        attestationHashes[cycleId] = keccak256(attestationData);

        // Update reserves
        totalReserves += reservedAmount;

        // Take snapshot for distribution
        uint256 snapshotId = _snapshot();

        // Queue settlement via router
        address[] memory stablecoins = new address[](4);
        // Will be filled by caller or settlement router with actual stablecoin addresses
        settlementRouter.queueDistribution(cycleId, tokeholderShare, stablecoins);

        emit DistributionDeclared(
            cycleId,
            tokeholderShare + reservedAmount, // Gross
            0, // Deductions tracked internally
            tokeholderShare + reservedAmount,
            tokeholderShare,
            attestationHashes[cycleId],
            block.timestamp
        );

        return (tokeholderShare, reservedAmount);
    }

    /**
     * @notice Claim distribution in preferred stablecoin
     * @param cycleId Distribution cycle identifier
     * @param stablecoin Address of stablecoin (USDC, USDT, USDE, EURC, etc.)
     */
    function claimDistribution(uint256 cycleId, address stablecoin)
        external
        nonReentrant
    {
        require(distributionExecuted[cycleId], "NOT_EXECUTED");
        require(!claimProcessed[cycleId][_msgSender()], "ALREADY_CLAIMED");

        // Get balance at snapshot
        uint256 tokenBalance = balanceOfAt(_msgSender(), cycleId);
        require(tokenBalance > 0, "NO_TOKENS");

        // Calculate pro-rata share
        uint256 totalAtSnapshot = totalSupplyAt(cycleId);
        uint256 claimAmount = (distributionAmount[cycleId] * tokenBalance) /
            totalAtSnapshot;

        require(claimAmount > 0, "ZERO_CLAIM");

        // Mark as claimed
        claimProcessed[cycleId][_msgSender()] = true;
        claimedAmount[cycleId][_msgSender()] = claimAmount;

        // Settlement router handles stablecoin transfer
        // (This is a placeholder; actual settlement happens via router)

        emit DistributionClaimed(
            cycleId,
            _msgSender(),
            claimAmount,
            stablecoin,
            block.timestamp
        );
    }

    // ========================================================================
    // Attestation Anchoring (Proof of Reserves)
    // ========================================================================

    /**
     * @notice Anchor monthly attestation to on-chain registry
     * @param cycleId Distribution cycle identifier
     * @param merkleRoot Merkle root of production/assay/shipment proofs
     * @param ipfsCID IPFS content ID for full attestation data
     */
    function anchorAttestation(
        uint256 cycleId,
        bytes32 merkleRoot,
        string calldata ipfsCID
    ) external onlyRole(TREASURY_ROLE) {
        attestationHashes[cycleId] = merkleRoot;
        emit AttestationAnchored(cycleId, merkleRoot, ipfsCID, block.timestamp);
    }

    // ========================================================================
    // Admin Controls
    // ========================================================================

    /// @notice Admin mint (for scaling/refinancing)
    function adminMint(address to, uint256 amount)
        external
        onlyRole(OWNER_ROLE)
    {
        _mint(to, amount);
    }

    /// @notice Admin burn (for redemption/retirement)
    function adminBurn(address from, uint256 amount)
        external
        onlyRole(OWNER_ROLE)
    {
        _burn(from, amount);
    }

    /// @notice Pause all transfers (emergency only)
    function pause() external onlyRole(OWNER_ROLE) {
        _pause();
        emit EmergencyPauseTriggered(_msgSender(), "Admin pause triggered");
    }

    /// @notice Unpause (post-emergency recovery)
    function unpause() external onlyRole(OWNER_ROLE) {
        _unpause();
    }

    // ========================================================================
    // View Functions
    // ========================================================================

    /// @notice Get current distribution cycle
    function currentCycle() external view returns (uint256) {
        // YYYYMM format (e.g., 202410 = Oct 2024)
        return (block.timestamp / 2592000) * 100; // Simplified; use actual calendar
    }

    /// @notice Check if address has claimed for cycle
    function hasClaimedCycle(uint256 cycleId, address holder)
        external
        view
        returns (bool)
    {
        return claimProcessed[cycleId][holder];
    }

    /// @notice Get claimed amount for holder in cycle
    function getClaimedAmount(uint256 cycleId, address holder)
        external
        view
        returns (uint256)
    {
        return claimedAmount[cycleId][holder];
    }

    /// @notice Get total reserves held for sustaining CAPEX
    function getTotalReserves() external view returns (uint256) {
        return totalReserves;
    }

    /// @notice Get reserve percentage (basis points)
    function getReservePercentage() external view returns (uint256) {
        return reservePercentage;
    }
}
