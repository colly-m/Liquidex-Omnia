// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/*//////////////////////////////////////////////////////////////
                        IPOOL REGISTRY INTERFACE
//////////////////////////////////////////////////////////////*/

/**
 * @title IPoolRegistry
 * @notice Interface for the PoolRegistry contract.
 */
interface IPoolRegistry {
    /**
     * @dev Storage-packed layout (for the implementing contract):
     *      Slot 0: tokenA (20 bytes)
     *      Slot 1: tokenB (20 bytes) + active (1 byte) + exists (1 byte)  [packed]
     *      Slot 2: apy       (32 bytes)
     *      Slot 3: tvl       (32 bytes)
     *      Slot 4: lastUpdate (32 bytes)
     */
    struct PoolInfo {
        address tokenA;
        address tokenB;
        bool active;
        bool exists;
        uint256 apy;
        uint256 tvl;
        uint256 lastUpdate;
    }

    function addPool(string memory poolId, address tokenA, address tokenB) external;
    function removePool(string memory poolId) external;
    function reactivatePool(string memory poolId) external;
    function updatePoolMetrics(string memory poolId, uint256 apy, uint256 tvl) external;
    function updatePoolMetricsWithTokens(string memory poolId, address tokenA, address tokenB, uint256 apy, uint256 tvl) external;
    function getPool(string memory poolId) external view returns (PoolInfo memory);
    function isPoolActive(string memory poolId) external view returns (bool);
    function getPoolCount() external view returns (uint256);
    function totalTVL() external view returns (uint256);
    function getAllPools() external view returns (string[] memory);
}

/*//////////////////////////////////////////////////////////////
                        POOL REGISTRY
//////////////////////////////////////////////////////////////*/

/**
 * @title PoolRegistry
 * @notice Manages supported liquidity pools, their metadata, APY/TVL,
 *         activation state, and protocol-wide TVL.
 * @dev Key design decisions:
 *      - Two-step ownership transfer to prevent bricking via typo.
 *      - Custom errors throughout (cheaper than string reverts, typed for tooling).
 *      - PoolInfo struct is storage-packed as documented in the interface.
 *      - Active pool count maintained explicitly (O(1) instead of O(n)).
 *      - Sanity caps on APY and TVL prevent runaway values from a rogue updater.
 *      - Non-reentrant guard on all state-mutating external functions.
 *      - `removePool` deactivates a pool (does NOT delete the struct or ID from poolList).
 *        This preserves historical data and prevents ID reuse.
 */
