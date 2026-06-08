"use client";

import { useState, useEffect } from "react";
import { useAccount, useWriteContract, useWaitForTransactionReceipt } from "wagmi";
import { AgentRequest } from "@/types";
import { getLiquidityManager } from "@/lib/contracts";
import { ethers } from "ethers";
import { Zap, Brain, RefreshCw, CheckCircle, XCircle, Clock, BarChart3 } from "lucide-react";

const LIQUIDITY_MANAGER_ADDRESS = process.env.NEXT_PUBLIC_CONTRACT_ADDRESS || "0x4373337946F60376094553CC2339e21F18A1e6e3";

export default function AgentsPage() {
  const { address, isConnected } = useAccount();
  const [requests, setRequests] = useState<AgentRequest[]>([]);
  const [priceUrl, setPriceUrl] = useState("https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd");
  const [priceSelector, setPriceSelector] = useState("ethereum.usd");
  const [priceDecimals, setPriceDecimals] = useState(8);
  const [priceToken, setPriceToken] = useState("");
  const [requiredPriceDeposit, setRequiredPriceDeposit] = useState<bigint>(0n);
  const [requiredLLMDeposit, setRequiredLLMDeposit] = useState<bigint>(0n);
  const [totalTVL, setTotalTVL] = useState<string>("0");
  const [lastRebalance, setLastRebalance] = useState<string>("Never");
  const [isPaused, setIsPaused] = useState(false);
  const [loadingDeposits, setLoadingDeposits] = useState(true);

  const { writeContract, data: hash, isPending, error } = useWriteContract();
  const { isLoading: isConfirming } = useWaitForTransactionReceipt({ hash });

  useEffect(() => {
    if (typeof window === "undefined") return;
    
    const fetchContractState = async () => {
      try {
        const manager = getLiquidityManager();
        
        const [priceDeposit, llmDeposit, tvl, paused, rebalance] = await Promise.all([
          manager.requiredPriceDeposit(),
          manager.requiredLLMDeposit(),
          manager.totalTVL(),
          manager.paused(),
          manager.lastRebalance(),
        ]);
        
        setRequiredPriceDeposit(BigInt(priceDeposit));
        setRequiredLLMDeposit(BigInt(llmDeposit));
        setTotalTVL(ethers.formatUnits(tvl, 18));
        setIsPaused(paused);
        setLastRebalance(rebalance > 0 ? new Date(Number(rebalance) * 1000).toLocaleString() : "Never");
      } catch (error) {
        console.error("Error fetching contract state:", error);
      } finally {
        setLoadingDeposits(false);
      }
    };
    fetchContractState();
    const interval = setInterval(fetchContractState, 30000);
    return () => clearInterval(interval);
  }, []);

  const handleFetchPrice = async () => {
    if (!priceToken) return;
    try {
      writeContract({
        address: LIQUIDITY_MANAGER_ADDRESS as `0x${string}`,
        abi: [{
          name: "fetchPrice",
          type: "function",
          inputs: [
            { name: "url", type: "string" },
            { name: "selector", type: "string" },
            { name: "decimals", type: "uint8" },
            { name: "token", type: "address" },
            { name: "receiver", type: "address" }
          ],
        }],
        functionName: "fetchPrice",
        args: [priceUrl, priceSelector, priceDecimals, priceToken as `0x${string}`, address as `0x${string}`],
        value: requiredPriceDeposit,
      });
    } catch (error) {
      console.error("Error fetching price:", error);
    }
  };

  const handleAnalyzeAndRebalance = async () => {
    try {
      writeContract({
        address: LIQUIDITY_MANAGER_ADDRESS as `0x${string}`,
        abi: [{
          name: "analyzeAndRebalance",
          type: "function",
          inputs: [{ name: "receiver", type: "address" }],
        }],
        functionName: "analyzeAndRebalance",
        args: [address as `0x${string}`],
        value: requiredLLMDeposit,
      });
    } catch (error) {
      console.error("Error analyzing rebalance:", error);
    }
  };

  const StatusIcon = ({ status }: { status: AgentRequest["status"] }) => {
    switch (status) {
      case "completed": return <CheckCircle className="h-4 w-4 text-green-400" />;
      case "failed": return <XCircle className="h-4 w-4 text-red-400" />;
      case "pending": return <Clock className="h-4 w-4 text-yellow-400" />;
    }
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Agent Interactions</h1>
        <p className="text-gray-400">Interact with on-chain agents for price feeds and AI rebalancing</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
          <div className="flex items-center gap-2 mb-2">
            <Zap className="h-5 w-5 text-blue-400" />
            <span className="font-semibold">Contract Status</span>
          </div>
          <p className={`text-sm ${isPaused ? "text-red-400" : "text-green-400"}`}>
            {isPaused ? "Paused" : "Active"}
          </p>
        </div>
        <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
          <div className="flex items-center gap-2 mb-2">
            <BarChart3 className="h-5 w-5 text-purple-400" />
            <span className="font-semibold">Total TVL</span>
          </div>
          <p className="text-xl font-bold">${parseFloat(totalTVL).toLocaleString()}</p>
        </div>
        <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
          <div className="flex items-center gap-2 mb-2">
            <RefreshCw className="h-5 w-5 text-yellow-400" />
            <span className="font-semibold">Last Rebalance</span>
          </div>
          <p className="text-sm">{lastRebalance}</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div className="bg-gray-950 border border-gray-800 rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
            <Zap className="h-5 w-5 text-blue-400" /> Price Fetch Agent
          </h2>
          <div className="space-y-4">
            <div>
              <label className="block text-sm font-medium mb-2">Token Address</label>
              <input
                type="text"
                placeholder="0x..."
                value={priceToken}
                onChange={(e) => setPriceToken(e.target.value)}
                className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white placeholder-gray-500"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">API URL</label>
              <input
                type="text"
                value={priceUrl}
                onChange={(e) => setPriceUrl(e.target.value)}
                className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white text-sm"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">JSON Selector</label>
              <input
                type="text"
                value={priceSelector}
                onChange={(e) => setPriceSelector(e.target.value)}
                className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white"
              />
            </div>
            <div>
              <label className="block text-sm font-medium mb-2">Decimals</label>
              <input
                type="number"
                value={priceDecimals}
                onChange={(e) => setPriceDecimals(Number(e.target.value))}
                className="w-full px-3 py-2 bg-gray-800 border border-gray-700 rounded-lg text-white"
                min="0"
                max="18"
              />
            </div>
            <div className="text-xs text-gray-500">
              Required deposit: {loadingDeposits ? "Loading..." : `${ethers.formatEther(requiredPriceDeposit)} STT`}
            </div>
            <button
              onClick={handleFetchPrice}
              disabled={!isConnected || !priceToken || isPending}
              className="w-full py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {isPending ? (
                <>
                  <div className="animate-spin h-4 w-4 border-2 border-white border-t-transparent rounded-full" />
                  Processing...
                </>
              ) : (
                <>Fetch Price</>
              )}
            </button>
          </div>
        </div>

        <div className="bg-gray-950 border border-gray-800 rounded-lg p-6">
          <h2 className="text-xl font-semibold mb-4 flex items-center gap-2">
            <Brain className="h-5 w-5 text-purple-400" /> AI Rebalance Agent
          </h2>
          <div className="space-y-4">
            <div className="space-y-2">
              <p className="text-sm text-gray-400">
                The AI agent analyzes TVL and provides rebalancing recommendations based on current market conditions.
              </p>
              <p className="text-xs text-gray-500">
                Required deposit: {loadingDeposits ? "Loading..." : `${ethers.formatEther(requiredLLMDeposit)} STT`}
              </p>
            </div>
            <button
              onClick={handleAnalyzeAndRebalance}
              disabled={!isConnected || isPending}
              className="w-full py-2 bg-purple-600 text-white rounded-lg hover:bg-purple-700 disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2"
            >
              {isPending ? (
                <>
                  <div className="animate-spin h-4 w-4 border-2 border-white border-t-transparent rounded-full" />
                  Processing...
                </>
              ) : (
                <>Analyze & Rebalance</>
              )}
            </button>
          </div>
        </div>
      </div>

      <div className="bg-gray-950 border border-gray-800 rounded-lg p-6">
        <h2 className="text-xl font-semibold mb-4">Request History</h2>
        {requests.length === 0 ? (
          <div className="text-center py-8">
            <p className="text-gray-400">No agent requests yet</p>
          </div>
        ) : (
          <div className="space-y-3">
            {requests.map((request) => (
              <div key={request.id} className="flex items-center justify-between p-3 bg-gray-900 rounded-lg">
                <div className="flex items-center gap-3">
                  <StatusIcon status={request.status} />
                  <div>
                    <p className="font-medium capitalize">{request.type} request</p>
                    <p className="text-xs text-gray-400">
                      {new Date(request.timestamp).toLocaleString()}
                    </p>
                    {request.token && (
                      <p className="text-xs text-gray-500 font-mono">{request.token}</p>
                    )}
                  </div>
                </div>
                {request.result && (
                  <div className="text-right">
                    <p className="font-medium">{request.result}</p>
                  </div>
                )}
              </div>
            ))}
          </div>
        )}
      </div>

      {error && (
        <div className="bg-red-500/10 border border-red-500/20 rounded-lg p-4">
          <p className="text-red-400 text-sm">Error: {error.message}</p>
        </div>
      )}
    </div>
  );
}