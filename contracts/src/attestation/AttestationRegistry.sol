// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.24;

/**
 * @title AttestationRegistry
 * @notice Quebrada Honda I & II Attestation Registry
 *
 * Immutable monthly production proofs:
 * - ROM (run-of-mine), grades, recoveries
 * - Concentrate assays, weights, moisture
 * - Shipment details (destination, date, bill of lading)
 * - Payment confirmations (smelter receipt, net value)
 * - QA/QC approvals (independent lab review)
 *
 * All data hashed (SHA-256) and anchored on-chain with IPFS CID.
 * Merkle tree for auditability and third-party verification.
 *
 * Patent-Pending: Production-Linked Proof-of-Reserves Registry
 *
 * Copyright © 2025 Trustiva / Quebrada Honda Project
 */

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";

// ============================================================================
// Structs
// ============================================================================

struct AttestationEntry {
    uint256 cycleId;
    string category; // "Production", "Shipment", "Payment", "QAQC"
    bytes32 dataHash; // SHA-256 of source file
    string ipfsCID; // IPFS content ID
    string s3Uri; // Alternative S3 URI
    address attestor; // Who submitted this entry
    bytes32 attestorSignature; // Digital signature (simplified)
    uint256 timestamp;
    bool isVerified; // Independent reviewer sign-off
}

struct MerkleNode {
    bytes32 hash;
    uint256[] children; // Indices of child nodes
}

struct CycleAttestation {
    uint256 cycleId;
    bytes32 merkleRoot; // Root of Merkle tree
    string[] categories; // Production, Shipment, Payment, QAQC
    bytes32[] categoryHashes; // Hash for each category
    address independentReviewer; // Third-party QP/engineer
    bool isApproved; // Full cycle approval
    uint256 approvedTimestamp;
}

// ============================================================================
// Events
// ============================================================================

event AttestationSubmitted(
    uint256 indexed cycleId,
    string indexed category,
    bytes32 indexed dataHash,
    string ipfsCID,
    address attestor,
    uint256 timestamp
);

event CycleVerified(
    uint256 indexed cycleId,
    bytes32 merkleRoot,
    address indexed reviewer,
    uint256 timestamp
);

event MerkleTreeBuilt(uint256 indexed cycleId, bytes32 merkleRoot);
event AttestationQueried(
    uint256 indexed cycleId,
    string category,
    bytes32 dataHash,
    uint256 retrievedAt
);

// ============================================================================
// Main Contract
// ============================================================================