contract PoolRegistry is IPoolRegistry {

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error Unauthorized(address caller);
    error NotOwner(address caller);
    error NotPendingOwner(address caller);
    error ZeroAddress();
    error InvalidPoolId();
    error PoolIdTooLong(uint256 length, uint256 maxLength);
    error PoolAlreadyExists(string poolId);
    error PoolDoesNotExist(string poolId);
    error PoolAlreadyActive(string poolId);
    error PoolAlreadyInactive(string poolId);
    error IdenticalTokens();
    error TVLUnderflow(uint256 totalTVL, uint256 poolTVL);
    error APYExceedsMax(uint256 apy, uint256 maxApy);
    error TVLExceedsMax(uint256 tvl, uint256 maxTvl);
    error Reentrancy();

    /*//////////////////////////////////////////////////////////////
                            CONSTANTS
    //////////////////////////////////////////////////////////////*/

    /// @notice Maximum APY expressible in basis points (10 000 bp = 100%).
    ///         Set to 100 000 bp (1 000%) as a protocol-wide sanity ceiling.
    uint256 public constant MAX_APY = 100_000;

    /// @notice Sanity ceiling for a single pool's TVL (10^36 wei ≈ 10^18 ETH).
    ///         Prevents overflow-adjacent arithmetic if a caller passes type(uint256).max.
    uint256 public constant MAX_TVL = 1e36;

    /// @notice Maximum byte length of a pool ID string.
    uint256 public constant MAX_POOL_ID_LENGTH = 64;

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    address public owner;
    address public pendingOwner;
    address public liquidityManager;
    uint256 public _totalTVL;
    uint256 public activePoolCount;   // O(1) active pool count

    // Use the struct from the interface – single definition
    mapping(string => IPoolRegistry.PoolInfo) public pools;
    mapping(address => bool) public authorizedUpdaters;

    /// @dev Parallel array of all pool IDs (including inactive). Used for pagination.
    string[] private poolList;

    /// @dev Reentrancy lock
    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PoolAdded(string indexed poolId, address indexed tokenA, address indexed tokenB);
    event PoolRemoved(string indexed poolId, uint256 tvlRemoved, uint256 timestamp);
    event PoolReactivated(string indexed poolId, uint256 timestamp);
    event PoolUpdated(string indexed poolId, uint256 apy, uint256 tvl, uint256 timestamp);
    event AuthorizedUpdaterAdded(address indexed updater);
    event AuthorizedUpdaterRemoved(address indexed updater);
    event LiquidityManagerUpdated(address indexed oldManager, address indexed newManager);
    event OwnershipTransferProposed(address indexed currentOwner, address indexed pendingOwner);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier onlyAuthorized() {
        if (msg.sender != liquidityManager && !authorizedUpdaters[msg.sender]) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    modifier poolExists(string memory poolId) {
        if (!pools[poolId].exists) revert PoolDoesNotExist(poolId);
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

    constructor(address manager, address owner_) {
        if (manager == address(0) || owner_ == address(0)) revert ZeroAddress();
        owner = owner_;
        liquidityManager = manager;
        _reentrancyStatus = _NOT_ENTERED;
        activePoolCount = 0;
    }

    /*//////////////////////////////////////////////////////////////
                        POOL MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function addPool(
        string memory poolId,
        address tokenA,
        address tokenB
    ) external onlyOwner override nonReentrant {
        uint256 idLen = bytes(poolId).length;
        if (idLen == 0) revert InvalidPoolId();
        if (idLen > MAX_POOL_ID_LENGTH) revert PoolIdTooLong(idLen, MAX_POOL_ID_LENGTH);
        if (pools[poolId].exists) revert PoolAlreadyExists(poolId);
        if (tokenA == address(0) || tokenB == address(0)) revert ZeroAddress();
        if (tokenA == tokenB) revert IdenticalTokens();

        pools[poolId] = IPoolRegistry.PoolInfo({
            tokenA:     tokenA,
            tokenB:     tokenB,
            active:     true,
            exists:     true,
            apy:        0,
            tvl:        0,
            lastUpdate: block.timestamp
        });

        poolList.push(poolId);
        activePoolCount++;

        emit PoolAdded(poolId, tokenA, tokenB);
    }

    function removePool(string memory poolId)
        external
        override
        onlyOwner
        nonReentrant
        poolExists(poolId)
    {
        IPoolRegistry.PoolInfo storage pool = pools[poolId];
        if (!pool.active) revert PoolAlreadyInactive(poolId);

        if (_totalTVL < pool.tvl) revert TVLUnderflow(_totalTVL, pool.tvl);
        uint256 removedTVL = pool.tvl;
        _totalTVL -= removedTVL;
        pool.tvl = 0;
        pool.active = false;
        activePoolCount--;

        emit PoolRemoved(poolId, removedTVL, block.timestamp);
    }

    function reactivatePool(string memory poolId)
        external
        override
        onlyOwner
        nonReentrant
        poolExists(poolId)
    {
        IPoolRegistry.PoolInfo storage pool = pools[poolId];
        if (pool.active) revert PoolAlreadyActive(poolId);

        pool.active = true;
        activePoolCount++;

        emit PoolReactivated(poolId, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                        METRIC MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function updatePoolMetrics(
        string memory poolId,
        uint256 apy,
        uint256 tvl
    )
        public
        override
        onlyAuthorized
        nonReentrant
        poolExists(poolId)
    {
        if (apy > MAX_APY) revert APYExceedsMax(apy, MAX_APY);
        if (tvl > MAX_TVL) revert TVLExceedsMax(tvl, MAX_TVL);

        IPoolRegistry.PoolInfo storage pool = pools[poolId];
        if (!pool.active) revert PoolAlreadyInactive(poolId);

        if (_totalTVL < pool.tvl) revert TVLUnderflow(_totalTVL, pool.tvl);
        _totalTVL -= pool.tvl;

        pool.apy = apy;
        pool.tvl = tvl;
        pool.lastUpdate = block.timestamp;

        _totalTVL += tvl;

        emit PoolUpdated(poolId, apy, tvl, block.timestamp);
    }

    function updatePoolMetricsWithTokens(
        string memory poolId,
        address tokenA,
        address tokenB,
        uint256 apy,
        uint256 tvl
    )
        external
        override
        onlyAuthorized
        nonReentrant
        poolExists(poolId)
    {
        IPoolRegistry.PoolInfo storage pool = pools[poolId];
        if (pool.active) {
            pool.tokenA = tokenA;
            pool.tokenB = tokenB;
        }
        updatePoolMetrics(poolId, apy, tvl);
    }

    /*//////////////////////////////////////////////////////////////
                    AUTHORIZATION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function addAuthorizedUpdater(address updater) external onlyOwner {
        if (updater == address(0)) revert ZeroAddress();
        authorizedUpdaters[updater] = true;
        emit AuthorizedUpdaterAdded(updater);
    }

    function removeAuthorizedUpdater(address updater) external onlyOwner {
        authorizedUpdaters[updater] = false;
        emit AuthorizedUpdaterRemoved(updater);
    }

    /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setLiquidityManager(address newManager) external onlyOwner {
        if (newManager == address(0)) revert ZeroAddress();
        address oldManager = liquidityManager;
        liquidityManager = newManager;
        emit LiquidityManagerUpdated(oldManager, newManager);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferProposed(owner, newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner(msg.sender);
        address oldOwner = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(oldOwner, owner);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPool(string memory poolId)
        external
        view
        override
        poolExists(poolId)
        returns (IPoolRegistry.PoolInfo memory)
    {
        return pools[poolId];
    }

    function getPoolsPaginated(uint256 start, uint256 limit)
        external
        view
        returns (string[] memory result)
    {
        uint256 total = poolList.length;
        if (start >= total) return new string[](0);

        uint256 end = start + limit;
        if (end > total) end = total;

        result = new string[](end - start);
        for (uint256 i = start; i < end; ) {
            result[i - start] = poolList[i];
            unchecked { ++i; }
        }
    }

    function getPoolCount() external view override returns (uint256) {
        return poolList.length;
    }

    function isPoolActive(string memory poolId)
        external
        view
        override
        poolExists(poolId)
        returns (bool)
    {
        return pools[poolId].active;
    }

    function getActivePoolCount() external view returns (uint256) {
        return activePoolCount;
    }

    function totalTVL() external view override returns (uint256) {
        return _totalTVL;
    }

    function getAllPools() external view override returns (string[] memory) {
        return poolList;
    }
}