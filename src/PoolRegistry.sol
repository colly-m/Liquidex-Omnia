// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/*//////////////////////////////////////////////////////////////
                        POOL REGISTRY (IMPROVED)
//////////////////////////////////////////////////////////////*/

/**
 * @title PoolRegistry
 * @notice
 * Manages supported liquidity pools, their metadata, APY/TVL,
 * activation state, and protocol‑wide TVL.
 *
 */
contract PoolRegistry {

    /*//////////////////////////////////////////////////////////////
                            STRUCTS
    //////////////////////////////////////////////////////////////*/

    struct PoolInfo {
        address tokenA;
        address tokenB;
        uint256 apy;         // Annual Percentage Yield (in basis points or raw)
        uint256 tvl;         // Total Value Locked
        uint256 lastUpdate;  // Timestamp of last metrics update
        bool active;
        bool exists;
    }

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    address public owner;
    address public liquidityManager;

    uint256 public totalTVL;
    uint256 public totalActivePools;

    mapping(string => PoolInfo) public pools;
    mapping(address => bool) public authorizedUpdaters;

    string[] private poolList;
    mapping(string => uint256) private poolIndex; // poolId => index in poolList

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PoolAdded(string indexed poolId, address indexed tokenA, address indexed tokenB);
    event PoolRemoved(string indexed poolId);
    event PoolReactivated(string indexed poolId);
    event PoolUpdated(string indexed poolId, uint256 apy, uint256 tvl, uint256 timestamp);
    event AuthorizedUpdaterAdded(address indexed updater);
    event AuthorizedUpdaterRemoved(address indexed updater);
    event LiquidityManagerUpdated(address indexed oldManager, address indexed newManager);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyAuthorized() {
        require(
            msg.sender == liquidityManager || authorizedUpdaters[msg.sender],
            "Not authorized"
        );
        _;
    }

    modifier poolExists(string memory poolId) {
        require(pools[poolId].exists, "Pool does not exist");
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    /**
     * @param manager Address of the LiquidityManager that will be allowed
     *                to call `updatePoolMetrics`. Must be set correctly at
     *                deployment or via `setLiquidityManager` before use.
     */
    constructor(address manager, address owner_) {
        require(manager != address(0), "Invalid manager");
        owner = owner_;
        liquidityManager = manager;
    }

    /*//////////////////////////////////////////////////////////////
                        POOL MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function addPool(
        string memory poolId,
        address tokenA,
        address tokenB
    ) external onlyOwner {
        require(bytes(poolId).length > 0, "Invalid pool ID");
        require(!pools[poolId].exists, "Pool already exists");
        require(tokenA != address(0) && tokenB != address(0), "Zero address");
        require(tokenA != tokenB, "Identical tokens");

        pools[poolId] = PoolInfo({
            tokenA: tokenA,
            tokenB: tokenB,
            apy: 0,
            tvl: 0,
            lastUpdate: block.timestamp,
            active: true,
            exists: true
        });

        poolIndex[poolId] = poolList.length;
        poolList.push(poolId);
        totalActivePools++;

        emit PoolAdded(poolId, tokenA, tokenB);
    }

    /**
     * @notice Deactivates a pool, removes its TVL from the protocol total,
     *         and resets its stored TVL to zero to avoid stale data.
     */
    function removePool(string memory poolId)
        external
        onlyOwner
        poolExists(poolId)
    {
        PoolInfo storage pool = pools[poolId];
        require(pool.active, "Already inactive");

        // Prevent underflow and zero out pool TVL
        require(totalTVL >= pool.tvl, "TVL underflow");
        totalTVL -= pool.tvl;
        pool.tvl = 0;

        pool.active = false;
        totalActivePools--;

        emit PoolRemoved(poolId);
    }

    /**
     * @notice Reactivates a previously deactivated pool.
     *         TVL remains zero until a fresh `updatePoolMetrics` call.
     */
    function reactivatePool(string memory poolId)
        external
        onlyOwner
        poolExists(poolId)
    {
        PoolInfo storage pool = pools[poolId];
        require(!pool.active, "Already active");

        pool.active = true;
        // No TVL is added back because it was set to 0 on deactivation.
        // This avoids reintroducing stale data.
        totalActivePools++;

        emit PoolReactivated(poolId);
    }

    /*//////////////////////////////////////////////////////////////
                        METRIC MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Updates APY and TVL for an active pool.
     *         Safely adjusts protocol‑wide TVL with underflow protection.
     */
    function updatePoolMetrics(
        string memory poolId,
        uint256 apy,
        uint256 tvl
    )
        external
        onlyAuthorized
        poolExists(poolId)
    {
        PoolInfo storage pool = pools[poolId];
        require(pool.active, "Inactive pool");

        // Underflow guard: old TVL must not exceed protocol total
        require(totalTVL >= pool.tvl, "TVL underflow");
        totalTVL -= pool.tvl;

        pool.apy = apy;
        pool.tvl = tvl;
        pool.lastUpdate = block.timestamp;

        totalTVL += tvl;

        emit PoolUpdated(poolId, apy, tvl, block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                    AUTHORIZATION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function addAuthorizedUpdater(address updater) external onlyOwner {
        require(updater != address(0), "Zero address");
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
        require(newManager != address(0), "Zero address");
        address oldManager = liquidityManager;
        liquidityManager = newManager;
        emit LiquidityManagerUpdated(oldManager, newManager);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getPool(string memory poolId)
        external
        view
        poolExists(poolId)
        returns (PoolInfo memory)
    {
        return pools[poolId];
    }

    /// @notice Returns all pool IDs (caution: unbounded, use paginated version for on-chain)
    function getAllPools() external view returns (string[] memory) {
        return poolList;
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
        uint256 counter;
        for (uint256 i = start; i < end; i++) {
            result[counter] = poolList[i];
            counter++;
        }
    }

    function getPoolCount() external view returns (uint256) {
        return poolList.length;
    }

    /**
     * @notice Returns true if the pool is active. Reverts if the pool does not exist.
     */
    function isPoolActive(string memory poolId)
        external
        view
        poolExists(poolId)
        returns (bool)
    {
        return pools[poolId].active;
    }
}