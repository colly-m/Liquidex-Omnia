"use client";

import { Pool, Position } from "@/types";
import { Plus, AlertCircle, Droplets, TrendingUp, RefreshCw } from "lucide-react";
import { fetchPoolsWithTokens, getPositionTracker, getLiquidityManager, formatToken } from "@/lib/contracts";
import { useAccount } from "wagmi";
import { useState, useEffect } from "react";
import { ethers } from "ethers";

export default function Dashboard() {
  const { address, isConnected } = useAccount();
  const [pools, setPools] = useState<Pool[]>([]);
  const [positions, setPositions] = useState<Position[]>([]);
  const [totalTVL, setTotalTVL] = useState<string>("0");
  const [pendingRewards, setPendingRewards] = useState<string>("0");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (typeof window === "undefined") return;
    
    const fetchData = async () => {
      try {
        const manager = getLiquidityManager();
        const tvl = await manager.totalTVL();
        setTotalTVL(formatToken(tvl, 18, "STT").formatted);
        
        const poolsData = await fetchPoolsWithTokens();
        setPools(poolsData);

        if (address) {
          const tracker = getPositionTracker();
          const rewards = await manager.pendingRewards(address);
          setPendingRewards(ethers.formatEther(rewards));
          
          const positionsData: Position[] = [];
          for (let i = 0; i < poolsData.length; i++) {
            const poolId = poolsData[i].id;
            try {
              const pos = await tracker.getUserPosition(address, poolId);
              if (pos.shares > 0n) {
                positionsData.push({
                  id: `${address}-${poolId}`,
                  poolId,
                  tickLower: 0,
                  tickUpper: 0,
                  liquidity: ethers.formatUnits(pos.shares, 18),
                  feeGrowthInside0Last: "0",
                  feeGrowthInside1Last: "0",
                  tokensOwed0: ethers.formatUnits(pos.amountA, 18),
                  tokensOwed1: ethers.formatUnits(pos.amountB, 18),
                });
              }
            } catch (e) {}
          }
          setPositions(positionsData);
        }
      } catch (error) {
        console.error("Error fetching data:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
    const interval = setInterval(fetchData, 30000);
    return () => clearInterval(interval);
  }, [address, isConnected]);
  const volume24h = 0;

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Dashboard</h1>
        <p className="text-gray-400">Welcome to Liquidex-Omnia, your DeFi dashboard</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
          <p className="text-sm text-gray-400">Total Value Locked</p>
          <p className="text-2xl font-bold">${parseFloat(totalTVL).toLocaleString()}</p>
          <p className="text-xs text-gray-400 mt-1">Across {pools.length} pools</p>
        </div>
        <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
          <p className="text-sm text-gray-400">Your Positions</p>
          <p className="text-2xl font-bold">{positions.length}</p>
          <p className="text-xs text-gray-400 mt-1">in {positions.length} pools</p>
        </div>
        <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
          <p className="text-sm text-gray-400">Pending Rewards</p>
          <p className="text-2xl font-bold">${parseFloat(pendingRewards).toFixed(2)}</p>
          <p className="text-xs text-gray-400 mt-1">Ready to claim</p>
        </div>
        <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
          <p className="text-sm text-gray-400">24h Volume</p>
          <p className="text-2xl font-bold">${volume24h.toLocaleString()}</p>
          <p className="text-xs text-gray-400 mt-1">Across all pools</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2">
          <h2 className="text-xl font-semibold mb-4">Your Positions</h2>
          {positions.length === 0 ? (
            <div className="text-center py-12 bg-gray-950 border border-gray-800 rounded-lg">
              <p className="text-gray-400 mb-4">No liquidity positions found</p>
              <button className="px-4 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700 flex items-center gap-2 mx-auto">
                <Plus className="h-4 w-4" />
                Create Position
              </button>
            </div>
          ) : (
            <div className="space-y-4">
              {positions.map((position) => {
                const pool = pools.find((p) => p.id === position.poolId);
                if (!pool) return null;
                return (
                  <div key={position.id} className="bg-gray-950 border border-gray-800 rounded-lg p-4">
                    <div className="flex items-center justify-between mb-3">
                      <div className="flex items-center gap-2">
                        <span className="font-semibold">{pool.token0.symbol}/{pool.token1.symbol}</span>
                        <span className="text-xs bg-gray-800 px-2 py-1 rounded">{pool.fee / 100}% fee</span>
                      </div>
                      <AlertCircle className="h-4 w-4 text-yellow-400" title="In range" />
                    </div>
                    <div className="grid grid-cols-2 gap-4 text-sm">
                      <div>
                        <p className="text-gray-400">Your Liquidity</p>
                        <p className="font-medium">${parseFloat(position.liquidity).toLocaleString()}</p>
                      </div>
                      <div>
                        <p className="text-gray-400">Fees Earned</p>
                        <p className="font-medium">${(parseFloat(position.tokensOwed0) + parseFloat(position.tokensOwed1)).toFixed(2)}</p>
                      </div>
                    </div>
                  </div>
                );
              })}
            </div>
          )}
        </div>

        <div className="space-y-6">
          <div>
            <h2 className="text-xl font-semibold mb-4">Quick Actions</h2>
            <div className="space-y-2">
              <button className="w-full py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
                Add Liquidity
              </button>
              <button className="w-full py-2 bg-gray-800 text-white rounded-lg hover:bg-gray-700">
                Remove Liquidity
              </button>
              <button className="w-full py-2 bg-gray-800 text-white rounded-lg hover:bg-gray-700">
                Collect Fees
              </button>
            </div>
          </div>

          <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
            <h3 className="font-semibold mb-3">Risk Warning</h3>
            <p className="text-xs text-gray-400">
              Providing liquidity exposes you to impermanent loss. Always research before participating.
            </p>
          </div>
        </div>
      </div>
    </div>
  );
}