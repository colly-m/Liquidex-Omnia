"use client";

export default function HelpPage() {
  const sections = [
    {
      title: "Getting Started",
      items: [
        {
          question: "How do I connect my wallet?",
          answer: "Click the 'Connect Wallet' button in the top right corner and select your preferred wallet (MetaMask, WalletConnect, etc.).",
        },
        {
          question: "What is liquidity providing?",
          answer: "Liquidity providing allows you to deposit token pairs into pools and earn fees from trades. You'll receive LP tokens representing your share.",
        },
      ],
    },
    {
      title: "Swap",
      items: [
        {
          question: "How do I swap tokens?",
          answer: "Navigate to the Swap page, select your input and output tokens, enter the amount, and confirm the transaction in your wallet.",
        },
        {
          question: "What is slippage tolerance?",
          answer: "Slippage is the difference between the expected price and the actual price. Set higher tolerance for volatile assets.",
        },
      ],
    },
    {
      title: "Pools",
      items: [
        {
          question: "How do I add liquidity?",
          answer: "Go to the Pools page, select a pool, click 'Add Liquidity', enter your amounts, and confirm the transaction.",
        },
        {
          question: "What is impermanent loss?",
          answer: "Impermanent loss occurs when token prices diverge. It's a natural risk of providing liquidity. Learn more about managing this risk.",
        },
      ],
    },
    {
      title: "Campaigns",
      items: [
        {
          question: "How do I earn campaign rewards?",
          answer: "Stake your LP tokens or specific tokens in active campaigns to earn additional rewards on top of trading fees.",
        },
        {
          question: "Are rewards claimable?",
          answer: "Yes, rewards are claimable once campaigns end or can be claimed periodically during active campaigns.",
        },
      ],
    },
  ];

  return (
    <div className="max-w-3xl mx-auto space-y-6">
      <div>
        <h1 className="text-3xl font-bold">Help Center</h1>
        <p className="text-gray-400">Find answers to common questions</p>
      </div>

      <div className="space-y-6">
        {sections.map((section) => (
          <div key={section.title}>
            <h2 className="text-xl font-semibold mb-4 pb-2 border-b border-gray-800">{section.title}</h2>
            <div className="space-y-4">
              {section.items.map((item) => (
                <div key={item.question} className="bg-gray-950 border border-gray-800 rounded-lg p-4">
                  <h3 className="font-medium mb-2">{item.question}</h3>
                  <p className="text-sm text-gray-400">{item.answer}</p>
                </div>
              ))}
            </div>
          </div>
        ))}
      </div>

      <div className="bg-blue-500/10 border border-blue-500/20 rounded-lg p-4 text-center">
        <p className="text-sm">Need more help? Contact support when contracts are integrated.</p>
      </div>
    </div>
  );
}