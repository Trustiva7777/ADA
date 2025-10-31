// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "../compliance/ComplianceRegistry.sol";

/**
 * @title TransferGate
 * @notice Enforces Reg D/S transfer restrictions, lockup periods, and trading windows
 * @dev Prevents restricted securities from violating SEC Rule 144 holding periods
 * 
 * FEATURES:
 * - Reg D/S restricted securities compliance (180-day/1-year holding periods)
 * - Affiliate/non-affiliate status tracking
 * - Form 144 filing requirements (accredited investor info)
 * - Trading volume limits for affiliates
 * - Broker-assisted sale requirements
 * - Acquisition price tracking for unrestricted value determination
 * - Volume limit calculations per SEC Rule 144(e)
 */

interface IQHSecurityToken {
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function mint(address to, uint256 amount) external;
    function burn(uint256 amount) external;
}

contract TransferGate is 
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    // ==================== Types ====================

    enum InvestorStatus {
        NONE,           // Not registered
        ACCREDITED,     // Accredited individual or entity
        AFFILIATED,     // Affiliate of issuer
        CONTROL,        // Control person (director, officer, major shareholder)
        DISTRIBUTION_AFFILIATE  // Affiliate in distribution
    }

    struct InvestorRecord {
        address investor;
        InvestorStatus status;
        uint256 acquisitionDate;        // When investor first acquired shares
        uint256 acquisitionPrice;       // Price paid at acquisition
        uint256 totalAcquired;          // Total number of shares acquired
        bool isAffiliate;               // Affiliate of issuer per Rule 144
        bool hasForm144Filed;           // Form 144 notice filed with SEC
        uint256 lastForm144FilingDate;  // Timestamp of last Form 144 filing
        uint256 lastSaleAmount;         // Amount sold in last transaction
        uint256 lastSaleDate;           // Timestamp of last sale
    }

    struct VolumeCalculation {
        uint256 issuerShares;           // Total shares outstanding
        uint256 avgDailyVolume;         // Average daily volume on exchange
        uint256 issuedCapital;          // Issuer's market cap
        uint256 maxVolumeLimit;         // 1% of outstanding or 4-week avg volume
    }

    struct TransferRequest {
        uint256 requestId;
        address from;
        address to;
        uint256 amount;
        uint256 timestamp;
        bool isApproved;
        string denialReason;
    }

    // ==================== State Variables ====================

    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant SEC_ROLE = keccak256("SEC_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    IQHSecurityToken public securityToken;
    ComplianceRegistry public complianceRegistry;

    mapping(address => InvestorRecord) public investorRecords;
    mapping(uint256 => TransferRequest) public transferRequests;
    
    uint256 public nextRequestId = 1;
    uint256 public constant HOLDING_PERIOD_RESTRICTED = 180 days;  // Reg D/S Rule 504
    uint256 public constant HOLDING_PERIOD_AFFILIATE = 6 months;    // Rule 144(i)
    uint256 public constant HOLDING_PERIOD_FULL = 1 years;          // Rule 144(h) - control persons

    // Volume calculations
    VolumeCalculation public volumeCalculation;
    uint256 public fourWeekAverageVolume = 100000e18;  // Default 100k tokens
    uint256 public lastVolumeUpdateTimestamp;

    // Configuration
    bool public requireForm144 = true;  // Require Form 144 filing for affiliates
    bool public allowUnrestrictedSalesOnly = false;  // If true, only allow Rule 144 unrestricted sales
    uint256 public form144FilingRequirementDays = 2 days;  // Form 144 must be filed by T+2

    // ==================== Events ====================

    event InvestorRegistered(address indexed investor, InvestorStatus status);
    event AffiliateStatusSet(address indexed investor, bool isAffiliate);
    event TransferRequested(uint256 indexed requestId, address indexed from, address indexed to, uint256 amount);
    event TransferApproved(uint256 indexed requestId);
    event TransferDenied(uint256 indexed requestId, string reason);
    event Form144Filed(address indexed investor, uint256 amount, uint256 timestamp);
    event VolumeCalculationUpdated(uint256 avgDailyVolume, uint256 maxVolumeLimit);
    event RestrictionLifted(address indexed investor, string reason);

    // ==================== Initialization ====================

    function initialize(
        address tokenAddress,
        address complianceAddress,
        address admin
    ) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        securityToken = IQHSecurityToken(tokenAddress);
        complianceRegistry = ComplianceRegistry(complianceAddress);

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
        _grantRole(SEC_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);
    }

    // ==================== Investor Registration ====================

    /**
     * @notice Register investor with Reg D/S status
     * @param investor Address of investor
     * @param status Accredited, Affiliated, Control, or Distribution Affiliate
     * @param acquisitionDate When shares were acquired
     * @param acquisitionPrice Price per share at acquisition
     * @param totalAcquired Total shares acquired
     */
    function registerInvestor(
        address investor,
        InvestorStatus status,
        uint256 acquisitionDate,
        uint256 acquisitionPrice,
        uint256 totalAcquired
    ) external onlyRole(COMPLIANCE_ROLE) {
        require(investor != address(0), "Invalid address");
        require(status != InvestorStatus.NONE, "Invalid status");

        InvestorRecord storage record = investorRecords[investor];
        record.investor = investor;
        record.status = status;
        record.acquisitionDate = acquisitionDate;
        record.acquisitionPrice = acquisitionPrice;
        record.totalAcquired = totalAcquired;

        emit InvestorRegistered(investor, status);
    }

    /**
     * @notice Set affiliate status for investor (Rule 144 definition)
     * @param investor Address to mark
     * @param isAffiliate Whether investor is affiliate
     */
    function setAffiliateStatus(address investor, bool isAffiliate) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        require(investor != address(0), "Invalid address");
        
        InvestorRecord storage record = investorRecords[investor];
        record.isAffiliate = isAffiliate;

        if (isAffiliate) {
            record.status = InvestorStatus.AFFILIATED;
        }

        emit AffiliateStatusSet(investor, isAffiliate);
    }

    // ==================== Transfer Authorization ====================

    /**
     * @notice Request transfer with compliance checking
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return requestId ID of transfer request
     */
    function requestTransfer(
        address from,
        address to,
        uint256 amount
    ) external nonReentrant returns (uint256) {
        require(from != address(0) && to != address(0), "Invalid address");
        require(amount > 0, "Amount must be positive");

        uint256 requestId = nextRequestId++;
        
        // Perform compliance checks
        (bool isCompliant, string memory reason) = _checkTransferCompliance(from, to, amount);

        TransferRequest storage request = transferRequests[requestId];
        request.requestId = requestId;
        request.from = from;
        request.to = to;
        request.amount = amount;
        request.timestamp = block.timestamp;
        request.isApproved = isCompliant;
        request.denialReason = reason;

        emit TransferRequested(requestId, from, to, amount);

        if (isCompliant) {
            emit TransferApproved(requestId);
        } else {
            emit TransferDenied(requestId, reason);
        }

        return requestId;
    }

    /**
     * @notice Execute approved transfer
     * @param requestId ID of transfer request
     */
    function executeTransfer(uint256 requestId) external nonReentrant {
        TransferRequest storage request = transferRequests[requestId];
        require(request.requestId == requestId, "Invalid request ID");
        require(request.isApproved, "Transfer not approved");
        require(request.from == msg.sender || hasRole(COMPLIANCE_ROLE, msg.sender), "Unauthorized");

        // Execute the actual transfer via the security token
        securityToken.transferFrom(request.from, request.to, request.amount);

        // Update investor records
        InvestorRecord storage record = investorRecords[request.from];
        record.lastSaleAmount = request.amount;
        record.lastSaleDate = block.timestamp;
    }

    // ==================== Compliance Checking ====================

    /**
     * @notice Check if transfer complies with Reg D/S and Rule 144
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return isCompliant Whether transfer is allowed
     * @return reason Denial reason if not compliant
     */
    function _checkTransferCompliance(
        address from,
        address to,
        uint256 amount
    ) internal view returns (bool, string memory) {
        // Check KYC/AML compliance
        (bool kycCompliant, ) = complianceRegistry.canTransfer(from, to, amount);
        if (!kycCompliant) {
            return (false, "KYC/AML compliance failed");
        }

        InvestorRecord storage record = investorRecords[from];

        // If no investor record, assume unrestricted
        if (record.investor == address(0)) {
            return (true, "");
        }

        // Check holding periods based on investor status
        if (record.status == InvestorStatus.ACCREDITED) {
            return _checkAccreditedSaleCompliance(from, amount);
        } else if (record.isAffiliate) {
            return _checkAffiliateSaleCompliance(from, amount);
        } else if (record.status == InvestorStatus.CONTROL) {
            return _checkControlPersonSaleCompliance(from, amount);
        }

        return (true, "");
    }

    /**
     * @notice Check compliance for accredited investor sales (Rule 504)
     * @param investor Investor address
     * @param amount Amount attempting to sell
     */
    function _checkAccreditedSaleCompliance(
        address investor,
        uint256 amount
    ) internal view returns (bool, string memory) {
        InvestorRecord storage record = investorRecords[investor];

        // Rule 504: 180-day holding period for Reg D offerings
        if (block.timestamp < record.acquisitionDate + HOLDING_PERIOD_RESTRICTED) {
            return (
                false, 
                "Rule 504: 180-day holding period not satisfied"
            );
        }

        return (true, "");
    }

    /**
     * @notice Check compliance for affiliate sales (Rule 144)
     * @param investor Investor address
     * @param amount Amount attempting to sell
     */
    function _checkAffiliateSaleCompliance(
        address investor,
        uint256 amount
    ) internal view returns (bool, string memory) {
        InvestorRecord storage record = investorRecords[investor];

        // Rule 144(i): 6-month holding period for affiliates
        if (block.timestamp < record.acquisitionDate + HOLDING_PERIOD_AFFILIATE) {
            return (
                false, 
                "Rule 144: 6-month holding period not satisfied for affiliate"
            );
        }

        // Rule 144(e): Volume limit - cannot sell more than greater of:
        // 1. 1% of outstanding shares, or
        // 2. Average weekly volume for prior 4 weeks
        uint256 maxVolume = _calculateVolumeLimit();
        if (amount > maxVolume) {
            return (
                false, 
                "Rule 144(e): Volume limit exceeded"
            );
        }

        // Require Form 144 filing
        if (requireForm144) {
            if (!record.hasForm144Filed || 
                block.timestamp > record.lastForm144FilingDate + form144FilingRequirementDays) {
                return (
                    false, 
                    "SEC Form 144 filing required"
                );
            }
        }

        return (true, "");
    }

    /**
     * @notice Check compliance for control person sales (Rule 144)
     * @param investor Investor address
     * @param amount Amount attempting to sell
     */
    function _checkControlPersonSaleCompliance(
        address investor,
        uint256 amount
    ) internal view returns (bool, string memory) {
        InvestorRecord storage record = investorRecords[investor];

        // Rule 144(h): 1-year holding period for control persons
        if (block.timestamp < record.acquisitionDate + HOLDING_PERIOD_FULL) {
            return (
                false, 
                "Rule 144: 1-year holding period not satisfied for control person"
            );
        }

        // Volume limit stricter for control persons
        uint256 maxVolume = _calculateVolumeLimit();
        if (amount > maxVolume / 2) {  // 0.5% instead of 1%
            return (
                false, 
                "Rule 144 (control person): Volume limit exceeded"
            );
        }

        // Require Form 144 filing
        if (requireForm144) {
            if (!record.hasForm144Filed || 
                block.timestamp > record.lastForm144FilingDate + form144FilingRequirementDays) {
                return (
                    false, 
                    "SEC Form 144 filing required"
                );
            }
        }

        return (true, "");
    }

    // ==================== Volume Calculations ====================

    /**
     * @notice Calculate Rule 144(e) volume limit
     * @return maxVolume Maximum sellable volume
     */
    function _calculateVolumeLimit() internal view returns (uint256) {
        // 1% of outstanding shares
        uint256 totalOutstanding = securityToken.balanceOf(address(this));
        uint256 onePercent = totalOutstanding / 100;

        // Greater of 1% or 4-week average volume
        return (fourWeekAverageVolume > onePercent) ? fourWeekAverageVolume : onePercent;
    }

    /**
     * @notice Update 4-week average daily volume
     * @param newAverageVolume New average daily volume
     */
    function updateAverageDailyVolume(uint256 newAverageVolume) 
        external 
        onlyRole(SEC_ROLE) 
    {
        fourWeekAverageVolume = newAverageVolume;
        lastVolumeUpdateTimestamp = block.timestamp;

        uint256 maxVolume = _calculateVolumeLimit();
        emit VolumeCalculationUpdated(newAverageVolume, maxVolume);
    }

    // ==================== Form 144 Filing ====================

    /**
     * @notice File SEC Form 144 (notice of proposed sale of securities)
     * @param investor Investor filing form
     * @param saleAmount Amount proposing to sell
     */
    function fileForm144(address investor, uint256 saleAmount) 
        external 
        onlyRole(COMPLIANCE_ROLE) 
    {
        require(investor != address(0), "Invalid address");
        require(saleAmount > 0, "Invalid amount");

        InvestorRecord storage record = investorRecords[investor];
        record.hasForm144Filed = true;
        record.lastForm144FilingDate = block.timestamp;

        emit Form144Filed(investor, saleAmount, block.timestamp);
    }

    // ==================== Restriction Management ====================

    /**
     * @notice Lift restrictions when holding period expires
     * @param investor Investor address
     */
    function liftRestrictions(address investor) external onlyRole(COMPLIANCE_ROLE) {
        require(investor != address(0), "Invalid address");

        InvestorRecord storage record = investorRecords[investor];
        
        string memory reason = "";
        
        if (record.status == InvestorStatus.ACCREDITED &&
            block.timestamp >= record.acquisitionDate + HOLDING_PERIOD_RESTRICTED) {
            reason = "Rule 504 holding period satisfied";
        } else if (record.isAffiliate &&
            block.timestamp >= record.acquisitionDate + HOLDING_PERIOD_AFFILIATE) {
            reason = "Rule 144(i) 6-month holding period satisfied";
        } else if (record.status == InvestorStatus.CONTROL &&
            block.timestamp >= record.acquisitionDate + HOLDING_PERIOD_FULL) {
            reason = "Rule 144(h) 1-year holding period satisfied";
        }

        if (bytes(reason).length > 0) {
            record.status = InvestorStatus.NONE;
            record.isAffiliate = false;
            emit RestrictionLifted(investor, reason);
        }
    }

    // ==================== Query Functions ====================

    /**
     * @notice Get investor record
     * @param investor Investor address
     */
    function getInvestorRecord(address investor) 
        external 
        view 
        returns (InvestorRecord memory) 
    {
        return investorRecords[investor];
    }

    /**
     * @notice Get transfer request details
     * @param requestId Request ID
     */
    function getTransferRequest(uint256 requestId) 
        external 
        view 
        returns (TransferRequest memory) 
    {
        return transferRequests[requestId];
    }

    /**
     * @notice Calculate days until holding period expires
     * @param investor Investor address
     * @return daysRemaining Days until unrestricted (0 if already unrestricted)
     */
    function getDaysUntilUnrestricted(address investor) 
        external 
        view 
        returns (uint256) 
    {
        InvestorRecord storage record = investorRecords[investor];
        
        if (record.investor == address(0)) {
            return 0;  // Not registered
        }

        uint256 releaseDate = record.acquisitionDate + HOLDING_PERIOD_RESTRICTED;
        
        if (record.isAffiliate) {
            releaseDate = record.acquisitionDate + HOLDING_PERIOD_AFFILIATE;
        }
        
        if (record.status == InvestorStatus.CONTROL) {
            releaseDate = record.acquisitionDate + HOLDING_PERIOD_FULL;
        }

        if (block.timestamp >= releaseDate) {
            return 0;
        }

        return (releaseDate - block.timestamp) / 1 days;
    }

    // ==================== Configuration ====================

    function setRequireForm144(bool require_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        requireForm144 = require_;
    }

    function setForm144FilingRequirement(uint256 days_) external onlyRole(DEFAULT_ADMIN_ROLE) {
        form144FilingRequirementDays = days_;
    }

    function setComplianceRegistry(address newRegistry) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newRegistry != address(0), "Invalid address");
        complianceRegistry = ComplianceRegistry(newRegistry);
    }

    // ==================== Upgrade Authorization ====================

    function _authorizeUpgrade(address newImplementation) 
        internal 
        onlyRole(UPGRADER_ROLE) 
    {}
}
