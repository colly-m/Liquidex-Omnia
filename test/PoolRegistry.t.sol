// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/PoolRegistry.sol";

contract PoolRegistryTest is Test {
    address public constant OWNER = address(2);

    function testAll() public {
        PoolRegistry registry = new PoolRegistry(OWNER, OWNER);
        
        // testAddPool
        vm.startPrank(OWNER);
        registry.addPool("pool1", address(10), address(11));
        PoolRegistry.PoolInfo memory pool = registry.getPool("pool1");
        assert(pool.tokenA == address(10));
        assert(pool.tokenB == address(11));
        assert(pool.apy == 0);
        assert(pool.tvl == 0);
        assert(pool.active == true);
        
        // testGetAllPools
        registry.addPool("pool2", address(20), address(21));
        string[] memory pools = registry.getAllPools();
        assert(pools.length == 2);
        
        // testUpdatePoolMetrics
        registry.addAuthorizedUpdater(OWNER);
        registry.updatePoolMetrics("pool1", 100, 1000);
        pool = registry.getPool("pool1");
        assert(pool.apy == 100);
        assert(pool.tvl == 1000);
        assert(pool.lastUpdate > 0);
        vm.stopPrank();
    }
}