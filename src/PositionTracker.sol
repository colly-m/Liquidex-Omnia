// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title PositionTracker (Improved)
 * @notice Tracks LP positions per user per pool.
 *
 * Used by LiquidityManager to:
 * - Record deposits
 * - Track shares
 * - Manage withdrawals
 * - Compute LP ownership
 */
contract PositionTracker {

    struct Position {
        string poolId;       // Redundant with mapping key, kept for off-chain convenience
        uint256 amountA;
        uint256 amountB;
        uint256 shares;
        uint256 lastDeposit;
        bool exists;
    }

    address public owner;
    address public liquidityManager;
    bool private locked;

    mapping(address => bool) public authorizedCallers;
    mapping(address => mapping(string => Position)) public positions;

    mapping(string => uint256) public totalShares;
    mapping(string => uint256) public totalLiquidityA;
    mapping(string => uint256) public totalLiquidityB;

    event PositionDeposited(address indexed user, string indexed poolId,
        uint256 shares, uint256 amountA, uint256 amountB);
    event PositionWithdrawn(address indexed user, string indexed poolId,
        uint256 shares, uint256 amountA, uint256 amountB);
    event AuthorizedCallerAdded(address indexed caller);
    event AuthorizedCallerRemoved(address indexed caller);
    event LiquidityManagerUpdated(address indexed oldManager, address indexed newManager);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }

    modifier onlyAuthorized() {
        require(
            msg.sender == liquidityManager || authorizedCallers[msg.sender],
            "Not authorized"
        );
        _;
    }

    modifier nonReentrant() {
        require(!locked, "Reentrancy");
        locked = true;
        _;
        locked = false;
    }

    constructor(address manager, address owner_)
        payable
    {
        require(manager != address(0), "Invalid manager");
        owner = owner_;
        liquidityManager = manager;
    }

    /**
     * @notice Deposits liquidity into a user's position.
     *         Creates the position if it doesn't exist.
     */
    function deposit(
        address user,
        string memory poolId,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    )
        external
        onlyAuthorized
        nonReentrant
    {
        require(user != address(0), "Zero user");
        require(shares > 0, "Invalid shares");
        require(amountA > 0 || amountB > 0, "Invalid amounts");

        Position storage pos = positions[user][poolId];

        if (!pos.exists) {
            pos.poolId = poolId;
            pos.exists = true;
        }

        pos.amountA += amountA;
        pos.amountB += amountB;
        pos.shares += shares;
        pos.lastDeposit = block.timestamp;

        totalShares[poolId] += shares;
        totalLiquidityA[poolId] += amountA;
        totalLiquidityB[poolId] += amountB;

        emit PositionDeposited(user, poolId, shares, amountA, amountB);
    }

    /**
     * @notice Withdraws a portion of the user's position, maintaining the
     *         same proportion of token A and B.
     *         Reverts if shares > 0 and underflow would occur in global totals.
     */
    function withdraw(
        address user,
        string memory poolId,
        uint256 shares
    )
        external
        onlyAuthorized
        nonReentrant
    {
        require(shares > 0, "Zero shares");
        Position storage pos = positions[user][poolId];
        require(pos.exists, "No position");
        require(pos.shares >= shares, "Insufficient shares");

        uint256 amountA = (pos.amountA * shares) / pos.shares;
        uint256 amountB = (pos.amountB * shares) / pos.shares;

        // Underflow protection: ensure global totals cover the withdrawal
        require(totalLiquidityA[poolId] >= amountA, "Liquidity A underflow");
        require(totalLiquidityB[poolId] >= amountB, "Liquidity B underflow");
        require(totalShares[poolId] >= shares, "Shares underflow");

        pos.shares -= shares;
        pos.amountA -= amountA;
        pos.amountB -= amountB;

        totalShares[poolId] -= shares;
        totalLiquidityA[poolId] -= amountA;
        totalLiquidityB[poolId] -= amountB;

        if (pos.shares == 0) {
            pos.exists = false;
            // Optionally clear the poolId, but not strictly needed
            delete pos.poolId;
        }

        emit PositionWithdrawn(user, poolId, shares, amountA, amountB);
    }

    /* ---------- View functions unchanged ---------- */
    function getUserPosition(address user, string memory poolId)
        external view returns (uint256 amountA, uint256 amountB, uint256 shares)
    {
        Position memory pos = positions[user][poolId];
        return (pos.amountA, pos.amountB, pos.shares);
    }

    function getPositionFull(address user, string memory poolId)
        external view returns (Position memory)
    {
        return positions[user][poolId];
    }

    function getTotalShares(string memory poolId) external view returns (uint256) {
        return totalShares[poolId];
    }

    function getPoolLiquidity(string memory poolId) external view returns (uint256 a, uint256 b) {
        return (totalLiquidityA[poolId], totalLiquidityB[poolId]);
    }

    /* ---------- Admin functions ---------- */
    function addAuthorizedCaller(address caller) external onlyOwner {
        require(caller != address(0), "Zero address");
        authorizedCallers[caller] = true;
        emit AuthorizedCallerAdded(caller);
    }

    function removeAuthorizedCaller(address caller) external onlyOwner {
        authorizedCallers[caller] = false;
        emit AuthorizedCallerRemoved(caller);
    }

    function setLiquidityManager(address newManager) external onlyOwner {
        require(newManager != address(0), "Zero address");
        address old = liquidityManager;
        liquidityManager = newManager;
        emit LiquidityManagerUpdated(old, newManager);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Zero address");
        address old = owner;
        owner = newOwner;
        emit OwnershipTransferred(old, newOwner);
    }

    receive() external payable {}
}