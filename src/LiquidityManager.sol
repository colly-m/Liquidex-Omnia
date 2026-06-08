// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "./PoolRegistry.sol";
import "./PositionTracker.sol";
import "./AgentInterface.sol";

/*//////////////////////////////////////////////////////////////
                    EXTERNAL INTERFACES
//////////////////////////////////////////////////////////////*/

interface IAgentRequester {
    function createRequest(
        uint256 agentId,
        address receiver,
        bytes4  callbackSelector,
        bytes memory payload
    ) external returns (uint256 requestId);
    function getRequestDeposit() external view returns (uint256);
    function getRequestFee(uint256 agentId) external view returns (uint256);
}

interface IJsonApiAgent {
    function fetchUint(
        string calldata url,
        string calldata selector,
        uint8 decimals
    ) external returns (uint256);
}

contract LiquidityManager is IAgentInterface {

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOwner(address caller);
    error NotPendingOwner(address caller);
    error NotPlatform(address caller);
    error ZeroAddress();
    error ContractPaused();
    error Reentrancy();
    error InsufficientDeposit(uint256 sent, uint256 required);
    error InvalidRequest(uint256 requestId);
    error RequestAlreadyHandled(uint256 requestId);
    error RequestExpired(uint256 requestId, uint256 expiry, uint256 blockTime);
    error NoRewardsPending(address user);
    error RewardTransferFailed(address user, uint256 amount);
    error RefundFailed(address recipient, uint256 amount);
    error LengthMismatch(uint256 count1, uint256 count2);
    error EmptyRebalance();
    error NoEtherSent();
    error InvalidFee(uint256 fee, uint256 maxFee);
    error InvalidAmount();
    error TotalSharesZero();
    error NotImplemented();

    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct RequestInfo {
        bool    pending;
        bool    completed;
        uint256 result;
        uint256 timestamp;
        uint256 expiry;
        uint256 agentId;
        address token;      // associated token for price requests
    }

    struct UserRewards {
        uint256 pendingRewards;
        uint256 claimedRewards;
        uint256 lastUpdated;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant JSON_API_AGENT_ID  = 13174292974160097713;
    uint256 public constant LLM_AGENT_ID       = 13174292974160097714;
    uint256 public constant SUBCOMMITTEE_SIZE  = 3;
    uint256 public constant REWARD_BPS         = 100;      // 1% of TVL growth → reward pool
    uint256 public constant BPS_DENOMINATOR    = 10_000;
    uint256 public constant MAX_AGENT_FEE      = 1 ether;
    uint256 public constant REQUEST_TIMEOUT    = 1 hours;

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    IAgentRequester public immutable PLATFORM;
    PoolRegistry   public poolRegistry;
    IPositionTracker public positionTracker;

    address public owner;
    address public pendingOwner;
    bool    public paused;

    uint256 public totalValueLocked;
    uint256 public totalRewards;
    uint256 public lastRebalance;

    uint256 public jsonApiAgentFee;
    uint256 public llmAgentFee;

    mapping(address => uint256) public priceFeeds;
    mapping(address => uint256) public priceUpdatedAt;

    mapping(uint256 => RequestInfo) public requests;
    mapping(address => UserRewards) public userRewards;

    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED     = 2;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PoolMetricsUpdated(string indexed poolId, address tokenA, address tokenB, uint256 apy, uint256 tvl, uint256 timestamp);
    event PriceRequested(uint256 indexed requestId, string url, address indexed token, uint256 timestamp);
    event PriceReceived(uint256 indexed requestId, address indexed token, uint256 value, uint256 timestamp);
    event AIAnalysisRequested(uint256 indexed requestId, uint256 timestamp);
    event RewardsClaimed(address indexed user, uint256 amount, uint256 timestamp);
    event RewardsAdded(uint256 amount, uint256 timestamp);
    event RewardsAllocated(address indexed user, uint256 amount, uint256 timestamp);
    event Paused(uint256 timestamp);
    event Unpaused(uint256 timestamp);
    event AgentFeesUpdated(uint256 jsonApiFee, uint256 llmFee);
    event OwnershipTransferProposed(address indexed currentOwner, address indexed proposed);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event PoolRegistryUpdated(address indexed oldRegistry, address indexed newRegistry);
    event PositionTrackerUpdated(address indexed oldTracker, address indexed newTracker);
    event ExcessRefunded(address indexed recipient, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert Reentrancy();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(
        address platform_,
        address registry_,
        address payable tracker_,
        address owner_,
        uint256 jsonApiFee_,
        uint256 llmFee_
    ) {
        if (platform_ == address(0) || registry_ == address(0) ||
            tracker_  == address(0) || owner_    == address(0))
            revert ZeroAddress();
        if (jsonApiFee_ > MAX_AGENT_FEE) revert InvalidFee(jsonApiFee_, MAX_AGENT_FEE);
        if (llmFee_     > MAX_AGENT_FEE) revert InvalidFee(llmFee_,     MAX_AGENT_FEE);

        PLATFORM          = IAgentRequester(platform_);
        poolRegistry      = PoolRegistry(registry_);
        positionTracker   = IPositionTracker(tracker_);
        owner             = owner_;
        jsonApiAgentFee   = jsonApiFee_;
        llmAgentFee       = llmFee_;
        _reentrancyStatus = _NOT_ENTERED;
    }

    /*//////////////////////////////////////////////////////////////
                        POOL MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function updatePoolMetrics(
        string memory poolId,
        address tokenA,
        address tokenB,
        uint256 apy,
        uint256 tvl
    ) external onlyOwner nonReentrant whenNotPaused {
        poolRegistry.updatePoolMetrics(poolId, apy, tvl);
        uint256 oldTVL = totalValueLocked;
        totalValueLocked = poolRegistry.totalTVL();

        if (totalValueLocked > oldTVL) {
            uint256 increase   = totalValueLocked - oldTVL;
            uint256 rewardPool = (increase * REWARD_BPS) / BPS_DENOMINATOR;
            if (rewardPool > 0) {
                totalRewards += rewardPool;
                emit RewardsAdded(rewardPool, block.timestamp);
            }
        }

        emit PoolMetricsUpdated(poolId, tokenA, tokenB, apy, tvl, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                        PRICE FETCHING
    //////////////////////////////////////////////////////////////*/

    function fetchPrice(
        string memory url,
        string memory selector,
        uint8 decimals,
        address token,
        address receiver
    )
        external
        payable
        override
        nonReentrant
        whenNotPaused
        returns (uint256 requestId)
    {
        if (receiver == address(0) || token == address(0)) revert ZeroAddress();

        bytes memory payload = abi.encodeWithSelector(
            IJsonApiAgent.fetchUint.selector,
            url,
            selector,
            decimals
        );

        uint256 required = PLATFORM.getRequestDeposit() + (jsonApiAgentFee * SUBCOMMITTEE_SIZE);
        if (msg.value < required) revert InsufficientDeposit(msg.value, required);

        if (msg.value > required) {
            uint256 excess = msg.value - required;
            (bool ok, ) = payable(msg.sender).call{value: excess}("");
            if (!ok) revert RefundFailed(msg.sender, excess);
            emit ExcessRefunded(msg.sender, excess);
        }

        requestId = PLATFORM.createRequest(
            JSON_API_AGENT_ID,
            receiver,
            this.handleResponse.selector,
            payload
        );

        requests[requestId] = RequestInfo({
            pending:   true,
            completed: false,
            result:    0,
            timestamp: block.timestamp,
            expiry:    block.timestamp + REQUEST_TIMEOUT,
            agentId:   JSON_API_AGENT_ID,
            token:     token
        });

        emit PriceRequested(requestId, url, token, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                        AI REBALANCING
    //////////////////////////////////////////////////////////////*/

    function analyzeAndRebalance(address receiver)
        external
        payable
        override
        nonReentrant
        whenNotPaused
        returns (uint256 requestId)
    {
        if (receiver == address(0)) revert ZeroAddress();

        string memory prompt = _buildRebalancePrompt();

        uint256 required = PLATFORM.getRequestDeposit() + (llmAgentFee * SUBCOMMITTEE_SIZE);
        if (msg.value < required) revert InsufficientDeposit(msg.value, required);

        if (msg.value > required) {
            uint256 excess = msg.value - required;
            (bool ok, ) = payable(msg.sender).call{value: excess}("");
            if (!ok) revert RefundFailed(msg.sender, excess);
            emit ExcessRefunded(msg.sender, excess);
        }

        requestId = PLATFORM.createRequest(
            LLM_AGENT_ID,
            receiver,
            this.handleResponse.selector,
            abi.encode(prompt)
        );

        requests[requestId] = RequestInfo({
            pending:   true,
            completed: false,
            result:    0,
            timestamp: block.timestamp,
            expiry:    block.timestamp + REQUEST_TIMEOUT,
            agentId:   LLM_AGENT_ID,
            token:     address(0)
        });

        emit AIAnalysisRequested(requestId, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                        CALLBACK HANDLER
    //////////////////////////////////////////////////////////////*/

    function handleResponse(
        uint256 requestId,
        bytes[] memory results,
        uint8 status,
        bytes memory /* details */
    )
        external
        nonReentrant
    {
        if (msg.sender != address(PLATFORM)) revert NotPlatform(msg.sender);

        RequestInfo storage req = requests[requestId];
        if (!req.pending)             revert InvalidRequest(requestId);
        if (req.completed)            revert RequestAlreadyHandled(requestId);
        if (block.timestamp > req.expiry) revert RequestExpired(requestId, req.expiry, block.timestamp);

        req.pending = false;

        if (status == 1 && results.length > 0) {
            req.completed = true;

            if (req.agentId == JSON_API_AGENT_ID) {
                uint256 price = abi.decode(results[0], (uint256));
                req.result = price;
                priceFeeds[req.token]      = price;
                priceUpdatedAt[req.token]  = block.timestamp;
                emit PriceReceived(requestId, req.token, price, block.timestamp);
            }
            // LLM responses are not automatically rebalanced in this version;
            // the off-chain service can retrieve the result and call executeRebalance.
        }
    }

    /*//////////////////////////////////////////////////////////////
                        REBALANCING (STUB)
    //////////////////////////////////////////////////////////////*/

    /// @notice Owner-triggered rebalance – NOT YET IMPLEMENTED.
    ///         Will revert with `NotImplemented` until the AMM integration is completed.
    function executeRebalance(
        string[] memory /* poolIds */,
        uint256[] memory /* amounts */
    )
        external
        override
        onlyOwner
        nonReentrant
        whenNotPaused
    {
        // Update lastRebalance timestamp
        lastRebalance = block.timestamp;
        // TODO: Implement actual rebalance logic when AMM integration is complete
        // For now, we just update the timestamp to indicate a rebalance was attempted
    }

    /*//////////////////////////////////////////////////////////////
                        REWARD SYSTEM
    //////////////////////////////////////////////////////////////*/

    function addRewards() external payable onlyOwner {
        if (msg.value == 0) revert NoEtherSent();
        totalRewards += msg.value;
        emit RewardsAdded(msg.value, block.timestamp);
    }

    function claimRewards() external nonReentrant whenNotPaused {
        UserRewards storage user = userRewards[msg.sender];
        uint256 reward = user.pendingRewards;
        if (reward == 0) revert NoRewardsPending(msg.sender);

        user.pendingRewards  = 0;
        user.claimedRewards += reward;
        user.lastUpdated     = block.timestamp;

        (bool ok, ) = payable(msg.sender).call{value: reward}("");
        if (!ok) revert RewardTransferFailed(msg.sender, reward);

        emit RewardsClaimed(msg.sender, reward, block.timestamp);
    }

    function allocateRewards(address user, uint256 amount) external onlyOwner nonReentrant {
        if (user == address(0) || amount == 0) revert InvalidAmount();
        userRewards[user].pendingRewards += amount;
        userRewards[user].lastUpdated     = block.timestamp;
        emit RewardsAllocated(user, amount, block.timestamp);
    }

    /// @notice distributeRewardsToLPs is not yet implemented – it will be added in a future upgrade.
    function distributeRewardsToLPs(address[] calldata /* lps */) external onlyOwner nonReentrant {
        revert NotImplemented();
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function pause() external override onlyOwner {
        paused = true;
        emit Paused(block.timestamp);
    }

    function unpause() external override onlyOwner {
        paused = false;
        emit Unpaused(block.timestamp);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferProposed(owner, newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner(msg.sender);
        address old  = owner;
        owner        = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(old, owner);
    }

    function setAgentFees(uint256 jsonApiFee_, uint256 llmFee_) external onlyOwner {
        if (jsonApiFee_ > MAX_AGENT_FEE) revert InvalidFee(jsonApiFee_, MAX_AGENT_FEE);
        if (llmFee_     > MAX_AGENT_FEE) revert InvalidFee(llmFee_,     MAX_AGENT_FEE);
        jsonApiAgentFee = jsonApiFee_;
        llmAgentFee     = llmFee_;
        emit AgentFeesUpdated(jsonApiFee_, llmFee_);
    }

    function setPoolRegistry(address newRegistry) external onlyOwner {
        if (newRegistry == address(0)) revert ZeroAddress();
        address old  = address(poolRegistry);
        poolRegistry = PoolRegistry(newRegistry);
        emit PoolRegistryUpdated(old, newRegistry);
    }

    function setPositionTracker(address payable newTracker) external onlyOwner {
        if (newTracker == address(0)) revert ZeroAddress();
        address old     = address(positionTracker);
        positionTracker = PositionTracker(newTracker);
        emit PositionTrackerUpdated(old, newTracker);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getRequestResult(uint256 requestId) external view override returns (uint256 result, bool completed) {
        RequestInfo memory r = requests[requestId];
        return (r.result, r.completed);
    }

    function getUserRewards(address user) external view returns (uint256 pending, uint256 claimed) {
        UserRewards memory r = userRewards[user];
        return (r.pendingRewards, r.claimedRewards);
    }

    function requiredPriceDeposit() external view override returns (uint256) {
        return PLATFORM.getRequestDeposit() + (jsonApiAgentFee * SUBCOMMITTEE_SIZE);
    }

    function requiredLLMDeposit() external view override returns (uint256) {
        return PLATFORM.getRequestDeposit() + (llmAgentFee * SUBCOMMITTEE_SIZE);
    }

    function getPrice(address token) external view returns (uint256 price, uint256 updatedAt, uint256 ageSeconds) {
        price     = priceFeeds[token];
        updatedAt = priceUpdatedAt[token];
        ageSeconds = (updatedAt == 0) ? type(uint256).max : block.timestamp - updatedAt;
    }

    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    function _buildRebalancePrompt() private view returns (string memory) {
        return string(abi.encodePacked(
            "{\"action\":\"rebalance\",\"tvl\":\"",
            _uintToString(totalValueLocked),
            "\",\"timestamp\":\"",
            _uintToString(block.timestamp),
            "\"}"
        ));
    }

    function _uintToString(uint256 value) private pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp   = value;
        uint256 digits = 0;
        while (temp != 0) { unchecked { ++digits; } temp /= 10; }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            unchecked { --digits; }
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }
}