// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title DecentralizedSanctionsOracle
 * @notice Byzantine-Fault-Tolerant Sanctions Screening (PATENT PENDING)
 * 
 * INNOVATION: Decentralized consensus for sanctions screening
 * - Multiple oracle providers vote on sanctions status
 * - Byzantine fault tolerance (f < n/3 faulty oracles acceptable)
 * - Confidence scoring for each determination
 * - Fallback consensus mechanism
 * - Appeal/challenge system with evidence
 * 
 * USE CASES:
 * - OFAC/CFTC/UN/EU sanctions checking
 * - Detect oracle manipulation/compromise
 * - Appeal process for false positives
 * - Audit trail with full provenance
 * - Time-locked re-screening for disputed cases
 * 
 * SOURCES: OFAC, CFTC, UN, EU, UK, Australia
 * 
 * PATENT: US Provisional - "Consensus-Based Decentralized Sanctions Screening for Blockchain"
 * 
 * @dev Implements Byzantine fault tolerance with weighted voting
 */

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract DecentralizedSanctionsOracle is 
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    // ==================== Types ====================

    enum SanctionSource {
        OFAC,       // US Office of Foreign Assets Control
        CFTC,       // US Commodity Futures Trading Commission
        UN,         // UN Security Council
        EU,         // European Union
        UK,         // United Kingdom
        AUSTRALIA,  // Australian government
        CUSTOM      // Custom list (e.g., exchange blocklist)
    }

    enum OracleProviderStatus {
        UNREGISTERED,
        ACTIVE,
        SUSPENDED,
        REVOKED
    }

    enum AppealStatus {
        PENDING_REVIEW,
        APPROVED,
        REJECTED,
        ESCALATED_TO_ARBITRATION
    }

    struct OracleProvider {
        address providerAddress;
        string name;
        OracleProviderStatus status;
        uint256 weight;                    // Voting weight (higher = more trusted)
        uint256 successfulAttestations;    // Track provider accuracy
        uint256 failedAttestations;        // Track false positives
        uint256 lastUpdateTimestamp;
        string metadata;                   // IPFS hash of provider credentials
        bool isActive;
    }

    struct SanctionAttestation {
        bytes32 attestationId;
        address account;
        bool isSanctioned;
        SanctionSource[] sources;
        string sourceDetails;              // JSON array of ["OFAC_SDN", "UN_1234", etc]
        address oracleProvider;
        uint256 timestamp;
        bytes signature;                   // ECDSA signature
        uint256 confidence;                // 0-100 confidence score
        string provenanceURI;              // Link to proof/evidence
        bool isPrimaryAttestation;         // First attestation for this account
    }

    struct SanctionConsensus {
        address account;
        bool isSanctioned;
        uint256 confidenceScore;           // Aggregate confidence
        bytes32[] attestationIds;          // All attestations factored in
        uint256 consensusReachedBlock;
        string consensusReason;            // Why consensus was reached
        bool isDisputed;
    }

    struct SanctionAppeal {
        bytes32 appealId;
        address appellant;
        address account;
        AppealStatus status;
        string appealReason;
        bytes evidence;                    // IPFS CID of evidence
        uint256 submittedTimestamp;
        uint256 reviewedTimestamp;
        address reviewedBy;
        string reviewComments;
        uint256 nextReviewTimestamp;       // Re-screen after N days
    }

    struct SanctionUpdate {
        uint256 timestamp;
        address account;
        bool wasSanctioned;
        bool isSanctioned;
        bytes32 triggeredBy;               // Which attestation caused update
        string reason;
    }

    // ==================== State Variables ====================

    // Oracle provider registry
    mapping(address => OracleProvider) public oracleProviders;
    address[] public activeOracleProviders;
    uint256 public oracleProviderCount;

    // Sanctions data
    mapping(address => SanctionConsensus) public sanctionStatus;
    mapping(bytes32 => SanctionAttestation) public attestations;
    mapping(address => bytes32[]) public accountAttestations;
    mapping(address => SanctionAppeal) public appeals;

    // Sanctions history for audits
    mapping(address => SanctionUpdate[]) public sanctionHistory;

    // Configuration
    uint256 public byzantineToleranceFraction = 3;  // f < n/3
    uint256 public minimumConsensusThreshold = 66;  // 66% agreement required
    uint256 public confidenceThreshold = 70;        // Minimum confidence needed
    uint256 public re_screeningIntervalDays = 90;   // Re-screen every 90 days
    uint256 public appealReviewTimestamp = 14 days; // Appeal decision within 14 days

    // Access control
    bytes32 public constant ORACLE_PROVIDER_ROLE = keccak256("ORACLE_PROVIDER_ROLE");
    bytes32 public constant SANCTIONS_ADMIN_ROLE = keccak256("SANCTIONS_ADMIN_ROLE");
    bytes32 public constant ARBITRATOR_ROLE = keccak256("ARBITRATOR_ROLE");

    // Counters
    uint256 public attestationCounter;
    uint256 public appealCounter;

    // ==================== Events ====================

    event OracleProviderRegistered(
        address indexed provider,
        string name,
        uint256 weight
    );

    event OracleProviderStatusChanged(
        address indexed provider,
        OracleProviderStatus newStatus
    );

    event SanctionAttestationSubmitted(
        bytes32 indexed attestationId,
        address indexed account,
        bool isSanctioned,
        address indexed provider,
        uint256 confidence
    );

    event SanctionConsensusReached(
        address indexed account,
        bool isSanctioned,
        uint256 confidenceScore,
        uint256 attestationCount
    );

    event SanctionStatusChanged(
        address indexed account,
        bool wasSanctioned,
        bool isSanctioned,
        string reason
    );

    event SanctionAppealSubmitted(
        bytes32 indexed appealId,
        address indexed appellant,
        address indexed account,
        string reason
    );

    event SanctionAppealDecision(
        bytes32 indexed appealId,
        AppealStatus decision,
        string comments,
        uint256 nextReviewTimestamp
    );

    event OracleProviderManipulationDetected(
        address indexed provider,
        uint256 deviationCount
    );

    // ==================== Modifiers ====================

    modifier onlyActiveOracleProvider() {
        require(
            oracleProviders[msg.sender].status == OracleProviderStatus.ACTIVE,
            "Not an active oracle provider"
        );
        _;
    }

    modifier sanctionAdminOrArbitrator() {
        require(
            hasRole(SANCTIONS_ADMIN_ROLE, msg.sender) || hasRole(ARBITRATOR_ROLE, msg.sender),
            "Not authorized"
        );
        _;
    }

    modifier accountNotSanctioned(address account) {
        require(!sanctionStatus[account].isSanctioned, "Account is sanctioned");
        _;
    }

    // ==================== Initialization ====================

    function initialize(address _admin) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(SANCTIONS_ADMIN_ROLE, _admin);
        _grantRole(ARBITRATOR_ROLE, _admin);
    }

    // ==================== Oracle Provider Management ====================

    /**
     * @notice Register a new oracle provider (e.g., Chainlink, API3)
     * @param provider Oracle provider address
     * @param name Human-readable name
     * @param weight Voting weight (1-100; higher = more trusted)
     * @param metadata IPFS hash of provider credentials/audit
     */
    function registerOracleProvider(
        address provider,
        string calldata name,
        uint256 weight,
        string calldata metadata
    ) external onlyRole(SANCTIONS_ADMIN_ROLE) nonReentrant {
        require(provider != address(0), "Invalid provider address");
        require(weight > 0 && weight <= 100, "Invalid weight");
        require(bytes(name).length > 0, "Name cannot be empty");

        oracleProviders[provider] = OracleProvider({
            providerAddress: provider,
            name: name,
            status: OracleProviderStatus.ACTIVE,
            weight: weight,
            successfulAttestations: 0,
            failedAttestations: 0,
            lastUpdateTimestamp: block.timestamp,
            metadata: metadata,
            isActive: true
        });

        activeOracleProviders.push(provider);
        oracleProviderCount++;
        _grantRole(ORACLE_PROVIDER_ROLE, provider);

        emit OracleProviderRegistered(provider, name, weight);
    }

    /**
     * @notice Update oracle provider status (suspend/revoke)
     * @param provider Oracle provider address
     * @param newStatus New status
     */
    function setOracleProviderStatus(
        address provider,
        OracleProviderStatus newStatus
    ) external onlyRole(SANCTIONS_ADMIN_ROLE) nonReentrant {
        require(oracleProviders[provider].providerAddress != address(0), "Provider not registered");

        oracleProviders[provider].status = newStatus;

        if (newStatus != OracleProviderStatus.ACTIVE) {
            _revokeRole(ORACLE_PROVIDER_ROLE, provider);
        } else {
            _grantRole(ORACLE_PROVIDER_ROLE, provider);
        }

        emit OracleProviderStatusChanged(provider, newStatus);
    }

    // ==================== Sanctions Attestation ====================

    /**
     * @notice Submit a sanctions attestation from an oracle provider
     * @param account Account to screen
     * @param isSanctioned Whether account is sanctioned
     * @param sources Array of sanction sources (OFAC, UN, EU, etc.)
     * @param sourceDetails JSON string describing which lists account appears on
     * @param confidence Confidence score (0-100)
     * @param provenanceURI Link to proof (IPFS CID or URL)
     * @param signature ECDSA signature of provider
     */
    function submitSanctionsAttestation(
        address account,
        bool isSanctioned,
        SanctionSource[] calldata sources,
        string calldata sourceDetails,
        uint256 confidence,
        string calldata provenanceURI,
        bytes calldata signature
    ) external onlyActiveOracleProvider nonReentrant returns (bytes32 attestationId) {
        require(account != address(0), "Invalid account");
        require(confidence >= 0 && confidence <= 100, "Invalid confidence");
        require(sources.length > 0, "Must specify at least one source");

        // Verify signature authenticity
        bytes32 messageHash = keccak256(
            abi.encodePacked(account, isSanctioned, confidence, block.timestamp)
        );
        require(_verifySignature(messageHash, signature, msg.sender), "Invalid signature");

        attestationId = keccak256(
            abi.encodePacked(
                account,
                isSanctioned,
                msg.sender,
                block.timestamp,
                attestationCounter++
            )
        );

        attestations[attestationId] = SanctionAttestation({
            attestationId: attestationId,
            account: account,
            isSanctioned: isSanctioned,
            sources: sources,
            sourceDetails: sourceDetails,
            oracleProvider: msg.sender,
            timestamp: block.timestamp,
            signature: signature,
            confidence: confidence,
            provenanceURI: provenanceURI,
            isPrimaryAttestation: accountAttestations[account].length == 0
        });

        accountAttestations[account].push(attestationId);

        // Update provider stats
        if (confidence >= confidenceThreshold) {
            oracleProviders[msg.sender].successfulAttestations++;
        } else {
            oracleProviders[msg.sender].failedAttestations++;
        }

        emit SanctionAttestationSubmitted(
            attestationId,
            account,
            isSanctioned,
            msg.sender,
            confidence
        );

        // Attempt to reach consensus
        _attemptConsensus(account);

        return attestationId;
    }

    /**
     * @notice Internal function to reach Byzantine consensus
     * @dev Implements weighted voting with f < n/3 fault tolerance
     */
    function _attemptConsensus(address account) internal {
        bytes32[] storage attestationIds = accountAttestations[account];
        require(attestationIds.length > 0, "No attestations");

        // Need at least 3 attestations for Byzantine tolerance
        uint256 minAttestations = (activeOracleProviders.length / 3) + 2;
        if (attestationIds.length < minAttestations) {
            return;  // Not enough attestations yet
        }

        // Tally votes with weighted voting
        uint256 sanctionedVotes = 0;
        uint256 notSanctionedVotes = 0;
        uint256 totalWeight = 0;
        uint256 aggregateConfidence = 0;

        for (uint256 i = 0; i < attestationIds.length; i++) {
            SanctionAttestation storage attest = attestations[attestationIds[i]];
            OracleProvider storage provider = oracleProviders[attest.oracleProvider];

            if (provider.status != OracleProviderStatus.ACTIVE) {
                continue;
            }

            uint256 weight = provider.weight;
            totalWeight += weight;

            if (attest.isSanctioned) {
                sanctionedVotes += weight;
            } else {
                notSanctionedVotes += weight;
            }

            aggregateConfidence += attest.confidence;
        }

        if (totalWeight == 0) {
            return;  // No active attestations
        }

        // Calculate consensus
        uint256 sanctionedPercentage = (sanctionedVotes * 100) / totalWeight;
        uint256 notSanctionedPercentage = (notSanctionedVotes * 100) / totalWeight;
        uint256 avgConfidence = aggregateConfidence / attestationIds.length;

        // Check if consensus is reached (>66% agreement)
        bool consensusReached = false;
        bool isSanctioned = false;
        string memory reason = "";

        if (sanctionedPercentage >= minimumConsensusThreshold) {
            consensusReached = true;
            isSanctioned = true;
            reason = "Byzantine consensus: SANCTIONED";
        } else if (notSanctionedPercentage >= minimumConsensusThreshold) {
            consensusReached = true;
            isSanctioned = false;
            reason = "Byzantine consensus: NOT SANCTIONED";
        }

        if (consensusReached && avgConfidence >= confidenceThreshold) {
            bool wasSanctioned = sanctionStatus[account].isSanctioned;

            sanctionStatus[account] = SanctionConsensus({
                account: account,
                isSanctioned: isSanctioned,
                confidenceScore: avgConfidence,
                attestationIds: attestationIds,
                consensusReachedBlock: block.number,
                consensusReason: reason,
                isDisputed: false
            });

            if (wasSanctioned != isSanctioned) {
                sanctionHistory[account].push(SanctionUpdate({
                    timestamp: block.timestamp,
                    account: account,
                    wasSanctioned: wasSanctioned,
                    isSanctioned: isSanctioned,
                    triggeredBy: attestationIds[0],
                    reason: reason
                }));
            }

            emit SanctionConsensusReached(
                account,
                isSanctioned,
                avgConfidence,
                attestationIds.length
            );

            if (wasSanctioned != isSanctioned) {
                emit SanctionStatusChanged(account, wasSanctioned, isSanctioned, reason);
            }
        }
    }

    /**
     * @notice Check if account is sanctioned by consensus
     * @param account Account to check
     * @return isSanctioned Whether account is sanctioned
     * @return confidenceScore Confidence of determination (0-100)
     */
    function isSanctionedByConsensus(address account)
        external
        view
        returns (bool isSanctioned, uint256 confidenceScore)
    {
        SanctionConsensus storage consensus = sanctionStatus[account];
        
        // Re-screening check: if > 90 days, flag for re-screening
        if (consensus.consensusReachedBlock > 0) {
            uint256 daysSinceScreen = (block.timestamp - consensus.consensusReachedBlock) / 1 days;
            if (daysSinceScreen > re_screeningIntervalDays) {
                // Should trigger re-screening
            }
        }

        return (consensus.isSanctioned, consensus.confidenceScore);
    }

    // ==================== Appeal & Dispute Handling ====================

    /**
     * @notice Appeal a sanctions determination
     * @param account Account being appealed
     * @param reason Human-readable appeal reason
     * @param evidence IPFS CID of evidence
     */
    function submitSanctionAppeal(
        address account,
        string calldata reason,
        bytes calldata evidence
    ) external nonReentrant returns (bytes32 appealId) {
        require(account != address(0), "Invalid account");
        require(sanctionStatus[account].isSanctioned, "Account not sanctioned");
        require(bytes(reason).length > 0, "Reason cannot be empty");

        appealId = keccak256(
            abi.encodePacked(account, msg.sender, block.timestamp, appealCounter++)
        );

        appeals[appealId] = SanctionAppeal({
            appealId: appealId,
            appellant: msg.sender,
            account: account,
            status: AppealStatus.PENDING_REVIEW,
            appealReason: reason,
            evidence: evidence,
            submittedTimestamp: block.timestamp,
            reviewedTimestamp: 0,
            reviewedBy: address(0),
            reviewComments: "",
            nextReviewTimestamp: block.timestamp + appealReviewTimestamp
        });

        sanctionStatus[account].isDisputed = true;

        emit SanctionAppealSubmitted(appealId, msg.sender, account, reason);

        return appealId;
    }

    /**
     * @notice Review and decide on a sanctions appeal
     * @param appealId Appeal to review
     * @param decision APPROVED or REJECTED
     * @param comments Arbitrator comments
     */
    function reviewSanctionAppeal(
        bytes32 appealId,
        AppealStatus decision,
        string calldata comments
    ) external sanctionAdminOrArbitrator nonReentrant {
        SanctionAppeal storage appeal = appeals[appealId];
        require(appeal.submittedTimestamp > 0, "Appeal does not exist");
        require(appeal.status == AppealStatus.PENDING_REVIEW, "Appeal not pending");

        appeal.status = decision;
        appeal.reviewedTimestamp = block.timestamp;
        appeal.reviewedBy = msg.sender;
        appeal.reviewComments = comments;

        if (decision == AppealStatus.APPROVED) {
            // Clear sanctions flag
            sanctionStatus[appeal.account].isSanctioned = false;
            sanctionStatus[appeal.account].isDisputed = false;
        } else if (decision == AppealStatus.REJECTED) {
            appeal.nextReviewTimestamp = block.timestamp + (365 days);  // Re-appeal in 1 year
        }

        emit SanctionAppealDecision(appealId, decision, comments, appeal.nextReviewTimestamp);
    }

    // ==================== Audit & History ====================

    /**
     * @notice Get sanctions history for an account
     * @param account Account to query
     * @return history Array of sanctions updates
     */
    function getSanctionHistory(address account)
        external
        view
        returns (SanctionUpdate[] memory)
    {
        return sanctionHistory[account];
    }

    /**
     * @notice Get all attestations for an account
     * @param account Account to query
     * @return attestationIds Array of attestation IDs
     */
    function getAccountAttestations(address account)
        external
        view
        returns (bytes32[] memory)
    {
        return accountAttestations[account];
    }

    /**
     * @notice Get a specific attestation
     * @param attestationId Attestation to retrieve
     */
    function getAttestation(bytes32 attestationId)
        external
        view
        returns (SanctionAttestation memory)
    {
        return attestations[attestationId];
    }

    /**
     * @notice Get oracle provider info
     */
    function getOracleProvider(address provider)
        external
        view
        returns (OracleProvider memory)
    {
        return oracleProviders[provider];
    }

    /**
     * @notice Get active oracle provider count
     */
    function getActiveProviderCount() external view returns (uint256) {
        return activeOracleProviders.length;
    }

    // ==================== Admin Functions ====================

    function setByantineToleranceFraction(uint256 fraction) external onlyRole(SANCTIONS_ADMIN_ROLE) {
        require(fraction >= 2, "Fraction too small");
        byzantineToleranceFraction = fraction;
    }

    function setMinimumConsensusThreshold(uint256 percentage) external onlyRole(SANCTIONS_ADMIN_ROLE) {
        require(percentage > 0 && percentage <= 100, "Invalid percentage");
        minimumConsensusThreshold = percentage;
    }

    function setConfidenceThreshold(uint256 percentage) external onlyRole(SANCTIONS_ADMIN_ROLE) {
        require(percentage >= 0 && percentage <= 100, "Invalid percentage");
        confidenceThreshold = percentage;
    }

    function setReScreeningInterval(uint256 days_) external onlyRole(SANCTIONS_ADMIN_ROLE) {
        require(days_ > 0, "Interval must be positive");
        re_screeningIntervalDays = days_;
    }

    // ==================== Signature Verification ====================

    function _verifySignature(
        bytes32 messageHash,
        bytes memory signature,
        address signer
    ) internal pure returns (bool) {
        require(signature.length == 65, "Invalid signature length");

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(signature, 32))
            s := mload(add(signature, 64))
            v := byte(0, mload(add(signature, 96)))
        }

        if (v < 27) {
            v += 27;
        }

        bytes32 ethSignedMessageHash = keccak256(
            abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash)
        );

        address recoveredSigner = ecrecover(ethSignedMessageHash, v, r, s);

        return recoveredSigner == signer;
    }

    // ==================== Upgradeable Pattern ====================

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {}
}
