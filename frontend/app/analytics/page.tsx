"use client";

import { useState, useEffect } from "react";
import { AnalyticsData } from "@/types";
import { HelpCircle } from "lucide-react";
import { getPoolRegistry, fetchPoolsWithTokens } from "@/lib/contracts";

const Tooltip = ({ content }: { content: string }) => (
  <div className="relative group">
    <HelpCircle className="h-4 w-4 text-gray-400 hover:text-gray-200 cursor-pointer" />
    <div className="absolute right-0 top-1/2 -translate-y-1/2 bg-gray-900 border border-gray-800 rounded-lg px-3 py-2 text-xs w-48 opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none z-10">
      {content}
    </div>
  </div>
);

export default function AnalyticsPage() {
  const [timeframe, setTimeframe] = useState<"24h" | "7d" | "30d">("24h");
  const [analyticsData, setAnalyticsData] = useState<AnalyticsData | null>(null);
  const [topPools, setTopPools] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (typeof window === "undefined") return;
    
    const fetchData = async () => {
      try {
        const registry = getPoolRegistry();
        const tvl = await registry.totalTVL();
        
        const pools = await fetchPoolsWithTokens();
        const sortedPools = pools
          .filter(p => p.active && parseFloat(p.liquidity) > 0)
          .sort((a, b) => parseFloat(b.liquidity) - parseFloat(a.liquidity))
          .slice(0, 5);
        
        setAnalyticsData({
          volume24h: "0",
          volume7d: "0",
          volume30d: "0",
          fees24h: "0",
          fees7d: "0",
          fees30d: "0",
          tvl: tvl.toString(),
          priceChange24h: 0,
        });
        
        setTopPools(sortedPools.map(p => ({
          symbol: `${p.token0.symbol}/${p.token1.symbol}`,
          volume: parseFloat(p.liquidity),
          fees: "0",
          apy: p.apy,
        })));
      } catch (error) {
        console.error("Error fetching analytics:", error);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
    const interval = setInterval(fetchData, 60000);
    return () => clearInterval(interval);
  }, []);

  const data = [
    { name: "Mon", volume: 120000 },
    { name: "Tue", volume: 180000 },
    { name: "Wed", volume: 150000 },
    { name: "Thu", volume: 200000 },
    { name: "Fri", volume: 175000 },
    { name: "Sat", volume: 220000 },
    { name: "Sun", volume: 190000 },
  ];

  const maxVolume = Math.max(...data.map((d) => d.volume));
  
  if (loading || !analyticsData) {
    return (
      <div className="space-y-6">
        <h1 className="text-3xl font-bold">Analytics</h1>
        <div className="text-center py-12">
          <p className="text-gray-400">Loading analytics...</p>
        </div>
      </div>
    );
  }

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Analytics</h1>
        <p className="text-gray-400">Protocol performance and metrics</p>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
          <div className="flex items-center justify-between mb-2">
            <p className="text-sm text-gray-400">Total Value Locked</p>
            <Tooltip content="Sum of all assets in liquidity pools" />
          </div>
          <p className="text-2xl font-bold">${parseFloat(analyticsData.tvl).toLocaleString()}</p>
          <p className="text-xs text-gray-400 mt-1">+{analyticsData.tvl.toLocaleString()} STT TVL</p>
        </div>

        <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
          <div className="flex items-center justify-between mb-2">
            <p className="text-sm text-gray-400">24h Volume</p>
            <Tooltip content="Total trading volume in the last 24 hours" />
          </div>
          <p className="text-2xl font-bold">$0</p>
          <p className="text-xs text-gray-400 mt-1">Real-time updates coming soon</p>
        </div>

        <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
          <div className="flex items-center justify-between mb-2">
            <p className="text-sm text-gray-400">24h Fees</p>
            <Tooltip content="Fees generated from trades in the last 24 hours" />
          </div>
          <p className="text-2xl font-bold">$0</p>
          <p className="text-xs text-gray-400 mt-1">Real-time updates coming soon</p>
        </div>

        <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
          <div className="flex items-center justify-between mb-2">
            <p className="text-sm text-gray-400">Price Change (24h)</p>
            <Tooltip content="24-hour price change of the native token" />
          </div>
          <p className={`text-2xl font-bold ${analyticsData.priceChange24h >= 0 ? "text-green-400" : "text-red-400"}`}>
            {analyticsData.priceChange24h.toFixed(1)}%
          </p>
          <p className="text-xs text-gray-400 mt-1">SOMNIA token</p>
        </div>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
        <div className="lg:col-span-2 bg-gray-950 border border-gray-800 rounded-lg p-6">
          <div className="flex items-center justify-between mb-4">
            <h2 className="text-lg font-semibold">Volume Chart</h2>
            <div className="flex gap-1">
              {(["24h", "7d", "30d"] as const).map((t) => (
                <button
                  key={t}
                  onClick={() => setTimeframe(t)}
                  className={`px-3 py-1 text-sm rounded ${
                    timeframe === t ? "bg-blue-600 text-white" : "bg-gray-800 text-gray-400"
                  }`}
                >
                  {t}
                </button>
              ))}
            </div>
          </div>

          <div className="h-64 flex items-end justify-between gap-2">
            {data.map((item) => (
              <div key={item.name} className="flex flex-col items-center gap-2 flex-1">
                <div className="w-full bg-gray-800 rounded-t-lg transition-all hover:bg-blue-500/50" style={{ height: `${(item.volume / maxVolume) * 200}px` }} />
                <span className="text-xs text-gray-400">{item.name}</span>
              </div>
            ))}
          </div>
        </div>

        <div className="space-y-6">
          <div className="bg-gray-950 border border-gray-800 rounded-lg p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold">Top Pools</h3>
              <Tooltip content="Highest trading volume pools" />
            </div>
            <div className="space-y-3">
              {topPools.length === 0 ? (
                <p className="text-gray-400 text-sm">No pools with liquidity yet</p>
              ) : (
                topPools.map((pool) => (
                  <div key={pool.symbol} className="flex items-center justify-between">
                    <div>
                      <p className="font-medium">{pool.symbol}</p>
                      <p className="text-xs text-gray-400">{pool.apy} APY</p>
                    </div>
                    <div className="text-right text-sm">
                      <p>${pool.volume.toLocaleString()}</p>
                      <p className="text-gray-400">{pool.fees} fees</p>
                    </div>
                  </div>
                ))
              )}
            </div>
          </div>

          <div className="bg-gray-950 border border-gray-800 rounded-lg p-6">
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-semibold">Recent Trades</h3>
              <Tooltip content="Latest trades executed on the protocol" />
            </div>
            <div className="space-y-3">
              {[
                { pair: "USDC → SOMNIA", amount: "5,000 USDC", time: "2 min ago", price: "0.0005 ETH" },
                { pair: "ETH → USDC", amount: "1.2 ETH", time: "5 min ago", price: "$3,200" },
                { pair: "SOMNIA → ETH", amount: "10,000 SOMNIA", time: "8 min ago", price: "0.002 ETH" },
              ].map((trade) => (
                <div key={trade.pair} className="flex items-center justify-between text-sm">
                  <div>
                    <p>{trade.pair}</p>
                    <p className="text-xs text-gray-400">{trade.amount}</p>
                  </div>
                  <div className="text-right">
                    <p>{trade.price}</p>
                    <p className="text-gray-400">{trade.time}</p>
                  </div>
                </div>
              ))}
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}