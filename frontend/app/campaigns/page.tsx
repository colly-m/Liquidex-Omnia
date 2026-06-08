"use client";

import { useState } from "react";
import { Campaign } from "@/types";
import { Trophy } from "lucide-react";

const mockCampaigns: Campaign[] = [
  {
    id: "camp-1",
    title: "SOMNIA Staking Rewards",
    description: "Stake SOMNIA tokens to earn ETH rewards",
    token: { symbol: "SOMNIA", name: "Somnia Token", address: "0x5678", decimals: 18, balance: "1000" },
    rewardPerBlock: "0.001",
    startDate: Date.now() - 86400000 * 2,
    endDate: Date.now() + 86400000 * 5,
    totalReward: "10000",
    stakedAmount: "500000",
  },
  {
    id: "camp-2",
    title: "Liquidity Provider Rewards",
    description: "Provide liquidity and earn extra rewards",
    token: { symbol: "USDC", name: "USD Coin", address: "0x1234", decimals: 6, balance: "10000.50" },
    rewardPerBlock: "0.01",
    startDate: Date.now() - 86400000,
    endDate: Date.now() + 86400000 * 14,
    totalReward: "50000",
    stakedAmount: "2500000",
  },
  {
    id: "camp-3",
    title: "New AMM Launch Campaign",
    description: "Be part of the first liquidity on Somnia",
    token: { symbol: "ETH", name: "Ethereum", address: "0xabcd", decimals: 18, balance: "2.5" },
    rewardPerBlock: "0.0001",
    startDate: Date.now(),
    endDate: Date.now() + 86400000 * 30,
    totalReward: "25000",
    stakedAmount: "0",
  },
];

export default function CampaignsPage() {
  const [filter, setFilter] = useState<"active" | "upcoming" | "ended">("active");

  const filteredCampaigns = mockCampaigns.filter((campaign) => {
    const now = Date.now();
    if (filter === "active") return campaign.startDate <= now && campaign.endDate > now;
    if (filter === "upcoming") return campaign.startDate > now;
    if (filter === "ended") return campaign.endDate <= now;
    return true;
  });

  const formatDate = (timestamp: number) => {
    return new Date(timestamp).toLocaleDateString("en-US", {
      month: "short",
      day: "numeric",
      year: "numeric",
    });
  };

  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Campaigns</h1>
        <p className="text-gray-400">Earn rewards by staking and providing liquidity</p>
      </div>

      <div className="flex gap-2">
        {(["active", "upcoming", "ended"] as const).map((tab) => (
          <button
            key={tab}
            onClick={() => setFilter(tab)}
            className={`px-4 py-2 rounded-lg text-sm font-medium capitalize transition-colors ${
                filter === tab
                  ? "bg-blue-600 text-white"
                  : "bg-gray-800 text-gray-400 hover:bg-gray-700"
              }`}
          >
            {tab}
          </button>
        ))}
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-6">
        {filteredCampaigns.length === 0 ? (
          <div className="col-span-2 text-center py-12">
            <Trophy className="h-12 w-12 text-gray-600 mx-auto mb-4" />
            <p className="text-gray-400">No {filter} campaigns</p>
          </div>
        ) : (
          filteredCampaigns.map((campaign) => {
            const now = Date.now();
            const isActive = campaign.startDate <= now && campaign.endDate > now;
            const isUpcoming = campaign.startDate > now;
            const progress = isActive
              ? ((now - campaign.startDate) / (campaign.endDate - campaign.startDate)) * 100
              : 0;

            return (
              <div key={campaign.id} className="bg-gray-950 border border-gray-800 rounded-lg p-6 space-y-4">
                <div className="flex items-start justify-between">
                  <div className="flex items-center gap-3">
                    <div className="w-12 h-12 bg-blue-500 rounded-full flex items-center justify-center text-white font-bold">
                      {campaign.token.symbol.slice(0, 2)}
                    </div>
                    <div>
                      <h3 className="font-semibold">{campaign.title}</h3>
                      <p className="text-sm text-gray-400">{campaign.description}</p>
                    </div>
                  </div>
                  {isActive && (
                    <span className="text-xs bg-green-500/20 text-green-400 px-2 py-1 rounded">
                      Active
                    </span>
                  )}
                  {isUpcoming && (
                    <span className="text-xs bg-yellow-500/20 text-yellow-400 px-2 py-1 rounded">
                      Upcoming
                    </span>
                  )}
                </div>

                <div className="grid grid-cols-2 gap-4 text-sm">
                  <div>
                    <p className="text-gray-400">Total Reward</p>
                    <p className="font-medium text-lg">{campaign.totalReward} {campaign.token.symbol}</p>
                  </div>
                  <div>
                    <p className="text-gray-400">Staked</p>
                    <p className="font-medium text-lg">{campaign.stakedAmount} {campaign.token.symbol}</p>
                  </div>
                  <div>
                    <p className="text-gray-400">Reward per Block</p>
                    <p className="font-medium">{campaign.rewardPerBlock} {campaign.token.symbol}</p>
                  </div>
                  <div>
                    <p className="text-gray-400">Duration</p>
                    <p className="font-medium">
                      {formatDate(campaign.startDate)} - {formatDate(campaign.endDate)}
                    </p>
                  </div>
                </div>

                {isActive && (
                  <div className="space-y-2">
                    <div className="flex justify-between text-sm">
                      <span>Progress</span>
                      <span>{Math.round(progress)}%</span>
                    </div>
                    <div className="w-full bg-gray-800 rounded-full h-2">
                      <div
                        className="bg-green-500 h-2 rounded-full transition-all"
                        style={{ width: `${Math.min(progress, 100)}%` }}
                      />
                    </div>
                  </div>
                )}

                <div className="flex gap-2 pt-2">
                  <button className="flex-1 py-2 bg-blue-600 text-white rounded-lg hover:bg-blue-700">
                    Stake
                  </button>
                  <button className="flex-1 py-2 bg-gray-800 text-white rounded-lg hover:bg-gray-700">
                    Details
                  </button>
                </div>
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}