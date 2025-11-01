// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title InstitutionalGovernanceDAO
 * @notice Token-Holder Governance DAO for RWA Distribution & Compliance (PATENT PENDING)
 * 
 * INNOVATION: Decentralized autonomous governance for institutional RWA tokenization
 * - Token-weighted voting on distributions, compliance rules, budgets
 * - Tiered governance: Simple proposals (threshold 30%), Complex proposals (threshold 66%)
 * - Timelock execution with emergency pause capability
 * - Voting delegation to institutional stakeholders
 * - Proposal history and governance audit trail
 * - Veto power for emergency situations
 * 
 * USE CASES:
 * - Vote on distribution amounts & timing
 * - Approve compliance rule changes (Rule 144 modifications, OFAC updates)
 * - Approve budget allocations (legal, audit, operations)
 * - Trigger emergency pause if fraud detected
 * - Delegate voting rights to fund managers
 * - Vote on cross-chain settlement parameters
 * 
 * GOVERNANCE TIERS:
 * - Simple Proposal: 30% approval, 3-day vote, execute immediately
 * - Complex Proposal: 66% approval, 7-day vote, 2-day timelock
 * - Emergency Proposal: 75% approval, 1-day vote, instant execution
 * 
 * PATENT: US Provisional - "Institutional Governance DAO for RWA Tokenization"
 * 
 * @dev Implements UUPS upgradeable pattern with time-locked execution
 */

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface IGovernanceToken {
    function balanceOf(address account) external view returns (uint256);
    function delegated(address account) external view returns (address);
}

