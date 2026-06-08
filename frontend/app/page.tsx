"use client";

import Link from "next/link";
import { Droplets, ArrowLeftRight, Trophy, BarChart3, Shield, Zap } from "lucide-react";

export default function Home() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center p-24">
      <div className="text-center max-w-3xl">
        <h1 className="text-5xl font-bold mb-4 bg-gradient-to-r from-blue-400 to-purple-400 bg-clip-text text-transparent">
          Liquidex-Omnia
        </h1>
        <p className="text-lg text-gray-300 mb-8">
          The next-generation AMM on Somnia Agentic L1. Provide liquidity, trade tokens, and earn rewards.
        </p>

        <div className="grid grid-cols-2 md:grid-cols-3 gap-4 mb-8">
          {[
            { name: "Dashboard", desc: "Overview & Positions", href: "/dashboard", icon: BarChart3 },
            { name: "Pools", desc: "Liquidity Pools", href: "/pools", icon: Droplets },
            { name: "Swap", desc: "Trade Tokens", href: "/swap", icon: ArrowLeftRight },
            { name: "Campaigns", desc: "Earn Rewards", href: "/campaigns", icon: Trophy },
            { name: "Analytics", desc: "View Metrics", href: "/analytics", icon: BarChart3 },
          ].map((item) => (
            <Link
              key={item.href}
              href={item.href}
              className="p-4 bg-gray-950 border border-gray-800 rounded-lg hover:bg-gray-900 transition-colors group"
            >
              <item.icon className="h-8 w-8 text-blue-400 mx-auto mb-2" />
              <div className="font-semibold">{item.name}</div>
              <div className="text-sm text-gray-400">{item.desc}</div>
            </Link>
          ))}
        </div>

        <div className="flex gap-4 justify-center">
          <Link
            href="/dashboard"
            className="px-6 py-3 bg-blue-600 text-white rounded-lg hover:bg-blue-700 transition-colors"
          >
            Launch App
          </Link>
          <Link
            href="/help"
            className="px-6 py-3 bg-gray-800 text-white rounded-lg hover:bg-gray-700 transition-colors"
          >
            Learn More
          </Link>
        </div>

        <div className="mt-12 grid grid-cols-1 md:grid-cols-3 gap-6 text-left">
          <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
            <Shield className="h-6 w-6 text-blue-400 mb-2" />
            <h3 className="font-semibold mb-1">Secure & Audited</h3>
            <p className="text-sm text-gray-400">Built with security best practices for agent-safe transactions.</p>
          </div>
          <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
            <Zap className="h-6 w-6 text-blue-400 mb-2" />
            <h3 className="font-semibold mb-1">Lightning Fast</h3>
            <p className="text-sm text-gray-400">Optimized for Somnia's high-throughput architecture.</p>
          </div>
          <div className="bg-gray-950 border border-gray-800 rounded-lg p-4">
            <Trophy className="h-6 w-6 text-blue-400 mb-2" />
            <h3 className="font-semibold mb-1">Agent-Powered</h3>
            <p className="text-sm text-gray-400">AI-driven liquidity management coming soon.</p>
          </div>
        </div>
      </div>
    </main>
  );
}