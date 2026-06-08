// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/PositionTracker.sol";

contract PositionTrackerTest is Test {
    PositionTracker public tracker;
    address public owner = address(3);
    address public user = address(2);

    constructor() {
        tracker = new PositionTracker(owner, owner);
    }

    function testDeposit() public {
        vm.prank(owner);
        tracker.deposit(user, "pool1", 100, 200, 50);
        
        (uint256 amountA, uint256 amountB, uint256 shares) = tracker.getUserPosition(user, "pool1");
        assert(amountA == 100);
        assert(amountB == 200);
        assert(shares == 50);
        assert(tracker.getTotalShares("pool1") == 50);
    }

    function testMultipleDeposits() public {
        vm.prank(owner);
        tracker.deposit(user, "pool1", 100, 200, 50);
        vm.prank(owner);
        tracker.deposit(user, "pool1", 50, 100, 25);
        
        (uint256 amountA, uint256 amountB, uint256 shares) = tracker.getUserPosition(user, "pool1");
        assert(amountA == 150);
        assert(amountB == 300);
        assert(shares == 75);
    }

    function testWithdraw() public {
        vm.prank(owner);
        tracker.deposit(user, "pool1", 100, 200, 50);
        vm.prank(owner);
        tracker.withdraw(user, "pool1", 20);
        
        (uint256 amountA, uint256 amountB, uint256 shares) = tracker.getUserPosition(user, "pool1");
        assert(shares == 30);
        assert(tracker.getTotalShares("pool1") == 30);
    }
}