contract AttestationRegistry is
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    // ========================================================================
    // Role Definitions
    // ========================================================================

    bytes32 public constant OWNER_ROLE = keccak256("OWNER_ROLE");
    bytes32 public constant ATTESTOR_ROLE = keccak256("ATTESTOR_ROLE");
    bytes32 public constant REVIEWER_ROLE = keccak256("REVIEWER_ROLE");

    // ========================================================================
    // State Variables
    // ========================================================================

    // All attestation entries (immutable)
    AttestationEntry[] public allEntries;

    // Entries by cycle
    mapping(uint256 => uint256[]) public entriesByCycle;

    // Cycle attestations (summary + approval)
    mapping(uint256 => CycleAttestation) public cycleAttestations;

    // Merkle trees (for audit proofs)
    mapping(uint256 => MerkleNode[]) public merkleTrees;

    // Attestor registrations
    mapping(address => bool) public isAttestor;
    mapping(address => string) public attestorDetails; // Name, role, credentials

    // Reviewer registrations
    mapping(address => bool) public isReviewer;
    mapping(address => string) public reviewerDetails;

    // ========================================================================
    // Initialization
    // ========================================================================

    function initialize(address admin) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(OWNER_ROLE, admin);
        _grantRole(ATTESTOR_ROLE, admin);
        _grantRole(REVIEWER_ROLE, admin);
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
    // Attestor Management
    // ========================================================================

    /**
     * @notice Register an attestor (operations team member, lab tech, etc.)
     */
    function registerAttestor(address attestor, string calldata details)
        external
        onlyRole(OWNER_ROLE)
    {
        require(attestor != address(0), "INVALID_ADDRESS");

        isAttestor[attestor] = true;
        attestorDetails[attestor] = details;
        _grantRole(ATTESTOR_ROLE, attestor);
    }

    /**
     * @notice Unregister an attestor
     */
    function unregisterAttestor(address attestor) external onlyRole(OWNER_ROLE) {
        isAttestor[attestor] = false;
        _revokeRole(ATTESTOR_ROLE, attestor);
    }

    /**
     * @notice Register a reviewer (independent QP/engineer)
     */
    function registerReviewer(address reviewer, string calldata credentials)
        external
        onlyRole(OWNER_ROLE)
    {
        require(reviewer != address(0), "INVALID_ADDRESS");

        isReviewer[reviewer] = true;
        reviewerDetails[reviewer] = credentials;
        _grantRole(REVIEWER_ROLE, reviewer);
    }

    /**
     * @notice Unregister a reviewer
     */
    function unregisterReviewer(address reviewer) external onlyRole(OWNER_ROLE) {
        isReviewer[reviewer] = false;
        _revokeRole(REVIEWER_ROLE, reviewer);
    }

    // ========================================================================
    // Attestation Submission
    // ========================================================================

    /**
     * @notice Submit attestation data (production, assays, shipments, payments)
     * @param cycleId Distribution cycle (e.g., 202410)
     * @param category Data category ("Production", "Shipment", "Payment", "QAQC")
     * @param dataHash SHA-256 hash of source CSV/PDF
     * @param ipfsCID IPFS content ID (for immutable storage)
     * @param s3Uri Alternative S3 URI (for availability)
     */
    function submitAttestation(
        uint256 cycleId,
        string calldata category,
        bytes32 dataHash,
        string calldata ipfsCID,
        string calldata s3Uri
    ) external onlyRole(ATTESTOR_ROLE) {
        require(cycleId > 0, "INVALID_CYCLE");
        require(dataHash != bytes32(0), "INVALID_HASH");
        require(bytes(ipfsCID).length > 0, "INVALID_CID");

        AttestationEntry memory entry = AttestationEntry(
            cycleId,
            category,
            dataHash,
            ipfsCID,
            s3Uri,
            _msgSender(),
            keccak256(abi.encode(_msgSender(), cycleId, dataHash)), // Simplified sig
            block.timestamp,
            false
        );

        allEntries.push(entry);
        uint256 entryIndex = allEntries.length - 1;

        entriesByCycle[cycleId].push(entryIndex);

        emit AttestationSubmitted(
            cycleId,
            category,
            dataHash,
            ipfsCID,
            _msgSender(),
            block.timestamp
        );
    }

    /**
     * @notice Batch submit multiple attestations (for monthly cycle)
     */
    function batchSubmitAttestations(
        uint256 cycleId,
        string[] calldata categories,
        bytes32[] calldata dataHashes,
        string[] calldata ipfsCIDs
    ) external onlyRole(ATTESTOR_ROLE) {
        require(
            categories.length == dataHashes.length &&
                dataHashes.length == ipfsCIDs.length,
            "LENGTH_MISMATCH"
        );

        for (uint256 i = 0; i < categories.length; i++) {
            submitAttestation(cycleId, categories[i], dataHashes[i], ipfsCIDs[i], "");
        }
    }

    // ========================================================================
    // Cycle Verification & Merkle Tree
    // ========================================================================

    /**
     * @notice Verify cycle attestations and build Merkle tree
     * @param cycleId Distribution cycle
     */
    function verifyCycle(uint256 cycleId) external onlyRole(REVIEWER_ROLE) {
        uint256[] memory indices = entriesByCycle[cycleId];
        require(indices.length > 0, "NO_ENTRIES");

        // Build Merkle tree from cycle entries
        MerkleNode[] storage tree = merkleTrees[cycleId];

        for (uint256 i = 0; i < indices.length; i++) {
            AttestationEntry storage entry = allEntries[indices[i]];

            // Add leaf node
            MerkleNode memory leaf = MerkleNode(entry.dataHash, new uint256[](0));
            tree.push(leaf);

            // Mark as verified
            entry.isVerified = true;
        }

        // Build tree upward (simplified; real implementation uses proper Merkle construction)
        bytes32 merkleRoot = _buildMerkleRoot(tree);

        // Record cycle attestation
        CycleAttestation storage cycleAtt = cycleAttestations[cycleId];
        cycleAtt.cycleId = cycleId;
        cycleAtt.merkleRoot = merkleRoot;
        cycleAtt.independentReviewer = _msgSender();
        cycleAtt.isApproved = true;
        cycleAtt.approvedTimestamp = block.timestamp;

        emit CycleVerified(cycleId, merkleRoot, _msgSender(), block.timestamp);
    }

    /**
     * @notice Internal: Build Merkle root from tree nodes
     */
    function _buildMerkleRoot(MerkleNode[] storage tree)
        internal
        view
        returns (bytes32)
    {
        if (tree.length == 0) return bytes32(0);
        if (tree.length == 1) return tree[0].hash;

        // Simplified: hash concatenation
        bytes32 root = tree[0].hash;
        for (uint256 i = 1; i < tree.length; i++) {
            root = keccak256(abi.encode(root, tree[i].hash));
        }

        return root;
    }

    // ========================================================================
    // Query & Verification
    // ========================================================================

    /**
     * @notice Get all entries for a cycle
     */
    function getEntriesByCycle(uint256 cycleId)
        external
        view
        returns (AttestationEntry[] memory)
    {
        uint256[] memory indices = entriesByCycle[cycleId];
        AttestationEntry[] memory entries = new AttestationEntry[](indices.length);

        for (uint256 i = 0; i < indices.length; i++) {
            entries[i] = allEntries[indices[i]];
        }

        return entries;
    }

    /**
     * @notice Get specific entry by index
     */
    function getEntry(uint256 index)
        external
        view
        returns (AttestationEntry memory)
    {
        require(index < allEntries.length, "INDEX_OUT_OF_BOUNDS");
        return allEntries[index];
    }

    /**
     * @notice Get cycle attestation summary
     */
    function getCycleAttestation(uint256 cycleId)
        external
        view
        returns (CycleAttestation memory)
    {
        return cycleAttestations[cycleId];
    }

    /**
     * @notice Verify Merkle proof for specific entry
     * @dev Simplified; real implementation uses full Merkle proof path
     */
    function verifyMerkleProof(uint256 cycleId, bytes32 dataHash)
        external
        view
        returns (bool)
    {
        uint256[] memory indices = entriesByCycle[cycleId];

        for (uint256 i = 0; i < indices.length; i++) {
            if (allEntries[indices[i]].dataHash == dataHash) {
                return allEntries[indices[i]].isVerified;
            }
        }

        return false;
    }

    /**
     * @notice Get total entry count
     */
    function getTotalEntries() external view returns (uint256) {
        return allEntries.length;
    }

    /**
     * @notice Get entry count for cycle
     */
    function getEntriesCountByCycle(uint256 cycleId)
        external
        view
        returns (uint256)
    {
        return entriesByCycle[cycleId].length;
    }

    /**
     * @notice Check if cycle is verified
     */
    function isCycleVerified(uint256 cycleId) external view returns (bool) {
        return cycleAttestations[cycleId].isApproved;
    }

    // ========================================================================
    // Audit Trail & Compliance
    // ========================================================================

    /**
     * @notice Export audit trail for external auditors
     */
    function exportAuditTrail(uint256 cycleId)
        external
        view
        returns (string memory)
    {
        // In production, this would serialize to JSON or similar format
        return "";
    }

    /**
     * @notice Generate compliance certificate (for NI 43-101 audits)
     */
    function generateComplianceCertificate(uint256 cycleId)
        external
        view
        returns (bytes memory)
    {
        CycleAttestation memory att = cycleAttestations[cycleId];
        require(att.isApproved, "CYCLE_NOT_APPROVED");

        // Return encoded certificate (simplified)
        return abi.encode(
            cycleId,
            att.merkleRoot,
            att.independentReviewer,
            att.approvedTimestamp
        );
    }
}
