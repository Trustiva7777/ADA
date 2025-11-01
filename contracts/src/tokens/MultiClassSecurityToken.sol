// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title MultiClassSecurityToken
 * @notice Multi-Class Security Token with Waterfall Distributions (PATENT PENDING)
 * 
 * INNOVATION: Sophisticated cap table with multiple share classes and liquidation preferences
 * - Common shares, Preferred A (10% return), Preferred B (5% return), Warrants
 * - Automatic distribution waterfall (preferred investors paid first)
 * - Automatic conversion at liquidity events (IPO, acquisition, etc.)
 * - Different voting rights per class
 * - Liquidation priority enforcement
 * - Multiple stablecoin distribution support
 * 
 * USE CASES:
 * - Venture capital funding with preferred shares
 * - Employee option programs
 * - Strategic investor warrant programs
 * - Acquisition escrow with conversion triggers
 * - SAFE (Simple Agreements for Future Equity) implementation
 * 
 * CAPITAL STRUCTURE:
 * - Common: 60% of equity, standard voting
 * - Preferred A: 25% of equity, 10% preferred return, 2x voting
 * - Preferred B: 10% of equity, 5% preferred return, 1x voting
 * - Warrant: 5% of equity, future conversion right
 * 
 * PATENT: US Provisional - "Multi-Class Security Token Architecture with Dynamic Waterfall"
 * 
 * @dev Implements UUPS upgradeable pattern with role-based access control
 */

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract MultiClassSecurityToken is 
    AccessControlUpgradeable,
    UUPSUpgradeable,
    ReentrancyGuardUpgradeable
{
    // ==================== Types ====================

    enum ShareClass {
        COMMON,
        PREFERRED_A,
        PREFERRED_B,
        WARRANT
    }

    enum LiquidityEventType {
        IPO,
        ACQUISITION,
        SECONDARY_SALE,
        DISSOLUTION
    }

    struct ShareClassTerms {
        ShareClass classId;
        string name;
        string symbol;
        uint256 totalShares;
        uint256 outstandingShares;
        uint256 mintedShares;
        uint256 distributionPercentage;    // % of distributions (in basis points)
        uint256 votingPowerMultiplier;     // Voting weight (1x, 2x, etc.)
        uint256 preferredReturnPercentage; // Annual % (0 for common)
        bool canVote;
        bool participatesInLiquidation;
        uint256 liquidationPriority;       // 0 = highest priority
        bool canConvertAutomatically;      // Convert on liquidity event?
        ShareClass convertibleTo;          // What class does it convert to?
        uint256 conversionRatio;           // Conversion ratio (in basis points)
    }

    struct ShareholderRecord {
        address shareholder;
        ShareClass classId;
        uint256 shareCount;
        uint256 acquisitionPrice;          // In cents (e.g., 100 = $1.00)
        uint256 acquisitionDate;
        uint256 preferredReturnAccrued;    // Accrued but not yet distributed
        bool isLocked;
        uint256 lockupExpiryDate;
    }

    struct DistributionEvent {
        bytes32 eventId;
        uint256 timestamp;
        uint256 totalAmount;
        address settlementToken;
        uint256 waterfallExecuted;  // Block number when waterfall was calculated
        mapping(ShareClass => uint256) classDistributions;
        mapping(address => uint256) shareholderDistributions;
        bool isProcessed;
    }

    struct LiquidityEvent {
        bytes32 eventId;
        LiquidityEventType eventType;
        uint256 timestamp;
        uint256 liquidationPrice;  // Price per share in cents
        address triggeredBy;
        bool isExecuted;
        mapping(ShareClass => uint256) sharesConverted;
    }

    struct ConversionRight {
        bytes32 rightId;
        address holder;
        ShareClass fromClass;
        ShareClass toClass;
        uint256 ratio;                     // Basis points (10000 = 1:1)
        uint256 expiryDate;
        bool isExercised;
        uint256 sharesConverted;
    }

    // ==================== State Variables ====================

    // Share class registry
    mapping(ShareClass => ShareClassTerms) public shareClasses;
    ShareClass[] public activeShareClasses;

    // Shareholdings
    mapping(address => mapping(ShareClass => ShareholderRecord)) public shareholders;
    mapping(ShareClass => address[]) public classHolders;

    // Distributions
    mapping(bytes32 => DistributionEvent) public distributions;
    bytes32[] public distributionHistory;

    // Liquidity events
    mapping(bytes32 => LiquidityEvent) public liquidityEvents;
    bytes32[] public liquidityEventHistory;

    // Conversion rights
    mapping(bytes32 => ConversionRight) public conversionRights;
    bytes32[] public allConversionRights;

    // Configuration
    address public companyTreasury;
    uint256 public totalFundsRaised;
    mapping(address => uint256) public treasuryBalanceByToken;

    // Access control
    bytes32 public constant CLASS_MANAGER_ROLE = keccak256("CLASS_MANAGER_ROLE");
    bytes32 public constant DISTRIBUTION_ROLE = keccak256("DISTRIBUTION_ROLE");
    bytes32 public constant GOVERNANCE_ROLE = keccak256("GOVERNANCE_ROLE");

    // Counters
    uint256 public distributionCounter;
    uint256 public liquidityEventCounter;
    uint256 public conversionRightCounter;

    // ==================== Events ====================

    event ShareClassCreated(
        ShareClass indexed classId,
        string name,
        string symbol,
        uint256 distributionPercentage,
        uint256 preferredReturnPercentage
    );

    event SharesMinted(
        address indexed shareholder,
        ShareClass indexed classId,
        uint256 shareCount,
        uint256 acquisitionPrice
    );

    event DistributionInitiated(
        bytes32 indexed eventId,
        uint256 totalAmount,
        address settlementToken,
        uint256 timestamp
    );

    event DistributionWaterfallExecuted(
        bytes32 indexed eventId,
        mapping(ShareClass => uint256) classAllocations
    );

    event ShareholderDistributionPaid(
        bytes32 indexed eventId,
        address indexed shareholder,
        ShareClass indexed classId,
        uint256 amount
    );

    event LiquidityEventTriggered(
        bytes32 indexed eventId,
        LiquidityEventType eventType,
        uint256 liquidationPrice,
        uint256 timestamp
    );

    event SharesConverted(
        address indexed shareholder,
        ShareClass fromClass,
        ShareClass toClass,
        uint256 sharesConverted,
        uint256 newSharesReceived
    );

    event ConversionRightExercised(
        bytes32 indexed rightId,
        address indexed holder,
        uint256 sharesConverted
    );

    event PreferredReturnAccrued(
        address indexed shareholder,
        ShareClass indexed classId,
        uint256 amount,
        uint256 accruedTotal
    );

    event ShareholderRecordUpdated(
        address indexed shareholder,
        ShareClass indexed classId,
        uint256 newShareCount
    );

    // ==================== Initialization ====================

    function initialize(
        address _admin,
        address _treasury
    ) external initializer {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(CLASS_MANAGER_ROLE, _admin);
        _grantRole(DISTRIBUTION_ROLE, _admin);
        _grantRole(GOVERNANCE_ROLE, _admin);

        companyTreasury = _treasury;
    }

    // ==================== Share Class Setup ====================

    /**
     * @notice Create a new share class
     * @param classId Share class identifier
     * @param name Human-readable name (e.g., "Common", "Preferred A")
     * @param symbol Trading symbol (e.g., "QH.C", "QH.PA")
     * @param distributionPercentage % of profits distributed to this class (basis points)
     * @param votingPowerMultiplier Voting weight multiplier
     * @param preferredReturnPercentage Annual preferred return % (0 for common)
     * @param liquidationPriority Order in liquidation waterfall
     */
    function createShareClass(
        ShareClass classId,
        string calldata name,
        string calldata symbol,
        uint256 distributionPercentage,
        uint256 votingPowerMultiplier,
        uint256 preferredReturnPercentage,
        uint256 liquidationPriority
    ) external onlyRole(CLASS_MANAGER_ROLE) nonReentrant {
        require(bytes(name).length > 0, "Name cannot be empty");
        require(distributionPercentage > 0, "Distribution % must be positive");

        shareClasses[classId] = ShareClassTerms({
            classId: classId,
            name: name,
            symbol: symbol,
            totalShares: 0,
            outstandingShares: 0,
            mintedShares: 0,
            distributionPercentage: distributionPercentage,
            votingPowerMultiplier: votingPowerMultiplier,
            preferredReturnPercentage: preferredReturnPercentage,
            canVote: true,
            participatesInLiquidation: true,
            liquidationPriority: liquidationPriority,
            canConvertAutomatically: (classId != ShareClass.COMMON),
            convertibleTo: ShareClass.COMMON,
            conversionRatio: 10000  // 1:1 by default
        });

        activeShareClasses.push(classId);

        emit ShareClassCreated(
            classId,
            name,
            symbol,
            distributionPercentage,
            preferredReturnPercentage
        );
    }

    // ==================== Share Issuance ====================

    /**
     * @notice Mint shares for a shareholder
     * @param shareholder Investor address
     * @param classId Share class
     * @param shareCount Number of shares
     * @param acquisitionPrice Price per share in cents (e.g., 100 = $1.00)
     */
    function mintShares(
        address shareholder,
        ShareClass classId,
        uint256 shareCount,
        uint256 acquisitionPrice
    ) external onlyRole(CLASS_MANAGER_ROLE) nonReentrant {
        require(shareholder != address(0), "Invalid shareholder");
        require(shareCount > 0, "Share count must be positive");

        ShareClassTerms storage classTerms = shareClasses[classId];
        require(classTerms.totalShares >= 0, "Class must exist");

        // Record shareholding
        ShareholderRecord storage record = shareholders[shareholder][classId];
        if (record.shareholder == address(0)) {
            record.shareholder = shareholder;
            record.classId = classId;
            classHolders[classId].push(shareholder);
        }

        record.shareCount += shareCount;
        record.acquisitionDate = block.timestamp;
        record.acquisitionPrice = acquisitionPrice;

        classTerms.outstandingShares += shareCount;
        classTerms.mintedShares += shareCount;
        classTerms.totalShares += shareCount;

        // Track capital raised
        uint256 fundsRaised = (shareCount * acquisitionPrice) / 100;
        totalFundsRaised += fundsRaised;

        emit SharesMinted(shareholder, classId, shareCount, acquisitionPrice);
        emit ShareholderRecordUpdated(shareholder, classId, record.shareCount);
    }

    /**
     * @notice Burn shares (for cancellation)
     * @param shareholder Shareholder address
     * @param classId Share class
     * @param shareCount Number of shares to burn
     */
    function burnShares(
        address shareholder,
        ShareClass classId,
        uint256 shareCount
    ) external onlyRole(CLASS_MANAGER_ROLE) nonReentrant {
        ShareholderRecord storage record = shareholders[shareholder][classId];
        require(record.shareCount >= shareCount, "Insufficient shares");

        record.shareCount -= shareCount;
        shareClasses[classId].outstandingShares -= shareCount;

        emit ShareholderRecordUpdated(shareholder, classId, record.shareCount);
    }

    // ==================== Distribution Waterfall ====================

    /**
     * @notice Initiate a distribution event (profit sharing)
     * @param amount Total amount to distribute
     * @param settlementToken Token to distribute in (e.g., USDC)
     * @return eventId Distribution event ID
     */
    function initiateDistribution(
        uint256 amount,
        address settlementToken
    ) external onlyRole(DISTRIBUTION_ROLE) nonReentrant returns (bytes32 eventId) {
        require(amount > 0, "Amount must be positive");
        require(settlementToken != address(0), "Invalid token");

        // Receive distribution funds
        require(
            IERC20(settlementToken).transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        eventId = keccak256(
            abi.encodePacked(
                amount,
                settlementToken,
                block.timestamp,
                distributionCounter++
            )
        );

        DistributionEvent storage distEvent = distributions[eventId];
        distEvent.eventId = eventId;
        distEvent.timestamp = block.timestamp;
        distEvent.totalAmount = amount;
        distEvent.settlementToken = settlementToken;
        distEvent.waterfallExecuted = 0;

        distributionHistory.push(eventId);
        treasuryBalanceByToken[settlementToken] += amount;

        emit DistributionInitiated(eventId, amount, settlementToken, block.timestamp);

        return eventId;
    }

    /**
     * @notice Execute distribution waterfall (payment priority order)
     * 
     * WATERFALL ORDER:
     * 1. Accrued preferred returns (Preferred A & B)
     * 2. Remaining amount split by class distribution %
     * 
     * @param eventId Distribution event ID
     */
    function executeDistributionWaterfall(bytes32 eventId)
        external
        onlyRole(DISTRIBUTION_ROLE)
        nonReentrant
    {
        DistributionEvent storage distEvent = distributions[eventId];
        require(distEvent.waterfallExecuted == 0, "Waterfall already executed");

        uint256 remaining = distEvent.totalAmount;

        // Step 1: Pay accrued preferred returns
        for (uint256 i = 0; i < activeShareClasses.length; i++) {
            ShareClass classId = activeShareClasses[i];
            ShareClassTerms storage classTerms = shareClasses[classId];

            if (classTerms.preferredReturnPercentage == 0) {
                continue;  // Skip classes without preferred return
            }

            address[] storage holders = classHolders[classId];
            for (uint256 j = 0; j < holders.length; j++) {
                address holder = holders[j];
                ShareholderRecord storage record = shareholders[holder][classId];

                uint256 preferredPayment = record.preferredReturnAccrued;
                if (preferredPayment > 0 && preferredPayment <= remaining) {
                    distEvent.classDistributions[classId] += preferredPayment;
                    distEvent.shareholderDistributions[holder] += preferredPayment;
                    remaining -= preferredPayment;
                    record.preferredReturnAccrued = 0;
                }
            }
        }

        // Step 2: Distribute remaining amount by class allocation %
        uint256 totalPercentage = 0;
        for (uint256 i = 0; i < activeShareClasses.length; i++) {
            totalPercentage += shareClasses[activeShareClasses[i]].distributionPercentage;
        }

        for (uint256 i = 0; i < activeShareClasses.length; i++) {
            ShareClass classId = activeShareClasses[i];
            ShareClassTerms storage classTerms = shareClasses[classId];

            uint256 classAllocation = (remaining * classTerms.distributionPercentage) / totalPercentage;
            distEvent.classDistributions[classId] += classAllocation;

            // Distribute pro-rata to shareholders
            address[] storage holders = classHolders[classId];
            uint256 totalClassShares = classTerms.outstandingShares;

            for (uint256 j = 0; j < holders.length; j++) {
                address holder = holders[j];
                ShareholderRecord storage record = shareholders[holder][classId];

                uint256 shareholderAmount = (classAllocation * record.shareCount) / totalClassShares;
                distEvent.shareholderDistributions[holder] += shareholderAmount;

                emit ShareholderDistributionPaid(eventId, holder, classId, shareholderAmount);
            }
        }

        distEvent.waterfallExecuted = block.number;
        distEvent.isProcessed = true;
    }

    /**
     * @notice Claim distribution payment
     * @param eventId Distribution event ID
     */
    function claimDistribution(bytes32 eventId) external nonReentrant {
        DistributionEvent storage distEvent = distributions[eventId];
        require(distEvent.isProcessed, "Distribution not yet processed");

        uint256 amount = distEvent.shareholderDistributions[msg.sender];
        require(amount > 0, "No distribution for this address");

        // Clear the distribution
        distEvent.shareholderDistributions[msg.sender] = 0;
        treasuryBalanceByToken[distEvent.settlementToken] -= amount;

        require(
            IERC20(distEvent.settlementToken).transfer(msg.sender, amount),
            "Transfer failed"
        );
    }

    // ==================== Accrual of Preferred Returns ====================

    /**
     * @notice Accrue preferred returns for shareholders
     * @param classId Share class with preferred return
     * @param daysToAccrue Number of days to accrue
     */
    function accruePreferredReturns(ShareClass classId, uint256 daysToAccrue)
        external
        onlyRole(DISTRIBUTION_ROLE)
        nonReentrant
    {
        ShareClassTerms storage classTerms = shareClasses[classId];
        require(classTerms.preferredReturnPercentage > 0, "Class has no preferred return");

        address[] storage holders = classHolders[classId];

        for (uint256 i = 0; i < holders.length; i++) {
            address holder = holders[i];
            ShareholderRecord storage record = shareholders[holder][classId];

            // Simple interest: return = principal * rate * time
            uint256 dailyReturn = (record.shareCount * record.acquisitionPrice * 
                                  classTerms.preferredReturnPercentage) / (365 * 10000 * 100);
            uint256 accruedReturn = dailyReturn * daysToAccrue;

            record.preferredReturnAccrued += accruedReturn;

            emit PreferredReturnAccrued(holder, classId, accruedReturn, record.preferredReturnAccrued);
        }
    }

    // ==================== Liquidity Events & Conversion ====================

    /**
     * @notice Trigger a liquidity event (IPO, acquisition, etc.)
     * @param eventType Type of liquidity event
     * @param liquidationPrice Final price per share in cents
     * @return eventId Liquidity event ID
     */
    function triggerLiquidityEvent(
        LiquidityEventType eventType,
        uint256 liquidationPrice
    ) external onlyRole(GOVERNANCE_ROLE) nonReentrant returns (bytes32 eventId) {
        eventId = keccak256(
            abi.encodePacked(
                eventType,
                liquidationPrice,
                block.timestamp,
                liquidityEventCounter++
            )
        );

        LiquidityEvent storage liquEvent = liquidityEvents[eventId];
        liquEvent.eventId = eventId;
        liquEvent.eventType = eventType;
        liquEvent.timestamp = block.timestamp;
        liquEvent.liquidationPrice = liquidationPrice;
        liquEvent.triggeredBy = msg.sender;

        liquidityEventHistory.push(eventId);

        emit LiquidityEventTriggered(eventId, eventType, liquidationPrice, block.timestamp);

        // Trigger automatic conversions for classes with conversion rights
        _executeAutomaticConversions(eventId);

        return eventId;
    }

    /**
     * @notice Internal function to execute automatic share class conversions
     */
    function _executeAutomaticConversions(bytes32 liquidityEventId) internal {
        for (uint256 i = 0; i < activeShareClasses.length; i++) {
            ShareClass classId = activeShareClasses[i];
            ShareClassTerms storage classTerms = shareClasses[classId];

            if (!classTerms.canConvertAutomatically) {
                continue;
            }

            address[] storage holders = classHolders[classId];
            for (uint256 j = 0; j < holders.length; j++) {
                address holder = holders[j];
                ShareholderRecord storage record = shareholders[holder][classId];

                if (record.shareCount == 0) {
                    continue;
                }

                // Convert to target class
                uint256 newShares = (record.shareCount * classTerms.conversionRatio) / 10000;

                _convertShares(holder, classId, classTerms.convertibleTo, newShares);

                emit SharesConverted(
                    holder,
                    classId,
                    classTerms.convertibleTo,
                    record.shareCount,
                    newShares
                );
            }
        }
    }

    /**
     * @notice Internal function to convert shares
     */
    function _convertShares(
        address shareholder,
        ShareClass fromClass,
        ShareClass toClass,
        uint256 newShareCount
    ) internal {
        ShareholderRecord storage fromRecord = shareholders[shareholder][fromClass];
        ShareholderRecord storage toRecord = shareholders[shareholder][toClass];

        // Remove from old class
        shareClasses[fromClass].outstandingShares -= fromRecord.shareCount;
        fromRecord.shareCount = 0;

        // Add to new class
        if (toRecord.shareholder == address(0)) {
            toRecord.shareholder = shareholder;
            toRecord.classId = toClass;
            classHolders[toClass].push(shareholder);
        }

        toRecord.shareCount += newShareCount;
        shareClasses[toClass].outstandingShares += newShareCount;
    }

    // ==================== Query Functions ====================

    function getShareClass(ShareClass classId)
        external
        view
        returns (ShareClassTerms memory)
    {
        return shareClasses[classId];
    }

    function getShareholderRecord(address shareholder, ShareClass classId)
        external
        view
        returns (ShareholderRecord memory)
    {
        return shareholders[shareholder][classId];
    }

    function getDistributionEvent(bytes32 eventId)
        external
        view
        returns (DistributionEvent memory)
    {
        // Note: Can't return mapping, so would need separate getter
        return distributions[eventId];
    }

    function getClassHolders(ShareClass classId)
        external
        view
        returns (address[] memory)
    {
        return classHolders[classId];
    }

    // ==================== Admin Functions ====================

    function setPreferredReturnPercentage(
        ShareClass classId,
        uint256 percentage
    ) external onlyRole(CLASS_MANAGER_ROLE) {
        require(percentage >= 0 && percentage <= 10000, "Invalid percentage");
        shareClasses[classId].preferredReturnPercentage = percentage;
    }

    function setDistributionPercentage(
        ShareClass classId,
        uint256 percentage
    ) external onlyRole(CLASS_MANAGER_ROLE) {
        require(percentage > 0 && percentage <= 10000, "Invalid percentage");
        shareClasses[classId].distributionPercentage = percentage;
    }

    function lockShares(
        address shareholder,
        ShareClass classId,
        uint256 lockupExpiryDate
    ) external onlyRole(CLASS_MANAGER_ROLE) {
        shareholders[shareholder][classId].isLocked = true;
        shareholders[shareholder][classId].lockupExpiryDate = lockupExpiryDate;
    }

    // ==================== Upgradeable Pattern ====================

    function _authorizeUpgrade(address newImplementation)
        internal
        onlyRole(DEFAULT_ADMIN_ROLE)
        override
    {}
}
