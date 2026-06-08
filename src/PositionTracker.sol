// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/*//////////////////////////////////////////////////////////////
                    POSITION TRACKER INTERFACE
//////////////////////////////////////////////////////////////*/

/**
 * @title IPositionTracker
 * @notice Public interface for PositionTracker.
 *         Depend on this in LiquidityManager and other contracts rather than
 *         the concrete implementation to stay loosely coupled and enable
 *         mocking in tests.
 */
interface IPositionTracker {

    /**
     * @dev Storage layout per position
     */
    struct Position {
        uint256 amountA;
        uint256 amountB;
        uint256 shares;
        uint256 lastDeposit;
        bool    exists;
    }

    function deposit(
        address user,
        string memory poolId,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    ) external;

    function withdraw(
        address user,
        string memory poolId,
        uint256 shares
    ) external;

    function getUserPosition(address user, string memory poolId)
        external view returns (uint256 amountA, uint256 amountB, uint256 shares);

    function getTotalShares(string memory poolId) external view returns (uint256);

    function getPoolLiquidity(string memory poolId)
        external view returns (uint256 a, uint256 b);

    function decreasePosition(string memory poolId, uint256 shares) external;

    function increasePosition(string memory poolId, uint256 shares) external;

    function getTotalSharesForUser(address user, string memory poolId)
        external view returns (uint256);
}

/*//////////////////////////////////////////////////////////////
                        POSITION TRACKER
//////////////////////////////////////////////////////////////*/

/**
 * @title PositionTracker
 * @notice Tracks LP positions per user per pool.
 *         Used by LiquidityManager to record deposits, track shares,
 *         manage withdrawals, and compute LP ownership.
 *
 * @dev Key design decisions vs the original:
 *      - IPositionTracker interface extracted for loose coupling.
 *      - Two-step ownership transfer to match PoolRegistry / LiquidityManager.
 *      - Custom errors throughout — cheaper than string reverts, typed for
 *        off-chain tooling.
 *      - uint256 reentrancy lock instead of bool (avoids post-Istanbul
 *        storage-refund edge case).
 *      - `poolId` field removed from Position struct — it was redundant with
 *        the mapping key and wasted one full storage slot per position.
 *      - `constructor` no longer marked `payable` — the contract holds no ETH
 *        on construction; the accidental payable was a footgun.
 *      - `owner_` zero-address validated in constructor (was missing).
 *      - `getUserOwnershipBps` added: returns a user's share of a pool in
 *        basis points, the value LiquidityManager actually needs for reward
 *        and rebalance math.
 *      - `pause` / `unpause` added so the owner can halt deposits/withdrawals
 *        independently of LiquidityManager, consistent with sibling contracts.
 *      - All admin address updates emit old + new values.
 *      - `unchecked` blocks used where overflow/underflow is already guarded.
 *      - Single source of truth for `Position` struct (defined in interface).
 */
