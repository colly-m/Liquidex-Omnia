// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console2} from "lib/forge-std/src/Script.sol";
import {LiquidityManager} from "../src/LiquidityManager.sol";
import {PoolRegistry}      from "../src/PoolRegistry.sol";
import {PositionTracker}   from "../src/PositionTracker.sol";

/**
 * @title  DeployScript
 * @notice Deploys PoolRegistry, PositionTracker, and LiquidityManager in the
 *         correct order and wires them together atomically inside a single
 *         broadcast session.
 *
 * @dev    Deployment order matters:
 *           1. PoolRegistry    – needs a placeholder manager (deployer)
 *           2. PositionTracker – same placeholder pattern
 *           3. LiquidityManager – receives registry & tracker addresses
 *           4. Wire: setLiquidityManager on registry & tracker
 *           5. (Optional) Transfer ownership to a final multisig
 *
 *         Configurable via environment variables:
 *           - DEPLOYER_ADDRESS : address that signs the deployment tx
 *           - PLATFORM_ADDRESS : agent request platform (must be set)
 *           - FINAL_OWNER      : (optional) if set, ownership is transferred
 *                                after deployment (e.g., a multisig)
 *           - JSON_API_FEE     : fee for JSON API agent (in wei)
 *           - LLM_FEE          : fee for LLM agent (in wei)
 */
contract DeployScript is Script {

    struct Deployment {
        address manager;
        address registry;
        address tracker;
    }

    function run() public returns (Deployment memory deployment) {
        // ---------------------------------------------------------------------
        // Configuration – read from environment or fallback to safe defaults
        // ---------------------------------------------------------------------

        address platform = vm.envAddress("PLATFORM_ADDRESS");
        require(platform != address(0), "Deploy: PLATFORM_ADDRESS not set");

        address deployer = vm.envOr("DEPLOYER_ADDRESS", msg.sender);
        require(deployer != address(0), "Deploy: deployer is zero address");

        // Optional final owner (if different from deployer)
        address finalOwner = vm.envOr("FINAL_OWNER", deployer);

        uint256 jsonApiAgentFee = vm.envUint("JSON_API_FEE");
        if (jsonApiAgentFee == 0) jsonApiAgentFee = 0.03 ether;
        uint256 llmAgentFee     = vm.envUint("LLM_FEE");
        if (llmAgentFee == 0) llmAgentFee = 0.07 ether;

        // ---------------------------------------------------------------------
        // Pre-flight assertions
        // ---------------------------------------------------------------------

        // Access MAX_AGENT_FEE from the contract we are about to deploy
        uint256 maxFee = 1 ether;  // MAX_AGENT_FEE = 1 ether
        require(jsonApiAgentFee <= maxFee, "Deploy: JSON API fee exceeds MAX_AGENT_FEE");
        require(llmAgentFee <= maxFee,     "Deploy: LLM fee exceeds MAX_AGENT_FEE");

        // Basic sanity: platform should be a contract (has code)
        uint256 platformCodeSize;
        assembly { platformCodeSize := extcodesize(platform) }
        require(platformCodeSize > 0, "Deploy: PLATFORM_ADDRESS is not a contract");

        // ---------------------------------------------------------------------
        // Broadcast deployment
        // ---------------------------------------------------------------------

        vm.startBroadcast(deployer);

        // 1. PoolRegistry (temporary manager = deployer)
        PoolRegistry registry = new PoolRegistry(deployer, deployer);

        // 2. PositionTracker (temporary manager = deployer)
        PositionTracker tracker = new PositionTracker(deployer, deployer);

        // 3. LiquidityManager (now with real registry & tracker)
        LiquidityManager manager = new LiquidityManager(
            platform,
            address(registry),
            payable(address(tracker)),
            deployer,               // initial owner
            jsonApiAgentFee,
            llmAgentFee
        );

        // 4. Wire: set the real manager on registry and tracker
        registry.setLiquidityManager(address(manager));
        tracker.setLiquidityManager(address(manager));

        // 5. (Optional) Transfer ownership to finalOwner if different from deployer
        if (finalOwner != deployer) {
            registry.transferOwnership(finalOwner);
            tracker.transferOwnership(finalOwner);
            manager.transferOwnership(finalOwner);

            // Final owner must call acceptOwnership() on each contract.
            // Log a reminder.
            console2.log("=== Ownership transfer initiated ===");
            console2.log("registry.transferOwnership(%s)", finalOwner);
            console2.log("tracker.transferOwnership(%s)", finalOwner);
            console2.log("manager.transferOwnership(%s)", finalOwner);
            console2.log("Accept ownership via acceptOwnership() on each contract.");
        }

        vm.stopBroadcast();

        // ---------------------------------------------------------------------
        // Post-deployment verification (eth_call, no gas cost)
        // ---------------------------------------------------------------------

        require(
            registry.liquidityManager() == address(manager),
            "Deploy: registry liquidityManager mismatch"
        );
        require(
            tracker.liquidityManager() == address(manager),
            "Deploy: tracker liquidityManager mismatch"
        );
        require(
            address(manager.poolRegistry()) == address(registry),
            "Deploy: manager poolRegistry mismatch"
        );
        require(
            address(manager.positionTracker()) == address(tracker),
            "Deploy: manager positionTracker mismatch"
        );

        address currentOwner = finalOwner != deployer ? deployer : finalOwner;
        require(registry.owner() == currentOwner, "Deploy: registry owner mismatch");
        require(tracker.owner() == currentOwner, "Deploy: tracker owner mismatch");
        require(manager.owner() == currentOwner, "Deploy: manager owner mismatch");

        // ---------------------------------------------------------------------
        // Log deployment summary
        // ---------------------------------------------------------------------

        console2.log("\n=== Deployment complete ===");
        console2.log("PoolRegistry     :", address(registry));
        console2.log("PositionTracker  :", address(tracker));
        console2.log("LiquidityManager :", address(manager));
        console2.log("Owner            :", currentOwner);
        console2.log("Platform         :", platform);
        console2.log("JSON API fee     :", jsonApiAgentFee);
        console2.log("LLM fee          :", llmAgentFee);

        if (finalOwner != deployer) {
            console2.log("\\n WARNING: Ownership transfer pending - final owner must call acceptOwnership()");
        }

        deployment = Deployment({
            manager:  address(manager),
            registry: address(registry),
            tracker:  address(tracker)
        });
    }
}