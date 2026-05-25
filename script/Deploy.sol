// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "../src/LiquidityManager.sol";
import "../src/PoolRegistry.sol";
import "../src/PositionTracker.sol";

contract DeployScript {
    function deploy() public returns (address manager, address registry, address tracker) {
        address platform = 0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776;
        address owner = msg.sender;
        
        PoolRegistry reg = new PoolRegistry(msg.sender, owner);
        PositionTracker trac = new PositionTracker(payable(msg.sender), owner);
        LiquidityManager man = new LiquidityManager(platform, address(reg), payable(address(trac)), owner);
        
        return (address(man), address(reg), address(trac));
    }
}