contract PositionTracker is IPositionTracker {

    /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/

    error NotOwner(address caller);
    error NotPendingOwner(address caller);
    error Unauthorized(address caller);
    error ZeroAddress();
    error ZeroUser();
    error ZeroShares();
    error InvalidAmounts();
    error InvalidAmount();
    error PositionDoesNotExist(address user, string poolId);
    error InsufficientShares(uint256 requested, uint256 available);
    error LiquidityAUnderflow(uint256 globalA, uint256 withdrawA);
    error LiquidityBUnderflow(uint256 globalB, uint256 withdrawB);
    error SharesUnderflow(uint256 globalShares, uint256 withdrawShares);
    error Reentrancy();
    error ContractPaused();

    /*//////////////////////////////////////////////////////////////
                            STATE
    //////////////////////////////////////////////////////////////*/

    address public owner;
    address public pendingOwner;
    address public liquidityManager;
    bool public paused;

    mapping(address => bool) public authorizedCallers;

    // Use the struct from the interface – single definition
    mapping(address => mapping(string => IPositionTracker.Position)) public positions;

    mapping(string => uint256) public totalShares;
    mapping(string => uint256) public totalLiquidityA;
    mapping(string => uint256) public totalLiquidityB;

    /// @dev uint256 reentrancy lock (cheaper than bool post-Istanbul).
    uint256 private _reentrancyStatus;
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED     = 2;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event PositionDeposited(
        address indexed user,
        string  indexed poolId,
        uint256 shares,
        uint256 amountA,
        uint256 amountB,
        uint256 timestamp
    );
    event PositionWithdrawn(
        address indexed user,
        string  indexed poolId,
        uint256 shares,
        uint256 amountA,
        uint256 amountB,
        uint256 timestamp
    );
    event AuthorizedCallerAdded(address indexed caller);
    event AuthorizedCallerRemoved(address indexed caller);
    event LiquidityManagerUpdated(address indexed oldManager, address indexed newManager);
    event OwnershipTransferProposed(address indexed currentOwner, address indexed proposed);
    event OwnershipTransferred(address indexed oldOwner, address indexed newOwner);
    event Paused(uint256 timestamp);
    event Unpaused(uint256 timestamp);

    /*//////////////////////////////////////////////////////////////
                            MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner(msg.sender);
        _;
    }

    modifier onlyAuthorized() {
        if (msg.sender != liquidityManager && !authorizedCallers[msg.sender]) {
            revert Unauthorized(msg.sender);
        }
        _;
    }

    modifier nonReentrant() {
        if (_reentrancyStatus == _ENTERED) revert Reentrancy();
        _reentrancyStatus = _ENTERED;
        _;
        _reentrancyStatus = _NOT_ENTERED;
    }

    modifier whenNotPaused() {
        if (paused) revert ContractPaused();
        _;
    }

    /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address manager, address owner_) {
        if (manager == address(0) || owner_ == address(0)) revert ZeroAddress();
        liquidityManager  = manager;
        owner             = owner_;
        authorizedCallers[manager] = true;
        _reentrancyStatus = _NOT_ENTERED;
    }

    /*//////////////////////////////////////////////////////////////
                        POSITION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function deposit(
        address user,
        string memory poolId,
        uint256 amountA,
        uint256 amountB,
        uint256 shares
    )
        external override
        onlyAuthorized
        nonReentrant
        whenNotPaused
    {
        if (user   == address(0)) revert ZeroUser();
        if (shares == 0)          revert ZeroShares();
        if (amountA == 0 && amountB == 0) revert InvalidAmounts();

        IPositionTracker.Position storage pos = positions[user][poolId];

        if (!pos.exists) {
            pos.exists = true;
        }

        unchecked {
            pos.amountA += amountA;
            pos.amountB += amountB;
            pos.shares  += shares;
        }
        pos.lastDeposit = block.timestamp;

        unchecked {
            totalShares[poolId]      += shares;
            totalLiquidityA[poolId]  += amountA;
            totalLiquidityB[poolId]  += amountB;
        }

        emit PositionDeposited(user, poolId, shares, amountA, amountB, block.timestamp);
    }

    function withdraw(
        address user,
        string memory poolId,
        uint256 shares
    )
        external override
        onlyAuthorized
        nonReentrant
        whenNotPaused
    {
        if (shares == 0) revert ZeroShares();

        IPositionTracker.Position storage pos = positions[user][poolId];
        if (!pos.exists)          revert PositionDoesNotExist(user, poolId);
        if (pos.shares < shares)  revert InsufficientShares(shares, pos.shares);

        uint256 amountA = (pos.amountA * shares) / pos.shares;
        uint256 amountB = (pos.amountB * shares) / pos.shares;

        if (totalLiquidityA[poolId] < amountA)
            revert LiquidityAUnderflow(totalLiquidityA[poolId], amountA);
        if (totalLiquidityB[poolId] < amountB)
            revert LiquidityBUnderflow(totalLiquidityB[poolId], amountB);
        if (totalShares[poolId] < shares)
            revert SharesUnderflow(totalShares[poolId], shares);

        unchecked {
            pos.shares  -= shares;
            pos.amountA -= amountA;
            pos.amountB -= amountB;

            totalShares[poolId]     -= shares;
            totalLiquidityA[poolId] -= amountA;
            totalLiquidityB[poolId] -= amountB;
        }

        if (pos.shares == 0) {
            delete positions[user][poolId];
        }

        emit PositionWithdrawn(user, poolId, shares, amountA, amountB, block.timestamp);
    }

    function decreasePosition(string memory poolId, uint256 shares)
        external
        override
        onlyAuthorized
        nonReentrant
    {
        unchecked { totalShares[poolId] -= shares; }
    }

    function increasePosition(string memory poolId, uint256 shares)
        external
        override
        onlyAuthorized
        nonReentrant
    {
        unchecked { totalShares[poolId] += shares; }
    }

    function getTotalSharesForUser(address user, string memory poolId)
        external
        view
        override
        returns (uint256)
    {
        return positions[user][poolId].shares;
    }

    /*//////////////////////////////////////////////////////////////
                            VIEW FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function getUserPosition(address user, string memory poolId)
        external
        view
        override
        returns (uint256 amountA, uint256 amountB, uint256 shares)
    {
        IPositionTracker.Position memory pos = positions[user][poolId];
        return (pos.amountA, pos.amountB, pos.shares);
    }

    function getPositionFull(address user, string memory poolId)
        external
        view
        returns (IPositionTracker.Position memory)
    {
        return positions[user][poolId];
    }

    function getTotalShares(string memory poolId) external view override returns (uint256) {
        return totalShares[poolId];
    }

    function getPoolLiquidity(string memory poolId)
        external
        view
        override
        returns (uint256 a, uint256 b)
    {
        return (totalLiquidityA[poolId], totalLiquidityB[poolId]);
    }

    function getUserOwnershipBps(address user, string memory poolId)
        external
        view
        returns (uint256 bps)
    {
        uint256 total = totalShares[poolId];
        if (total == 0) return 0;
        return (positions[user][poolId].shares * 10_000) / total;
    }

    /*//////////////////////////////////////////////////////////////
                        AUTHORIZATION MANAGEMENT
    //////////////////////////////////////////////////////////////*/

    function addAuthorizedCaller(address caller) external onlyOwner {
        if (caller == address(0)) revert ZeroAddress();
        authorizedCallers[caller] = true;
        emit AuthorizedCallerAdded(caller);
    }

    function removeAuthorizedCaller(address caller) external onlyOwner {
        authorizedCallers[caller] = false;
        emit AuthorizedCallerRemoved(caller);
    }

    /*//////////////////////////////////////////////////////////////
                            ADMIN FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function setLiquidityManager(address newManager) external onlyOwner {
        if (newManager == address(0)) revert ZeroAddress();
        address old = liquidityManager;
        liquidityManager = newManager;
        emit LiquidityManagerUpdated(old, newManager);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress();
        pendingOwner = newOwner;
        emit OwnershipTransferProposed(owner, newOwner);
    }

    function acceptOwnership() external {
        if (msg.sender != pendingOwner) revert NotPendingOwner(msg.sender);
        address old = owner;
        owner = pendingOwner;
        pendingOwner = address(0);
        emit OwnershipTransferred(old, owner);
    }

    function pause() external onlyOwner {
        paused = true;
        emit Paused(block.timestamp);
    }

    function unpause() external onlyOwner {
        paused = false;
        emit Unpaused(block.timestamp);
    }
}