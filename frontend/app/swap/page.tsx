"use client";

import { useState, useEffect } from "react";
import { Token, Pool } from "@/types";
import { ArrowLeftRight, Info } from "lucide-react";
import { fetchPoolsWithTokens } from "@/lib/contracts";

export default function SwapPage() {
  const [fromToken, setFromToken] = useState<Token | null>(null);
  const [toToken, setToToken] = useState<Token | null>(null);
  const [fromAmount, setFromAmount] = useState("");
  const [toAmount, setToAmount] = useState("");
  const [slippageTolerance, setSlippageTolerance] = useState("0.5");
  const [availablePools, setAvailablePools] = useState<Pool[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (typeof window === "undefined") return;
    
    const loadPools = async () => {
      try {
        const pools = await fetchPoolsWithTokens();
        setAvailablePools(pools.filter(p => p.active));
        if (pools.length > 0 && !fromToken && !toToken) {
          const firstPool = pools[0];
          setFromToken(firstPool.token0);
          setToToken(firstPool.token1);
        }
      } catch (error) {
        console.error("Error loading pools:", error);
      } finally {
        setLoading(false);
      }
    };
    loadPools();
  }, []);

  const swapTokens = () => {
    if (!fromToken || !toToken) return;
    const temp = fromToken;
    setFromToken(toToken);
    setToToken(temp);
  };

  const handleFromAmountChange = (value: string) => {
    setFromAmount(value);
    if (value) {
      const estimated = parseFloat(value) * 0.95;
      setToAmount(estimated.toString());
    } else {
      setToAmount("");
    }
  };

  const priceImpact = 0.05;
  const networkFee = 0.001;

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Swap</h1>
        <p className="text-gray-400">Trade tokens on Liquidex-Omnia</p>
      </div>

      <div className="bg-gray-950 border border-gray-800 rounded-lg p-6 space-y-4">
        <div className="flex items-center justify-between">
          <p className="text-sm text-gray-400">From</p>
          <p className="text-sm text-gray-400">Balance: {fromToken?.balance ?? "0"}</p>
        </div>
        
        <div className="flex items-center justify-between">
          <input
            type="number"
            value={fromAmount}
            onChange={(e) => handleFromAmountChange(e.target.value)}
            placeholder="0"
            className="bg-transparent text-3xl font-bold outline-none w-1/2"
          />
          <div className="flex items-center gap-2">
            <select
              value={fromToken?.symbol ?? ""}
              onChange={(e) => {
                const allTokens = availablePools.flatMap(p => [p.token0, p.token1]);
                const token = allTokens.find((t) => t.symbol === e.target.value);
                if (token) setFromToken(token);
              }}
              className="bg-gray-800 px-3 py-2 rounded-lg text-lg font-semibold appearance-none cursor-pointer"
              disabled={loading}
            >
              {availablePools.length === 0 ? (
                <option>No pools available</option>
              ) : (
                availablePools.flatMap(p => [p.token0, p.token1])
                  .filter((t, i, arr) => arr.findIndex(x => x.address === t.address) === i)
                  .map((token) => (
                    <option key={token.symbol} value={token.symbol}>
                      {token.symbol}
                    </option>
                  ))
              )}
            </select>
          </div>
        </div>

        <div className="flex justify-center -my-2">
          <button
            onClick={swapTokens}
            className="bg-gray-800 hover:bg-gray-700 rounded-lg p-2 transition-colors"
          >
            <ArrowLeftRight className="h-5 w-5" />
          </button>
        </div>

        <div className="border-t border-gray-800 pt-4">
          <div className="flex items-center justify-between">
            <p className="text-sm text-gray-400">To</p>
            <p className="text-sm text-gray-400">Balance: {toToken?.balance ?? "0"}</p>
          </div>
          
          <div className="flex items-center justify-between mt-2">
            <input
              type="number"
              value={toAmount}
              readOnly
              placeholder="0"
              className="bg-transparent text-3xl font-bold outline-none w-1/2 text-gray-400"
            />
            <select
              value={toToken?.symbol ?? ""}
              onChange={(e) => {
                const allTokens = availablePools.flatMap(p => [p.token0, p.token1]);
                const token = allTokens.find((t) => t.symbol === e.target.value);
                if (token) setToToken(token);
              }}
              className="bg-gray-800 px-3 py-2 rounded-lg text-lg font-semibold appearance-none cursor-pointer"
              disabled={loading}
            >
              {availablePools.length === 0 ? (
                <option>No pools available</option>
              ) : (
                availablePools.flatMap(p => [p.token0, p.token1])
                  .filter((t, i, arr) => arr.findIndex(x => x.address === t.address) === i)
                  .map((token) => (
                    <option key={token.symbol} value={token.symbol}>
                      {token.symbol}
                    </option>
                  ))
              )}
            </select>
          </div>
        </div>

        <div className="bg-gray-800/50 rounded-lg p-4 space-y-3">
          <div className="flex items-center justify-between">
            <div className="flex items-center gap-2">
              <Info className="h-4 w-4 text-gray-400" />
              <span className="text-sm text-gray-400">Price Impact</span>
            </div>
            <span className={priceImpact > 2 ? "text-red-400" : "text-green-400"}>
              {priceImpact.toFixed(2)}%
            </span>
          </div>
          <div className="flex items-center justify-between text-sm">
            <span className="text-gray-400">Network Fee</span>
            <span className="text-gray-300">{networkFee} ETH</span>
          </div>
          <div className="flex items-center justify-between text-sm">
            <span className="text-gray-400">Routes</span>
            <span className="text-gray-300">
              {fromToken?.symbol && toToken?.symbol 
                ? `${fromToken.symbol} → ${toToken.symbol}` 
                : "Select tokens"}
            </span>
          </div>
        </div>

        <button className="w-full py-3 bg-blue-600 text-white font-semibold rounded-lg hover:bg-blue-700 transition-colors">
          Swap
        </button>
      </div>

      <div className="text-xs text-gray-400 space-y-1">
        <p>* Transactions require wallet confirmation</p>
        <p>* Swap functionality will be enabled after contract integration</p>
      </div>
    </div>
  );
}