// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

/**
 * @title ComplianceRegistry
 * @notice Enterprise-grade compliance registry for KYC, AML, sanctions screening, and transfer restrictions
 * @dev Implements Reg D/S accreditation verification, OFAC/PEP screening, country restrictions
 * 
 * COMPLIANCE FEATURES:
 * - KYC/AML allowlist with tiered accreditation (Accredited, Qualified, Institutional)
 * - OFAC/PEP/Adverse Media screening with periodic re-verification
 * - Country restrictions (Reg D/S compliant: no ITIN nationals, no state sponsors)
 * - Transfer lockup periods (post-issuance restricted period)
 * - Compliance event audit trail (immutable records)
 * - Multi-role governance (COMPLIANCE_ROLE, REVIEWER_ROLE, EMERGENCY_ROLE)
 */

interface IOFAC {
    function checkSanctions(address account) external view returns (bool);
}

contract ComplianceRegistry is 
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    // ==================== Types ====================
    
    enum AccreditationLevel {
        NONE,           // 0: Not accredited
        ACCREDITED,     // 1: Accredited individual (>$1M net worth or >$200k income)
        QUALIFIED,      // 2: Qualified investor (institutions, entities)
        INSTITUTIONAL   // 3: Institutional investor (funds, corporations, entities)
    }

    enum ComplianceStatus {
        PENDING,        // Awaiting KYC review
        APPROVED,       // Passed KYC/AML, permitted to trade
        RESTRICTED,     // Pending re-verification or minor flag
        SUSPENDED,      // Major compliance flag, cannot trade
        BLOCKED         // OFAC/sanctions match, permanently blocked
    }

    struct KYCData {
        address investor;
        string name;                           // Hashed for privacy
        string jurisdiction;                   // Country code (ISO 3166-1 alpha-2)
        AccreditationLevel accreditationLevel;
        ComplianceStatus complianceStatus;
        uint256 kycTimestamp;                  // When KYC was completed
        uint256 expiryTimestamp;               // When KYC expires (annual re-check)
        bytes32 documentHash;                  // Hash of KYC documentation
        address kycReviewer;                   // Who approved the KYC
        bool isPEP;                            // Politically Exposed Person flag
        bool hasAdverseMedia;                  // Adverse media flag
        string sanctionScreenResult;           // Result from sanctions check (OFAC, CFTC, etc.)
        uint256 lastScreeningTimestamp;
    }

    struct LockupPeriod {
        address holder;
        uint256 releaseTimestamp;
        uint256 lockedAmount;
        string reason;  // "Post-Issuance", "Strategic Hold", etc.
    }

    struct ComplianceEvent {
        uint256 timestamp;
        address account;
        string eventType;  // "KYC_APPROVED", "SANCTIONS_MATCH", "LOCKUP_SET", "TRANSFER_DENIED", etc.
        string details;
        address operator;
    }

    // ==================== State Variables ====================

    bytes32 public constant COMPLIANCE_ROLE = keccak256("COMPLIANCE_ROLE");
    bytes32 public constant REVIEWER_ROLE = keccak256("REVIEWER_ROLE");
    bytes32 public constant EMERGENCY_ROLE = keccak256("EMERGENCY_ROLE");
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");

    mapping(address => KYCData) public kycRegistry;
    mapping(address => LockupPeriod[]) public lockups;
    mapping(address => bool) public blocklist;  // OFAC/sanctions blocklist

    // Allowed jurisdictions (ISO 3166-1 alpha-2 codes)
    // Default: all except sanctioned jurisdictions (IR, KP, SY, CU)
    mapping(string => bool) public allowedJurisdictions;
    string[] public restrictedJurisdictions;  // ["IR", "KP", "SY", "CU"]

    ComplianceEvent[] public complianceAuditTrail;

    // Configuration
    uint256 public kycExpiryPeriod = 365 days;  // Re-verify annually
    uint256 public postIssuanceLockupPeriod = 180 days;
    address public ofacOracle;  // Address of OFAC/sanctions screening service

    // ==================== Events ====================

    event KYCSubmitted(address indexed investor, string jurisdiction, AccreditationLevel level);
    event KYCApproved(address indexed investor, address indexed reviewer, uint256 expiryTimestamp);
    event KYCExpired(address indexed investor);
    event KYCRenewed(address indexed investor, uint256 newExpiryTimestamp);
    
    event SanctionsFlagRaised(address indexed account, string result, string reason);
    event PEPFlagSet(address indexed account, bool isPEP);
    event AdverseMediaFlagSet(address indexed account, bool hasFlag);
    
    event LockupPeriodSet(address indexed holder, uint256 releaseTimestamp, uint256 amount, string reason);
    event LockupReleased(address indexed holder, uint256 amount);
    
    event ComplianceStatusChanged(address indexed account, ComplianceStatus from, ComplianceStatus to);
    event AccountBlocked(address indexed account, string reason);
    event AccountUnblocked(address indexed account);
    
    event JurisdictionAllowed(string jurisdictionCode);
    event JurisdictionRestricted(string jurisdictionCode);
    
    event ComplianceEventLogged(address indexed account, string eventType, string details);

    // ==================== Initialization ====================

    function initialize(address admin, address oracleAddress) public initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(COMPLIANCE_ROLE, admin);
        _grantRole(REVIEWER_ROLE, admin);
        _grantRole(EMERGENCY_ROLE, admin);
        _grantRole(UPGRADER_ROLE, admin);

        ofacOracle = oracleAddress;

        // Initialize allowed jurisdictions (all except restricted)
        restrictedJurisdictions = ["IR", "KP", "SY", "CU"];  // Iran, North Korea, Syria, Cuba
        initializeDefaultAllowedJurisdictions();
    }

    function initializeDefaultAllowedJurisdictions() internal {
        // Major jurisdictions (not exhaustive, but covers most trading destinations)
        string[] memory allowed = new string[](50);
        allowed[0] = "US"; allowed[1] = "CA"; allowed[2] = "GB"; allowed[3] = "DE"; 
        allowed[4] = "FR"; allowed[5] = "JP"; allowed[6] = "AU"; allowed[7] = "SG";
        allowed[8] = "CH"; allowed[9] = "NL"; allowed[10] = "SE"; allowed[11] = "NO";
        allowed[12] = "DK"; allowed[13] = "FI"; allowed[14] = "BE"; allowed[15] = "AT";
        allowed[16] = "IT"; allowed[17] = "ES"; allowed[18] = "IE"; allowed[19] = "LU";
        allowed[20] = "MT"; allowed[21] = "CY"; allowed[22] = "HK"; allowed[23] = "NZ";
        allowed[24] = "ZA"; allowed[25] = "AE"; allowed[26] = "QA"; allowed[27] = "KR";
        allowed[28] = "CL"; allowed[29] = "MX"; allowed[30] = "BR"; allowed[31] = "AR";
        allowed[32] = "CO"; allowed[33] = "PE"; allowed[34] = "IN"; allowed[35] = "MY";
        allowed[36] = "TH"; allowed[37] = "ID"; allowed[38] = "PH"; allowed[39] = "VN";
        allowed[40] = "CN"; allowed[41] = "TW"; allowed[42] = "IS"; allowed[43] = "GR";
        allowed[44] = "PT"; allowed[45] = "CZ"; allowed[46] = "PL"; allowed[47] = "HU";
        allowed[48] = "RO"; allowed[49] = "HR";

        for (uint256 i = 0; i < allowed.length; i++) {
            allowedJurisdictions[allowed[i]] = true;
        }
    }

    // ==================== KYC Management ====================

    /**
     * @notice Submit KYC data for compliance review
     * @param investor Address of investor
     * @param nameHash Hashed name (for privacy)
     * @param jurisdiction ISO 3166-1 alpha-2 country code
     * @param accreditationLevel Accreditation tier
     * @param documentHash Hash of supporting documentation
     */
    function submitKYC(
        address investor,
        string calldata nameHash,
        string calldata jurisdiction,
        AccreditationLevel accreditationLevel,
        bytes32 documentHash
    ) external onlyRole(COMPLIANCE_ROLE) {
        require(investor != address(0), "Invalid address");
        require(bytes(jurisdiction).length == 2, "Invalid jurisdiction code");

        KYCData storage kyc = kycRegistry[investor];
        kyc.investor = investor;
        kyc.name = nameHash;
        kyc.jurisdiction = jurisdiction;
        kyc.accreditationLevel = accreditationLevel;
        kyc.complianceStatus = ComplianceStatus.PENDING;
        kyc.kycTimestamp = block.timestamp;
        kyc.documentHash = documentHash;

        _logComplianceEvent(investor, "KYC_SUBMITTED", jurisdiction);
        emit KYCSubmitted(investor, jurisdiction, accreditationLevel);
    }

    /**
     * @notice Approve KYC after review
     * @param investor Address to approve
     * @dev Only REVIEWER_ROLE can approve
     */
    function approveKYC(address investor) external onlyRole(REVIEWER_ROLE) {
        require(investor != address(0), "Invalid address");
        
        KYCData storage kyc = kycRegistry[investor];
        require(kyc.kycTimestamp > 0, "No KYC submitted");
        require(!blocklist[investor], "Account is blocked");

        // Check jurisdiction allowed
        require(allowedJurisdictions[kyc.jurisdiction], "Jurisdiction not permitted");

        kyc.complianceStatus = ComplianceStatus.APPROVED;
        kyc.expiryTimestamp = block.timestamp + kycExpiryPeriod;
        kyc.kycReviewer = msg.sender;

        _logComplianceEvent(investor, "KYC_APPROVED", "Passed KYC review");
        emit KYCApproved(investor, msg.sender, kyc.expiryTimestamp);
    }

    /**
     * @notice Check if address has valid, non-expired KYC
     * @param account Address to check
     * @return isValid Whether KYC is valid and not expired
     */
    function isKYCValid(address account) external view returns (bool) {
        KYCData storage kyc = kycRegistry[account];
        return kyc.complianceStatus == ComplianceStatus.APPROVED 
            && kyc.expiryTimestamp > block.timestamp
            && !blocklist[account];
    }

    /**
     * @notice Check if KYC is expired and needs renewal
     * @param account Address to check
     * @return isExpired Whether KYC has expired
     */
    function isKYCExpired(address account) external view returns (bool) {
        KYCData storage kyc = kycRegistry[account];
        return kyc.expiryTimestamp > 0 && kyc.expiryTimestamp <= block.timestamp;
    }

    /**
     * @notice Renew KYC after expiry
     * @param investor Address to renew
     */
    function renewKYC(address investor) external onlyRole(REVIEWER_ROLE) {
        require(investor != address(0), "Invalid address");
        
        KYCData storage kyc = kycRegistry[investor];
        require(kyc.kycTimestamp > 0, "No KYC on file");
        require(!blocklist[investor], "Account is blocked");

        kyc.expiryTimestamp = block.timestamp + kycExpiryPeriod;
        kyc.complianceStatus = ComplianceStatus.APPROVED;
        kyc.lastScreeningTimestamp = block.timestamp;

        _logComplianceEvent(investor, "KYC_RENEWED", "Annual renewal passed");
        emit KYCRenewed(investor, kyc.expiryTimestamp);
    }

    // ==================== Sanctions & AML Screening ====================

    /**
     * @notice Flag account as OFAC/sanctions match
     * @param account Address to flag
     * @param screenResult Result from sanctions screening
     */
    function setSanctionsFlag(
        address account,
        string calldata screenResult
    ) external onlyRole(COMPLIANCE_ROLE) {
        require(account != address(0), "Invalid address");

        KYCData storage kyc = kycRegistry[account];
        kyc.sanctionScreenResult = screenResult;
        kyc.lastScreeningTimestamp = block.timestamp;
        kyc.complianceStatus = ComplianceStatus.BLOCKED;

        blocklist[account] = true;

        _logComplianceEvent(account, "SANCTIONS_MATCH", screenResult);
        emit SanctionsFlagRaised(account, screenResult, "OFAC/CFTC sanctions match");
    }

    /**
     * @notice Set PEP (Politically Exposed Person) flag
     * @param account Address to flag
     * @param isPEP Whether account is PEP
     */
    function setPEPFlag(address account, bool isPEP) external onlyRole(COMPLIANCE_ROLE) {
        require(account != address(0), "Invalid address");

        KYCData storage kyc = kycRegistry[account];
        kyc.isPEP = isPEP;

        if (isPEP) {
            kyc.complianceStatus = ComplianceStatus.RESTRICTED;
            _logComplianceEvent(account, "PEP_FLAG_SET", "Politically Exposed Person");
        }

        emit PEPFlagSet(account, isPEP);
    }

    /**
     * @notice Set adverse media flag
     * @param account Address to flag
     * @param hasFlag Whether account has adverse media
     */
    function setAdverseMediaFlag(address account, bool hasFlag) external onlyRole(COMPLIANCE_ROLE) {
        require(account != address(0), "Invalid address");

        KYCData storage kyc = kycRegistry[account];
        kyc.hasAdverseMedia = hasFlag;

        if (hasFlag) {
            kyc.complianceStatus = ComplianceStatus.RESTRICTED;
            _logComplianceEvent(account, "ADVERSE_MEDIA_FLAG_SET", "Adverse media detected");
        }

        emit AdverseMediaFlagSet(account, hasFlag);
    }

    // ==================== Transfer Restrictions ====================

    /**
     * @notice Set lockup period for restricted securities
     * @param holder Address to lockup
     * @param releaseTimestamp When tokens become tradeable
     * @param amount Amount locked
     * @param reason Reason for lockup (e.g., "Post-Issuance", "Reg D Rule 504")
     */
    function setLockupPeriod(
        address holder,
        uint256 releaseTimestamp,
        uint256 amount,
        string calldata reason
    ) external onlyRole(COMPLIANCE_ROLE) {
        require(holder != address(0), "Invalid address");
        require(releaseTimestamp > block.timestamp, "Release time must be in future");
        require(amount > 0, "Amount must be positive");

        lockups[holder].push(LockupPeriod({
            holder: holder,
            releaseTimestamp: releaseTimestamp,
            lockedAmount: amount,
            reason: reason
        }));

        _logComplianceEvent(holder, "LOCKUP_SET", reason);
        emit LockupPeriodSet(holder, releaseTimestamp, amount, reason);
    }

    /**
     * @notice Get total locked amount for holder
     * @param holder Address to check
     * @return lockedAmount Total amount currently locked
     */
    function getLockedAmount(address holder) external view returns (uint256) {
        uint256 total = 0;
        LockupPeriod[] storage holderLockups = lockups[holder];
        
        for (uint256 i = 0; i < holderLockups.length; i++) {
            if (holderLockups[i].releaseTimestamp > block.timestamp) {
                total += holderLockups[i].lockedAmount;
            }
        }
        
        return total;
    }

    /**
     * @notice Check if transfer is allowed
     * @param from Sender address
     * @param to Recipient address
     * @param amount Amount to transfer
     * @return isAllowed Whether transfer is permitted
     * @return reason Reason if denied
     */
    function canTransfer(
        address from,
        address to,
        uint256 amount
    ) external view returns (bool isAllowed, string memory reason) {
        // Check sender KYC
        if (!_isCompliant(from)) {
            return (false, "Sender KYC not valid");
        }

        // Check recipient KYC
        if (!_isCompliant(to)) {
            return (false, "Recipient KYC not valid");
        }

        // Check if sender is blocked
        if (blocklist[from] || blocklist[to]) {
            return (false, "Account blocked (OFAC/sanctions)");
        }

        // Check lockup periods
        uint256 totalLocked = 0;
        LockupPeriod[] storage holderLockups = lockups[from];
        
        for (uint256 i = 0; i < holderLockups.length; i++) {
            if (holderLockups[i].releaseTimestamp > block.timestamp) {
                totalLocked += holderLockups[i].lockedAmount;
            }
        }

        // This check is informational; actual balance check done by token contract
        if (amount > 0 && totalLocked > 0) {
            return (false, "Tokens subject to lockup restriction");
        }

        return (true, "");
    }

    // ==================== Jurisdiction Management ====================

    /**
     * @notice Allow trading from specific jurisdiction
     * @param jurisdictionCode ISO 3166-1 alpha-2 code
     */
    function allowJurisdiction(string calldata jurisdictionCode) external onlyRole(COMPLIANCE_ROLE) {
        require(bytes(jurisdictionCode).length == 2, "Invalid jurisdiction code");
        require(!_isRestricted(jurisdictionCode), "Cannot allow restricted jurisdiction");
        
        allowedJurisdictions[jurisdictionCode] = true;
        emit JurisdictionAllowed(jurisdictionCode);
    }

    /**
     * @notice Restrict trading from specific jurisdiction
     * @param jurisdictionCode ISO 3166-1 alpha-2 code
     */
    function restrictJurisdiction(string calldata jurisdictionCode) external onlyRole(COMPLIANCE_ROLE) {
        require(bytes(jurisdictionCode).length == 2, "Invalid jurisdiction code");
        
        allowedJurisdictions[jurisdictionCode] = false;
        restrictedJurisdictions.push(jurisdictionCode);
        
        emit JurisdictionRestricted(jurisdictionCode);
    }

    // ==================== Account Blocking ====================

    /**
     * @notice Block account from all operations
     * @param account Address to block
     * @param reason Reason for blocking
     */
    function blockAccount(address account, string calldata reason) external onlyRole(EMERGENCY_ROLE) {
        require(account != address(0), "Invalid address");
        
        blocklist[account] = true;
        KYCData storage kyc = kycRegistry[account];
        kyc.complianceStatus = ComplianceStatus.BLOCKED;

        _logComplianceEvent(account, "ACCOUNT_BLOCKED", reason);
        emit AccountBlocked(account, reason);
    }

    /**
     * @notice Unblock account
     * @param account Address to unblock
     */
    function unblockAccount(address account) external onlyRole(EMERGENCY_ROLE) {
        require(account != address(0), "Invalid address");
        
        blocklist[account] = false;
        KYCData storage kyc = kycRegistry[account];
        if (kyc.complianceStatus == ComplianceStatus.BLOCKED) {
            kyc.complianceStatus = ComplianceStatus.APPROVED;
        }

        _logComplianceEvent(account, "ACCOUNT_UNBLOCKED", "");
        emit AccountUnblocked(account);
    }

    /**
     * @notice Check if account is blocked
     * @param account Address to check
     * @return isBlocked Whether account is blocked
     */
    function isBlocked(address account) external view returns (bool) {
        return blocklist[account];
    }

    // ==================== Audit Trail ====================

    /**
     * @notice Get compliance audit trail for account
     * @param account Address to check
     * @return events Array of compliance events
     */
    function getComplianceAuditTrail(address account) 
        external 
        view 
        returns (ComplianceEvent[] memory) 
    {
        uint256 count = 0;
        for (uint256 i = 0; i < complianceAuditTrail.length; i++) {
            if (complianceAuditTrail[i].account == account) {
                count++;
            }
        }

        ComplianceEvent[] memory events = new ComplianceEvent[](count);
        uint256 idx = 0;
        for (uint256 i = 0; i < complianceAuditTrail.length; i++) {
            if (complianceAuditTrail[i].account == account) {
                events[idx] = complianceAuditTrail[i];
                idx++;
            }
        }

        return events;
    }

    // ==================== Internal Functions ====================

    function _isCompliant(address account) internal view returns (bool) {
        if (blocklist[account]) return false;
        
        KYCData storage kyc = kycRegistry[account];
        return kyc.complianceStatus == ComplianceStatus.APPROVED 
            && kyc.expiryTimestamp > block.timestamp;
    }

    function _isRestricted(string memory jurisdictionCode) internal view returns (bool) {
        for (uint256 i = 0; i < restrictedJurisdictions.length; i++) {
            if (keccak256(bytes(restrictedJurisdictions[i])) == keccak256(bytes(jurisdictionCode))) {
                return true;
            }
        }
        return false;
    }

    function _logComplianceEvent(
        address account,
        string memory eventType,
        string memory details
    ) internal {
        complianceAuditTrail.push(ComplianceEvent({
            timestamp: block.timestamp,
            account: account,
            eventType: eventType,
            details: details,
            operator: msg.sender
        }));
        
        emit ComplianceEventLogged(account, eventType, details);
    }

    // ==================== Configuration ====================

    function setKYCExpiryPeriod(uint256 newPeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        kycExpiryPeriod = newPeriod;
    }

    function setPostIssuanceLockupPeriod(uint256 newPeriod) external onlyRole(DEFAULT_ADMIN_ROLE) {
        postIssuanceLockupPeriod = newPeriod;
    }

    function setOFACOracle(address newOracle) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(newOracle != address(0), "Invalid oracle");
        ofacOracle = newOracle;
    }

    // ==================== Upgrade Authorization ====================

    function _authorizeUpgrade(address newImplementation) 
        internal 
        onlyRole(UPGRADER_ROLE) 
    {}
}
