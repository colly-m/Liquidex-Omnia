"use client";

import { useState, useEffect } from "react";
import { Pool } from "@/types";
import { Plus, Search, ExternalLink, Info } from "lucide-react";
import { fetchPoolsWithTokens } from "@/lib/contracts";

export default function PoolsPage() {
  const [pools, setPools] = useState<Pool[]>([]);
  const [searchTerm, setSearchTerm] = useState("");
  const [selectedPool, setSelectedPool] = useState<Pool | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (typeof window === "undefined") return;
    
    const fetchPools = async () => {
      try {
        const poolsData = await fetchPoolsWithTokens();
        setPools(poolsData);
      } catch (error) {
        console.error("Error fetching pools:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchPools();
    const interval = setInterval(fetchPools, 30000);
    return () => clearInterval(interval);
  }, []);

  const filteredPools = pools.filter(
    (pool) =>
      pool.token0.symbol.toLowerCase().includes(searchTerm.toLowerCase()) ||
      pool.token1.symbol.toLowerCase().includes(searchTerm.toLowerCase())
  );

  const calculateAPY = (pool: Pool) => {
    const feesPerYear = (parseFloat(pool.totalFees.token0) + parseFloat(pool.totalFees.token1)) * 365;
    const tvl = parseFloat(pool.liquidity) || 1;
    return tvl > 0 ? ((feesPerYear / tvl) * 100).toFixed(2) : "0";
  };

  if (loading) {
    return (
      <div className="space-y-6">
        <h1 className="text-3xl font-bold">Pools</h1>
        <div className="text-center py-12">
          <p className="text-gray-400">Loading pools...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div className="flex items-center justify-between">
        <div>
          <h1 className="text-3xl font-bold">Pools</h1>
          <p className="text-gray-400">Provide liquidity and earn fees</p>
        </div>
        <button className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center gap-2">
          <Plus className="h-4 w-4" />
          New Position
        </button>
      </div>

      <div className="relative">
        <Search className="absolute left-3 top-1/2 -translate-y-1/2 h-5 w-5 text-gray-400" />
        <input
          type="text"
          placeholder="Search pools..."
          value={searchTerm}
          onChange={(e) => setSearchTerm(e.target.value)}
          className="w-full max-w-md pl-10 pr-4 bg-gray-950 border border-gray-800 rounded-lg text-white placeholder-gray-400"
        />
      </div>

      {filteredPools.length === 0 ? (
        <div className="text-center py-12 bg-gray-950 border border-gray-800 rounded-lg">
          <p className="text-gray-400 mb-2">No pools found</p>
          <p className="text-sm text-gray-500">Create your first liquidity position to get started</p>
        </div>
      ) : (
        <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
          <div className="lg:col-span-2 space-y-4">
            {filteredPools.map((pool) => (
              <div
                key={pool.id}
                onClick={() => setSelectedPool(pool)}
                className="bg-gray-950 border border-gray-800 rounded-lg p-5 cursor-pointer hover:bg-gray-900 transition-colors"
              >
                <div className="flex items-center justify-between mb-4">
                  <div className="flex items-center gap-3">
                    <div className="flex -space-x-2">
                      <div className="w-10 h-10 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold text-sm">
                        {pool.token0.symbol.slice(0, 1)}
                      </div>
                      <div className="w-10 h-10 bg-gray-700 rounded-full flex items-center justify-center text-white font-bold text-sm -ml-4">
                        {pool.token1.symbol.slice(0, 1)}
                      </div>
                    </div>
                    <div>
                      <h3 className="font-semibold">{pool.token0.symbol}/{pool.token1.symbol}</h3>
                      <p className="text-xs text-gray-400">Fee: {pool.fee / 100}% • {calculateAPY(pool)}% APY</p>
                    </div>
                  </div>
                  <ExternalLink className="h-4 w-4 text-gray-400" />
                </div>

                <div className="grid grid-cols-2 md:grid-cols-4 gap-4 text-sm">
                  <div>
                    <p className="text-gray-400">TVL</p>
                    <p className="font-medium">${parseFloat(pool.liquidity).toLocaleString()}</p>
                  </div>
                  <div>
                    <p className="text-gray-400">Volume 24h</p>
                    <p className="font-medium">$0</p>
                  </div>
                  <div>
                    <p className="text-gray-400">Fees Earned</p>
                    <p className="font-medium">$0</p>
                  </div>
                  <div>
                    <p className="text-gray-400">Your Share</p>
                    <p className="font-medium">0.00%</p>
                  </div>
                </div>
              </div>
            ))}
          </div>

          <div className="bg-gray-950 border border-gray-800 rounded-lg p-6 space-y-4">
            <h3 className="text-lg font-semibold">Pool Details</h3>
            {selectedPool ? (
              <div className="space-y-4">
                <div className="flex items-center gap-3">
                  <div className="flex -space-x-2">
                    <div className="w-12 h-12 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold">
                      {selectedPool.token0.symbol.slice(0, 1)}
                    </div>
                    <div className="w-12 h-12 bg-gray-700 rounded-full flex items-center justify-center text-white font-bold -ml-4">
                      {selectedPool.token1.symbol.slice(0, 1)}
                    </div>
                  </div>
                  <div>
                    <p className="font-semibold">{selectedPool.token0.symbol}/{selectedPool.token1.symbol}</p>
                    <p className="text-sm text-gray-400">Fee: {selectedPool.fee / 100}% • {calculateAPY(selectedPool)}% APY</p>
                  </div>
                </div>

                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <p className="text-gray-400">TVL</p>
                    <p className="font-medium">${parseFloat(selectedPool.liquidity).toLocaleString()}</p>
                  </div>
                  <div>
                    <p className="text-gray-400">24h Volume</p>
                    <p className="font-medium">$0</p>
                  </div>
                  <div>
                    <p className="text-gray-400">Fees (24h)</p>
                    <p className="font-medium">$0</p>
                  </div>
                  <div>
                    <p className="text-gray-400">Price</p>
                    <p className="font-medium">1 {selectedPool.token1.symbol} ≈ 0.5 {selectedPool.token0.symbol}</p>
                  </div>
                </div>

                <div className="bg-gray-800/50 rounded-lg p-3">
                  <div className="flex items-center gap-2 mb-2">
                    <Info className="h-4 w-4 text-yellow-400" />
                    <span className="text-sm font-medium">Risk Warning</span>
                  </div>
                  <p className="text-xs text-gray-400">
                    Providing liquidity exposes you to impermanent loss. Make sure you understand the risks.
                  </p>
                </div>

                <div className="space-y-2">
                  <button 
                    className="w-full py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700"
                  >
                    Add Liquidity
                  </button>
                  <button className="w-full py-2 bg-gray-800 text-white rounded-lg hover:bg-gray-700">
                    Remove Liquidity
                  </button>
                </div>
              </div>
            ) : (
              <div className="text-center py-8">
                <p className="text-gray-400">Select a pool to view details</p>
                <p className="text-xs text-gray-500 mt-2">Click on a pool to manage your liquidity</p>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}