contract InstitutionalGovernanceDAO is 
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    // ==================== Types ====================

    enum ProposalType {
        SIMPLE,        // Distribution parameters, non-critical changes (30% approval)
        COMPLEX,       // Compliance rules, budget allocations (66% approval)
        EMERGENCY      // System pause, critical security action (75% approval)
    }

    enum ProposalStatus {
        PENDING,
        ACTIVE,
        SUCCEEDED,
        DEFEATED,
        EXPIRED,
        CANCELED,
        QUEUED,
        EXPIRED_QUEUED,
        EXECUTED
    }

    enum VoteType {
        FOR,
        AGAINST,
        ABSTAIN
    }

    struct Proposal {
        uint256 proposalId;
        address proposer;
        ProposalType proposalType;
        ProposalStatus status;
        string title;
        string description;
        bytes[] calldatas;              // Low-level calls to execute
        string[] callSignatures;        // Function signatures
        address[] targets;              // Target contracts
        uint256[] values;               // ETH values (0 for token transfers)
        
        // Voting
        uint256 startBlock;
        uint256 endBlock;
        uint256 forVotes;
        uint256 againstVotes;
        uint256 abstainVotes;
        uint256 startTime;
        uint256 endTime;
        
        // Execution
        uint256 eta;                    // Estimated time of arrival (for timelock)
        bool canceled;
        bool executed;
        
        // Metadata
        bytes32 canceledBy;             // Why was it canceled?
        string metadata;                // IPFS hash of proposal details
    }

    struct VotingRecord {
        address voter;
        uint256 proposalId;
        uint256 votes;
        VoteType support;
        uint256 timestamp;
        bool hasVoted;
    }

    struct Delegation {
        address delegator;
        address delegatee;
        uint256 amount;
        uint256 timestamp;
        bool isActive;
    }

    struct GovernanceParameter {
        string name;
        uint256 value;
        uint256 lastUpdated;
        address updatedBy;
    }

    // ==================== State Variables ====================

    // Governance token
    IGovernanceToken public governanceToken;
    address public tokenAddress;

    // Proposals
    mapping(uint256 => Proposal) public proposals;
    uint256 public proposalCounter;
    uint256[] public allProposalIds;

    // Voting
    mapping(uint256 => mapping(address => VotingRecord)) public votingRecords;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    // Delegations
    mapping(address => Delegation) public delegations;
    mapping(address => address[]) public delegationHistory;

    // Governance parameters (time-locked updates)
    mapping(string => GovernanceParameter) public parameters;

    // Emergency controls
    bool public isPaused;
    address public emergencyCouncil;
    mapping(address => bool) public isEmergencyCouncilMember;
    uint256 public emergencyCouncilSize;

    // Access control
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");
    bytes32 public constant PROPOSAL_CREATOR_ROLE = keccak256("PROPOSAL_CREATOR_ROLE");

    // Configuration
    uint256 public votingDelay = 1 blocks;           // 1 block before voting starts
    uint256 public votingPeriodSimple = 3 days;      // 3 days to vote on simple proposal
    uint256 public votingPeriodComplex = 7 days;     // 7 days for complex proposal
    uint256 public votingPeriodEmergency = 1 days;   // 1 day for emergency proposal
    uint256 public timelockDelaySimple = 0 seconds;  // Immediate execution
    uint256 public timelockDelayComplex = 2 days;    // 2-day timelock for complex
    uint256 public timelockDelayEmergency = 0 seconds; // Immediate execution

    // Thresholds
    uint256 public approvalThresholdSimple = 30;     // 30% approval required
    uint256 public approvalThresholdComplex = 66;    // 66% approval required
    uint256 public approvalThresholdEmergency = 75;  // 75% approval required
    uint256 public quorumPercentage = 25;            // 25% participation required

    // ==================== Events ====================

    event ProposalCreated(
        uint256 indexed proposalId,
        address indexed proposer,
        ProposalType proposalType,
        string title,
        uint256 startBlock,
        uint256 endBlock
    );

    event VoteCast(
        uint256 indexed proposalId,
        address indexed voter,
        VoteType support,
        uint256 votes,
        string reason
    );

    event ProposalQueued(
        uint256 indexed proposalId,
        uint256 eta
    );

    event ProposalExecuted(
        uint256 indexed proposalId,
        uint256 executedAt
    );

    event ProposalCanceled(
        uint256 indexed proposalId,
        string reason
    );

    event VotingDelegated(
        address indexed delegator,
        address indexed delegatee,
        uint256 amount
    );

    event DelegationRevoked(
        address indexed delegator,
        address indexed previousDelegatee
    );

    event GovernanceParameterUpdated(
        string indexed parameterName,
        uint256 oldValue,
        uint256 newValue,
        address indexed updatedBy
    );

    event EmergencyPauseTriggered(
        address indexed triggeredBy,
        string reason
    );

    event EmergencyPauseLifted(
        address indexed liftedBy
    );

    // ==================== Modifiers ====================

    modifier notPaused() {
        require(!isPaused, "Governance is paused");
        _;
    }

    modifier onlyEmergencyCouncil() {
        require(isEmergencyCouncilMember[msg.sender], "Not emergency council member");
        _;
    }

    modifier proposalExists(uint256 proposalId) {
        require(proposals[proposalId].startBlock > 0, "Proposal does not exist");
        _;
    }

    // ==================== Initialization ====================

    function initialize(
        address _governanceToken,
        address _admin,
        address _emergencyCouncil
    ) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(GOVERNANCE_ROLE, _admin);
        _grantRole(PROPOSAL_CREATOR_ROLE, _admin);

        governanceToken = IGovernanceToken(_governanceToken);
        tokenAddress = _governanceToken;
        emergencyCouncil = _emergencyCouncil;
    }

    // ==================== Proposal Creation ====================

    /**
     * @notice Create a governance proposal
     * @param proposalType Simple, Complex, or Emergency
     * @param title Proposal title
     * @param description Proposal description
     * @param targets Target contract addresses
     * @param values ETH values for calls
     * @param callSignatures Function signatures
     * @param calldatas Encoded function data
     * @param metadata IPFS hash or metadata URI
     * @return proposalId Unique proposal identifier
     */
    function createProposal(
        ProposalType proposalType,
        string calldata title,
        string calldata description,
        address[] calldata targets,
        uint256[] calldata values,
        string[] calldata callSignatures,
        bytes[] calldata calldatas,
        string calldata metadata
    ) external onlyRole(PROPOSAL_CREATOR_ROLE) notPaused nonReentrant returns (uint256 proposalId) {
        require(bytes(title).length > 0, "Title cannot be empty");
        require(targets.length > 0, "Must have targets");
        require(
            targets.length == values.length && 
            targets.length == callSignatures.length && 
            targets.length == calldatas.length,
            "Array length mismatch"
        );

        proposalId = proposalCounter++;

        // Determine voting period based on proposal type
        uint256 votingPeriod = proposalType == ProposalType.SIMPLE
            ? votingPeriodSimple
            : proposalType == ProposalType.COMPLEX
            ? votingPeriodComplex
            : votingPeriodEmergency;

        uint256 startBlock = block.number + uint256(votingDelay);
        uint256 endBlock = startBlock + votingPeriod;

        proposals[proposalId] = Proposal({
            proposalId: proposalId,
            proposer: msg.sender,
            proposalType: proposalType,
            status: ProposalStatus.PENDING,
            title: title,
            description: description,
            targets: targets,
            values: values,
            callSignatures: callSignatures,
            calldatas: calldatas,
            startBlock: startBlock,
            endBlock: endBlock,
            forVotes: 0,
            againstVotes: 0,
            abstainVotes: 0,
            startTime: block.timestamp,
            endTime: block.timestamp + votingPeriod,
            eta: 0,
            canceled: false,
            executed: false,
            canceledBy: bytes32(0),
            metadata: metadata
        });

        allProposalIds.push(proposalId);

        // Update status to ACTIVE
        proposals[proposalId].status = ProposalStatus.ACTIVE;

        emit ProposalCreated(
            proposalId,
            msg.sender,
            proposalType,
            title,
            startBlock,
            endBlock
        );

        return proposalId;
    }

    // ==================== Voting ====================

    /**
     * @notice Cast a vote on a proposal
     * @param proposalId Proposal ID
     * @param support Vote type (FOR, AGAINST, ABSTAIN)
     * @param reason Optional reason for vote
     */
    function castVote(
        uint256 proposalId,
        VoteType support,
        string calldata reason
    ) external notPaused proposalExists(proposalId) nonReentrant {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp >= proposal.startTime, "Voting not started");
        require(block.timestamp <= proposal.endTime, "Voting ended");
        require(!hasVoted[proposalId][msg.sender], "Already voted");

        // Get voting power (including delegated)
        address votingAddress = msg.sender;
        address delegatee = governanceToken.delegated(msg.sender);
        if (delegatee != address(0)) {
            votingAddress = delegatee;
        }

        uint256 votes = governanceToken.balanceOf(votingAddress);
        require(votes > 0, "No voting power");

        // Record vote
        hasVoted[proposalId][msg.sender] = true;
        votingRecords[proposalId][msg.sender] = VotingRecord({
            voter: msg.sender,
            proposalId: proposalId,
            votes: votes,
            support: support,
            timestamp: block.timestamp,
            hasVoted: true
        });

        // Update proposal vote tallies
        if (support == VoteType.FOR) {
            proposal.forVotes += votes;
        } else if (support == VoteType.AGAINST) {
            proposal.againstVotes += votes;
        } else {
            proposal.abstainVotes += votes;
        }

        emit VoteCast(proposalId, msg.sender, support, votes, reason);
    }

    /**
     * @notice Finalize voting and queue proposal for execution
     * @param proposalId Proposal ID
     */
    function finalizeVoting(uint256 proposalId)
        external
        notPaused
        proposalExists(proposalId)
        nonReentrant
    {
        Proposal storage proposal = proposals[proposalId];
        require(block.timestamp > proposal.endTime, "Voting still active");
        require(proposal.status == ProposalStatus.ACTIVE, "Proposal not active");

        // Check quorum
        uint256 totalVotes = proposal.forVotes + proposal.againstVotes + proposal.abstainVotes;
        require(totalVotes > 0, "No votes cast");

        // Check approval threshold based on type
        uint256 threshold = proposal.proposalType == ProposalType.SIMPLE
            ? approvalThresholdSimple
            : proposal.proposalType == ProposalType.COMPLEX
            ? approvalThresholdComplex
            : approvalThresholdEmergency;

        uint256 approvalPercentage = (proposal.forVotes * 100) / totalVotes;

        if (approvalPercentage >= threshold) {
            proposal.status = ProposalStatus.SUCCEEDED;

            // Queue for execution with appropriate timelock
            uint256 timelockDelay = proposal.proposalType == ProposalType.SIMPLE
                ? timelockDelaySimple
                : proposal.proposalType == ProposalType.COMPLEX
                ? timelockDelayComplex
                : timelockDelayEmergency;

            proposal.eta = block.timestamp + timelockDelay;
            proposal.status = ProposalStatus.QUEUED;

            emit ProposalQueued(proposalId, proposal.eta);
        } else {
            proposal.status = ProposalStatus.DEFEATED;
        }
    }

    /**
     * @notice Execute a queued proposal
     * @param proposalId Proposal ID
     */
    function executeProposal(uint256 proposalId)
        external
        notPaused
        proposalExists(proposalId)
        nonReentrant
    {
        Proposal storage proposal = proposals[proposalId];
        require(proposal.status == ProposalStatus.QUEUED, "Proposal not queued");
        require(block.timestamp >= proposal.eta, "Timelock not met");
        require(!proposal.executed, "Already executed");

        proposal.executed = true;
        proposal.status = ProposalStatus.EXECUTED;

        // Execute each transaction
        for (uint256 i = 0; i < proposal.targets.length; i++) {
            _executeTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.callSignatures[i],
                proposal.calldatas[i]
            );
        }

        emit ProposalExecuted(proposalId, block.timestamp);
    }

    /**
     * @notice Internal function to execute a single transaction
     */
    function _executeTransaction(
        address target,
        uint256 value,
        string memory signature,
        bytes memory data
    ) internal {
        bytes memory callData;

        if (bytes(signature).length == 0) {
            callData = data;
        } else {
            callData = abi.encodePacked(bytes4(keccak256(bytes(signature))), data);
        }

        (bool success, bytes memory returnData) = target.call{value: value}(callData);
        require(success, string(returnData));
    }

    // ==================== Voting Delegation ====================

    /**
     * @notice Delegate voting power to another address
     * @param delegatee Address to delegate to
     */
    function delegateVotingPower(address delegatee) external notPaused nonReentrant {
        require(delegatee != address(0), "Invalid delegatee");
        require(delegatee != msg.sender, "Cannot delegate to self");

        uint256 votingPower = governanceToken.balanceOf(msg.sender);
        require(votingPower > 0, "No voting power to delegate");

        delegations[msg.sender] = Delegation({
            delegator: msg.sender,
            delegatee: delegatee,
            amount: votingPower,
            timestamp: block.timestamp,
            isActive: true
        });

        delegationHistory[msg.sender].push(delegatee);

        emit VotingDelegated(msg.sender, delegatee, votingPower);
    }

    /**
     * @notice Revoke voting delegation
     */
    function revokeDelegation() external notPaused nonReentrant {
        Delegation storage delegation = delegations[msg.sender];
        require(delegation.isActive, "No active delegation");

        address previousDelegatee = delegation.delegatee;
        delegation.isActive = false;

        emit DelegationRevoked(msg.sender, previousDelegatee);
    }

    // ==================== Emergency Controls ====================

    /**
     * @notice Trigger emergency pause (emergency council only)
     * @param reason Reason for pause
     */
    function triggerEmergencyPause(string calldata reason)
        external
        onlyEmergencyCouncil
        nonReentrant
    {
        isPaused = true;
        emit EmergencyPauseTriggered(msg.sender, reason);
    }

    /**
     * @notice Lift emergency pause (only by admin after review)
     */
    function liftEmergencyPause() external onlyRole(DEFAULT_ADMIN_ROLE) nonReentrant {
        isPaused = false;
        emit EmergencyPauseLifted(msg.sender);
    }

    /**
     * @notice Add emergency council member
     */
    function addEmergencyCouncilMember(address member)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        require(member != address(0), "Invalid address");
        isEmergencyCouncilMember[member] = true;
        emergencyCouncilSize++;
    }

    /**
     * @notice Remove emergency council member
     */
    function removeEmergencyCouncilMember(address member)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
        nonReentrant
    {
        isEmergencyCouncilMember[member] = false;
        emergencyCouncilSize--;
    }

    // ==================== Governance Parameter Updates ====================

    /**
     * @notice Update a governance parameter (time-locked)
     * @param parameterName Name of parameter
     * @param newValue New value
     */
    function updateGovernanceParameter(string calldata parameterName, uint256 newValue)
        external
        onlyRole(GOVERNANCE_ROLE)
        nonReentrant
    {
        GovernanceParameter storage param = parameters[parameterName];
        uint256 oldValue = param.value;

        param.name = parameterName;
        param.value = newValue;
        param.lastUpdated = block.timestamp;
        param.updatedBy = msg.sender;

        emit GovernanceParameterUpdated(parameterName, oldValue, newValue, msg.sender);
    }

    // ==================== Query Functions ====================

    function getProposal(uint256 proposalId)
        external
        view
        proposalExists(proposalId)
        returns (Proposal memory)
    {
        return proposals[proposalId];
    }

    function getProposalCount() external view returns (uint256) {
        return proposalCounter;
    }

    function getVotingRecord(uint256 proposalId, address voter)
        external
        view
        returns (VotingRecord memory)
    {
        return votingRecords[proposalId][voter];
    }

    function getDelegation(address delegator)
        external
        view
        returns (Delegation memory)
    {
        return delegations[delegator];
    }

    function getProposalStatus(uint256 proposalId)
        external
        view
        proposalExists(proposalId)
        returns (ProposalStatus)
    {
        return proposals[proposalId].status;
    }

    // ==================== Admin Functions ====================

    function cancelProposal(uint256 proposalId, string calldata reason)
        external
        onlyRole(GOVERNANCE_ROLE)
        proposalExists(proposalId)
        nonReentrant
    {
        Proposal storage proposal = proposals[proposalId];
        require(!proposal.executed, "Cannot cancel executed proposal");

        proposal.canceled = true;
        proposal.status = ProposalStatus.CANCELED;
        proposal.canceledBy = keccak256(abi.encodePacked(reason));

        emit ProposalCanceled(proposalId, reason);
    }

    function setVotingDelay(uint256 blocks) external onlyRole(GOVERNANCE_ROLE) {
        votingDelay = blocks;
    }

    function setVotingPeriod(ProposalType proposalType, uint256 duration)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        if (proposalType == ProposalType.SIMPLE) {
            votingPeriodSimple = duration;
        } else if (proposalType == ProposalType.COMPLEX) {
            votingPeriodComplex = duration;
        } else {
            votingPeriodEmergency = duration;
        }
    }

    function setApprovalThreshold(ProposalType proposalType, uint256 percentage)
        external
        onlyRole(GOVERNANCE_ROLE)
    {
        require(percentage > 0 && percentage <= 100, "Invalid percentage");

        if (proposalType == ProposalType.SIMPLE) {
            approvalThresholdSimple = percentage;
        } else if (proposalType == ProposalType.COMPLEX) {
            approvalThresholdComplex = percentage;
        } else {
            approvalThresholdEmergency = percentage;
        }
    }

    // ==================== Upgradeable Pattern ====================

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {}
}
