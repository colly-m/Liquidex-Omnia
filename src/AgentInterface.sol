// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/*//////////////////////////////////////////////////////////////
                        AGENT INTERFACE
//////////////////////////////////////////////////////////////*/

/**
 * @title IAgentInterface
 * @notice Defines the external surface of LiquidityManager that is consumed
 *         by off-chain agents and other on-chain contracts.
 *
 * @dev Separating this interface from the concrete LiquidityManager keeps
 *      coupling loose: any contract that only needs to trigger or query agent
 *      requests imports this file rather than the full implementation.
 *
 *      Matches the error, event, and naming conventions used across
 *      IPoolRegistry, ILiquidityManager, and IPositionTracker.
 *
 * Function groups:
 *   1. Agent requests  — fetchPrice, analyzeAndRebalance
 *   2. Rebalancing     — executeRebalance
 *   3. Queries         — getRequestResult, requiredPriceDeposit,
 *                        requiredLLMDeposit
 *   4. Circuit breaker — pause, unpause
 */
interface IAgentInterface {

    /*//////////////////////////////////////////////////////////////
                            AGENT REQUESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Submits an off-chain price data request to the JSON API agent.
     * @dev    The caller must attach at least `requiredPriceDeposit()` wei.
     *         Reverts with `InsufficientDeposit` if `msg.value` is too low,
     *         or `ZeroAddress` if `receiver` is the zero address.
     * @param url       API endpoint to query (e.g. "https://api.example.com/price").
     * @param selector  JSON selector path for the target field (e.g. "data.price").
     * @param decimals  Decimal places to apply to the returned integer.
     * @param receiver  Address that will be passed to the platform as the
     *                  result recipient.
     * @return requestId Platform-assigned identifier for this request.
     *                   Pass to `getRequestResult` to poll for the outcome.
     */
    function fetchPrice(
        string memory url,
        string memory selector,
        uint8  decimals,
        address token,
        address receiver
    ) external payable returns (uint256 requestId);

    /**
     * @notice Submits an AI-based strategy analysis request to the LLM agent.
     * @dev    The caller must attach at least `requiredLLMDeposit()` wei.
     *         Reverts with `InsufficientDeposit` if `msg.value` is too low,
     *         or `ZeroAddress` if `receiver` is the zero address.
     *         The payload encodes the current protocol TVL and timestamp so
     *         the agent has context for its recommendation.
     * @param receiver  Address that will be passed to the platform as the
     *                  result recipient.
     * @return requestId Platform-assigned identifier for this request.
     *                   Pass to `getRequestResult` to poll for the outcome.
     */
    function analyzeAndRebalance(address receiver) external payable returns (uint256 requestId);

    /*//////////////////////////////////////////////////////////////
                            REBALANCING
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes a liquidity rebalance across one or more pools.
     * @dev    Reverts with `LengthMismatch` if array lengths differ,
     *         `EmptyRebalance` if both arrays are empty, or `ContractPaused`
     *         if the contract is halted.
     *         Only callable by the contract owner.
     * @param poolIds Ordered list of pool identifiers to rebalance.
     * @param amounts Corresponding amounts (wei) to move per pool.
     */
function executeRebalance(
        string[] memory poolIds,
        uint256[] memory amounts
    ) external;

    function getRequestResult(uint256 requestId) external view returns (uint256 result, bool completed);

    function requiredPriceDeposit() external view returns (uint256);

    function requiredLLMDeposit() external view returns (uint256);

    function pause() external;

    function unpause() external;
}
