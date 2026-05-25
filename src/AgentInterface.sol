// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

/**
 * @title IAgentInterface
 * @notice Interface for the LiquidityManager contract.
 *         Defines the external functions that users and other contracts can call.
 */
interface IAgentInterface {

    /**
     * @notice Fetches off-chain price data via a JSON API agent.
     * @param url       API endpoint
     * @param selector  JSON selector path
     * @param decimals  Token decimals (e.g. 18)
     * @param receiver  Address to receive the result
     * @return requestId The ID of the asynchronous request
     */
    function fetchPrice(
        string memory url,
        string memory selector,
        uint8 decimals,
        address receiver
    ) external payable returns (uint256 requestId);

    /**
     * @notice Requests AI-based strategy analysis for rebalancing.
     * @param receiver Address to receive the result
     * @return requestId The ID of the asynchronous request
     */
    function analyzeAndRebalance(
        address receiver
    ) external payable returns (uint256 requestId);

    /**
     * @notice Returns the result of a previously created request.
     * @param requestId The ID of the request
     * @return result    The uint256 result (e.g., price or recommendation)
     * @return completed Whether the request has been fulfilled
     */
    function getRequestResult(
        uint256 requestId
    ) external view returns (uint256 result, bool completed);
}