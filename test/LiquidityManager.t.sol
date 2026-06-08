// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/LiquidityManager.sol";
import "../src/PoolRegistry.sol";
import "../src/PositionTracker.sol";

contract LiquidityManagerTest is Test {
    address public constant PLATFORM = address(1);
    address public constant OWNER = address(2);

    function testAll() public {
        vm.startPrank(OWNER);
        
        PoolRegistry registry = new PoolRegistry(OWNER, OWNER);
        PositionTracker tracker = new PositionTracker(OWNER, OWNER);
        LiquidityManager manager = new LiquidityManager(PLATFORM, address(registry), payable(address(tracker)), OWNER, 0.03 ether, 0.07 ether);
        registry.setLiquidityManager(address(manager));
        tracker.setLiquidityManager(address(manager));
        
        // testUpdatePoolMetrics
        registry.addPool("pool1", address(10), address(11));
        registry.addAuthorizedUpdater(OWNER);
        manager.updatePoolMetrics("pool1", address(10), address(11), 100, 1000);
        assert(manager.totalValueLocked() >= 1000);
        
        // testPause
        manager.pause();
        assert(manager.paused() == true);
        
        // testUnpause
        manager.unpause();
        assert(manager.paused() == false);
        
        // testExecuteRebalance
        string[] memory pools = new string[](1);
        uint256[] memory amounts = new uint256[](1);
        pools[0] = "pool1";
        amounts[0] = 100;
        manager.executeRebalance(pools, amounts);
        assert(manager.lastRebalance() > 0);
        
        vm.stopPrank();
    }
}