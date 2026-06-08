"use client";

import { useState } from "react";
import { useAccount, useConnect, useDisconnect } from "wagmi";
import { injected } from "@wagmi/connectors";
import { Wallet, LogOut, HelpCircle } from "lucide-react";

export default function Header() {
  const { address, isConnected } = useAccount();
  const { connectAsync } = useConnect();
  const { disconnectAsync } = useDisconnect();
  const [showHelp, setShowHelp] = useState(false);

  const connectWallet = async () => {
    try {
      await connectAsync({ connector: injected() });
    } catch (error) {
      console.error("Failed to connect wallet:", error);
    }
  };

  const disconnectWallet = async () => {
    await disconnectAsync();
  };

  return (
    <header className="h-16 fixed top-0 left-0 right-0 bg-gray-950 border-b border-gray-800 z-50">
      <div className="h-full px-6 flex items-center justify-end gap-4">
        <button
          onClick={() => setShowHelp(true)}
          className="p-2 text-gray-400 hover:text-gray-200 rounded-lg hover:bg-gray-800"
          title="Help"
        >
          <HelpCircle className="h-5 w-5" />
        </button>
        
        {isConnected && address ? (
          <div className="flex items-center gap-4">
            <div className="text-right">
              <p className="text-sm font-medium">
                {address.slice(0, 6)}...{address.slice(-4)}
              </p>
              <div className="flex items-center gap-1 text-xs text-gray-400">
                <div className="w-2 h-2 bg-green-400 rounded-full" />
                Connected
              </div>
            </div>
            <button
              onClick={disconnectWallet}
              className="p-2 text-gray-400 hover:text-red-400 rounded-lg hover:bg-gray-800"
              title="Disconnect"
            >
              <LogOut className="h-5 w-5" />
            </button>
          </div>
        ) : (
          <button
            onClick={connectWallet}
            className="px-4 py-2 bg-blue-600 text-white text-sm rounded-lg hover:bg-blue-700 flex items-center gap-2"
          >
            <Wallet className="h-4 w-4" />
            Connect Wallet
          </button>
        )}
      </div>

      {showHelp && (
        <div className="fixed inset-0 bg-black/50 flex items-center justify-center z-50" onClick={() => setShowHelp(false)}>
          <div className="bg-gray-900 border border-gray-800 rounded-lg p-6 max-w-md w-full mx-4" onClick={(e) => e.stopPropagation()}>
            <h3 className="text-lg font-semibold mb-4">Getting Started</h3>
            <div className="space-y-3 text-sm">
              <div>
                <p className="font-medium">1. Connect your wallet</p>
                <p className="text-gray-400">Use the Connect Wallet button to link your Web3 wallet.</p>
              </div>
              <div>
                <p className="font-medium">2. Add liquidity</p>
                <p className="text-gray-400">Navigate to Pools and create or manage your liquidity positions.</p>
              </div>
              <div>
                <p className="font-medium">3. Trade tokens</p>
                <p className="text-gray-400">Use Swap to trade tokens with competitive pricing and low fees.</p>
              </div>
              <div>
                <p className="font-medium">4. Earn rewards</p>
                <p className="text-gray-400">Participate in campaigns to earn additional token rewards.</p>
              </div>
            </div>
            <button
              onClick={() => setShowHelp(false)}
              className="w-full mt-4 py-2 bg-gray-800 text-white rounded-lg hover:bg-gray-700"
            >
              Got it
            </button>
          </div>
        </div>
      )}
    </header>
  );
}