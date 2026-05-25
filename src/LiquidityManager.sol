// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/*//////////////////////////////////////////////////////////////
                            IMPORTS
//////////////////////////////////////////////////////////////*/

import "./PoolRegistry.sol";
import "./PositionTracker.sol";
import "./AgentInterface.sol";

/*//////////////////////////////////////////////////////////////
                        LIQUIDITY MANAGER (IMPROVED)
//////////////////////////////////////////////////////////////*/

/**
 * @title LiquidityManager
 * @notice
 * Manages pool metrics, AI-powered analysis, reward distribution, and
 * liquidity rebalancing. Integrates with off‑chain agents via a request
 * platform.
 */

contract LiquidityManager is IAgentInterface {

    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct UserRewards {
        uint256 pendingRewards;
        uint256 claimedRewards;
        uint256 lastUpdated;
    }

    struct RequestInfo {
        bool pending;
        bool completed;
        uint256 result;
        uint256 timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    IAgentRequester public immutable PLATFORM;
    PoolRegistry public poolRegistry;
    PositionTracker public positionTracker;

    address public owner;
    bool public paused;
    bool private locked;

    uint256 public totalValueLocked;
    uint256 public totalRewards;
    uint256 public lastRebalance;

    mapping(string => uint256) public poolTVL;
    mapping(uint256 => RequestInfo) public requests;
    mapping(address => UserRewards) public userRewards;

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    uint256 public constant JSON_API_AGENT_ID = 13174292974160097713;
    uint256 public constant LLM_AGENT_ID      = 13174292974160097714;
    uint256 public constant SUBCOMMITTEE_SIZE = 3;
    uint256 public constant REWARD_BPS        = 100;
    uint256 public constant BPS_DENOMINATOR   = 10_000;

    /// @dev Default extra deposit per subcommittee member (configurable)
    uint256 public jsonApiAgentFee = 0.03 ether;
    uint256 public llmAgentFee     = 0.07 ether;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PoolUpdated(string indexed poolId, address tokenA, address tokenB,
        uint256 apy, uint256 tvl);
    event PriceRequested(uint256 indexed requestId, string url);
    event PriceReceived(uint256 indexed requestId, uint256 value);
    event AIAnalysisRequested(uint256 indexed requestId);
    event RebalanceExecuted(string[] poolIds, uint256[] amounts, uint256 timestamp);
    event RewardsClaimed(address indexed user, uint256 amount);
    event RewardsAdded(uint256 amount);
    event Paused(bool status);
    event AgentFeeUpdated(uint256 jsonApiFee, uint256 llmFee);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "Contract paused");
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrancy");
        locked = true;
        _;
        locked = false;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param platform_ Address of the agent request platform.
     * @param registry_ Address of the PoolRegistry (must have this contract set as manager).
     * @param tracker_  Address of the PositionTracker (must have this contract set as manager).
     */
    constructor(address platform_, address registry_, address payable tracker_, address owner_) {
        require(platform_ != address(0), "Invalid platform");
        require(registry_ != address(0), "Invalid registry");
        require(tracker_  != address(0), "Invalid tracker");

        PLATFORM = IAgentRequester(platform_);
        poolRegistry = PoolRegistry(registry_);
        positionTracker = PositionTracker(tracker_);

        owner = owner_;
    }

    /*//////////////////////////////////////////////////////////////
                        POOL MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates liquidity pool metrics.
     *
     * Improvements:
     * - Underflow protection when adjusting TVL
     * - Calls the improved PoolRegistry (which also has its own underflow check)
     */
    function updatePoolMetrics(
        string memory poolId,
        address tokenA,
        address tokenB,
        uint256 apy,
        uint256 tvl
    ) external onlyOwner {
        require(tvl > 0, "Invalid TVL");
        require(poolTVL[poolId] <= totalValueLocked, "TVL underflow");

        // Subtract old TVL safely
        totalValueLocked -= poolTVL[poolId];

        poolTVL[poolId] = tvl;
        totalValueLocked += tvl;

        poolRegistry.updatePoolMetrics(poolId, apy, tvl);

        emit PoolUpdated(poolId, tokenA, tokenB, apy, tvl);
    }

    /*//////////////////////////////////////////////////////////////
                        PRICE FETCHING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Fetches off‑chain price data.
     * @param url       The API endpoint.
     * @param selector  JSON selector path.
     * @param decimals  Token decimals (e.g. 18 for ETH).
     * @param receiver  Address that will receive the result.
     */
    function fetchPrice(
        string memory url,
        string memory selector,
        uint8 decimals,
        address receiver
    )
        external
        payable
        whenNotPaused
        returns (uint256 requestId)
    {
        bytes memory payload = abi.encodeWithSelector(
            IJsonApiAgent.fetchUint.selector,
            url,
            selector,
            decimals
        );

        uint256 deposit = PLATFORM.getRequestDeposit() +
            (jsonApiAgentFee * SUBCOMMITTEE_SIZE);

        require(msg.value >= deposit, "Insufficient deposit");

        requestId = PLATFORM.createRequest(
            JSON_API_AGENT_ID,
            receiver,
            this.handleResponse.selector,
            payload
        );

        requests[requestId] = RequestInfo({
            pending: true,
            completed: false,
            result: 0,
            timestamp: block.timestamp
        });

        emit PriceRequested(requestId, url);
    }

    /*//////////////////////////////////////////////////////////////
                        AI REBALANCING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Requests AI-based strategy analysis.
     */
    function analyzeAndRebalance(address receiver)
        external
        payable
        whenNotPaused
        returns (uint256 requestId)
    {
        bytes memory prompt = abi.encodePacked(
            "{",
                "\"action\":\"rebalance\",",
                "\"tvl\":\"", uintToString(totalValueLocked), "\",",
                "\"timestamp\":\"", uintToString(block.timestamp), "\"",
            "}"
        );

        uint256 deposit = PLATFORM.getRequestDeposit() +
            (llmAgentFee * SUBCOMMITTEE_SIZE);

        require(msg.value >= deposit, "Insufficient deposit");

        requestId = PLATFORM.createRequest(
            LLM_AGENT_ID,
            receiver,
            this.handleResponse.selector,
            prompt
        );

        requests[requestId] = RequestInfo({
            pending: true,
            completed: false,
            result: 0,
            timestamp: block.timestamp
        });

        emit AIAnalysisRequested(requestId);
    }

    /*//////////////////////////////////////////////////////////////
                        CALLBACK HANDLER
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Handles asynchronous agent responses.
     *         Now protected against reentrancy.
     */
    function handleResponse(
        uint256 requestId,
        bytes[] memory results,
        uint8 status,
        bytes memory details
    )
        external
        nonReentrant
    {
        require(msg.sender == address(PLATFORM), "Only platform");

        RequestInfo storage request = requests[requestId];
        require(request.pending, "Invalid request");

        request.pending = false;

        if (status == 1 && results.length > 0) {
            uint256 value = abi.decode(results[0], (uint256));
            request.result = value;
            request.completed = true;

            emit PriceReceived(requestId, value);
        }
    }

    /*//////////////////////////////////////////////////////////////
                        REBALANCING LOGIC
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes liquidity rebalance.
     *
     * Future upgrade: integrate with AMMs, swap routing, etc.
     * Currently a placeholder that records the action.
     */
    function executeRebalance(
        string[] memory poolIds,
        uint256[] memory amounts
    )
        external
        onlyOwner
        whenNotPaused
    {
        require(poolIds.length == amounts.length, "Length mismatch");
        require(poolIds.length > 0, "Empty rebalance");

        // Placeholder: actual withdraw/swap/deposit logic using PositionTracker
        // and pool contracts would go here.

        lastRebalance = block.timestamp;

        emit RebalanceExecuted(poolIds, amounts, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                        REWARD SYSTEM
    //////////////////////////////////////////////////////////////*/

    function addRewards() external payable onlyOwner {
        require(msg.value > 0, "No rewards");
        totalRewards += msg.value;
        emit RewardsAdded(msg.value);
    }

    /**
     * @notice Claims user rewards with reentrancy protection.
     *         `lastUpdated` is now set to current time.
     */
    function claimRewards() external nonReentrant whenNotPaused {
        UserRewards storage user = userRewards[msg.sender];
        uint256 reward = user.pendingRewards;
        require(reward > 0, "No rewards");

        user.pendingRewards = 0;
        user.claimedRewards += reward;
        user.lastUpdated = block.timestamp;

        payable(msg.sender).transfer(reward);

        emit RewardsClaimed(msg.sender, reward);
    }

    /**
     * @notice Allocates rewards to a user.
     *         `lastUpdated` timestamp is refreshed.
     */
    function allocateRewards(address user, uint256 amount) external onlyOwner {
        require(user != address(0), "Zero address");
        require(amount > 0, "Invalid amount");

        UserRewards storage u = userRewards[user];
        u.pendingRewards += amount;
        u.lastUpdated = block.timestamp;
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN
    //////////////////////////////////////////////////////////////*/

    function pause() external onlyOwner {
        paused = true;
        emit Paused(true);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Paused(false);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        owner = newOwner;
    }

    /**
     * @notice Adjusts the per‑agent fees for JSON API and LLM requests.
     */
    function setAgentFees(uint256 _jsonApiFee, uint256 _llmFee) external onlyOwner {
        jsonApiAgentFee = _jsonApiFee;
        llmAgentFee     = _llmFee;
        emit AgentFeeUpdated(_jsonApiFee, _llmFee);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEWS
    //////////////////////////////////////////////////////////////*/

    function getRequestResult(uint256 requestId)
        external view returns (uint256 result, bool completed)
    {
        RequestInfo memory request = requests[requestId];
        return (request.result, request.completed);
    }

    function getUserRewards(address user)
        external view returns (uint256 pending, uint256 claimed)
    {
        UserRewards memory rewards = userRewards[user];
        return (rewards.pendingRewards, rewards.claimedRewards);
    }

    /*//////////////////////////////////////////////////////////////
                        INTERNAL HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Converts uint256 to string (could be replaced with OZ's Strings library)
     */
    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 10;
        }
        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + (value % 10)));
            value /= 10;
        }
        return string(buffer);
    }

    /*//////////////////////////////////////////////////////////////
                        RECEIVE ETHER
    //////////////////////////////////////////////////////////////*/

    receive() external payable {}
}

/*//////////////////////////////////////////////////////////////
                        AGENT INTERFACES
//////////////////////////////////////////////////////////////*/

interface IAgentRequester {
    function createRequest(
        uint256 agentId,
        address receiver,
        bytes4 callbackSelector,
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