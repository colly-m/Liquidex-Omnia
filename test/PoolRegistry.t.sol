// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";
import "../src/PoolRegistry.sol";

contract PoolRegistryTest is Test {
    PoolRegistry public registry;
    address public owner = address(1);
    address public manager = address(2);

    constructor() {
        registry = new PoolRegistry(manager, owner);
    }

    function testAddPool() public {
        vm.prank(owner);
        registry.addPool("pool1", address(10), address(11));
        PoolRegistry.PoolInfo memory pool = registry.getPool("pool1");
        assert(pool.tokenA == address(10));
        assert(pool.tokenB == address(11));
        assert(pool.apy == 0);
        assert(pool.tvl == 0);
        assert(pool.active == true);
    }

    function testUpdatePoolMetrics() public {
        vm.prank(owner);
        registry.addPool("pool1", address(10), address(11));
        vm.prank(manager);
        registry.updatePoolMetrics("pool1", 100, 1000);
        
        PoolRegistry.PoolInfo memory pool = registry.getPool("pool1");
        assert(pool.apy == 100);
        assert(pool.tvl == 1000);
        assert(pool.lastUpdate > 0);
    }

    function testRemovePool() public {
        vm.prank(owner);
        registry.addPool("pool1", address(10), address(11));
        vm.prank(owner);
        registry.removePool("pool1");
        PoolRegistry.PoolInfo memory pool = registry.getPool("pool1");
        assert(pool.active == false);
    }

    function testGetAllPools() public {
        vm.prank(owner);
        registry.addPool("pool1", address(10), address(11));
        vm.prank(owner);
        registry.addPool("pool2", address(20), address(21));
        string[] memory pools = registry.getAllPools();
        assert(pools.length == 2);
    }
}