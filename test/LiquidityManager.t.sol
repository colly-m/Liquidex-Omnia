// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/LiquidityManager.sol";
import "../src/PoolRegistry.sol";
import "../src/PositionTracker.sol";

contract LiquidityManagerTest is Test {
    LiquidityManager public manager;
    PoolRegistry public registry;
    PositionTracker public tracker;
    
    address public platform = address(1);
    address public owner = address(2);

    constructor() {
        registry = new PoolRegistry(owner, owner);
        tracker = new PositionTracker(payable(owner), owner);
        manager = new LiquidityManager(platform, address(registry), payable(address(tracker)), owner);
        vm.prank(owner);
        registry.setLiquidityManager(address(manager));
    }

    function testUpdatePoolMetrics() public {
        vm.prank(owner);
        registry.addPool("pool1", address(10), address(11));
        vm.prank(owner);
        manager.updatePoolMetrics("pool1", address(10), address(11), 100, 1000);
        assert(manager.totalValueLocked() >= 1000);
    }

    function testPause() public {
        vm.prank(owner);
        manager.pause();
        assert(manager.paused() == true);
    }

    function testUnpause() public {
        vm.prank(owner);
        manager.pause();
        vm.prank(owner);
        manager.unpause();
        assert(manager.paused() == false);
    }

    function testExecuteRebalance() public {
        vm.prank(owner);
        string[] memory pools = new string[](1);
        uint256[] memory amounts = new uint256[](1);
        pools[0] = "pool1";
        amounts[0] = 100;
        manager.executeRebalance(pools, amounts);
        assert(manager.lastRebalance() > 0);
    }
}