# Liquidex-Omnia

Automated Liquidity Management dApp on Somnia Agentic L1

## Status

**Phase 1-4 Partially Complete** ✅
- Smart contracts compiled with Foundry
- Network configuration set for Somnia Testnet (50312)
- Agent integration implemented using Somnia's default agents
- All 11 unit tests passing
- Frontend scaffold created with Next.js 15
- Ethers.js contract integration complete

**Phase 5-7 Partially Underway** ⏳
- ✅ Smart contracts deployed to Somnia Testnet (50312)
- ✅ Frontend scaffold created with Next.js 15
- ✅ Ethers.js contract integration complete
- ✅ Dashboard page with live TVL data
- ✅ Pools page with on-chain pool data
- Frontend not connected to deployed contracts
- Missing agent directory and Wagmi integration

## Missing Components Summary

| Component | Phase | Status |
|-----------|-------|--------|
| Agent directory (AI model definitions) | 1 | MISSING |
| Wagmi frontend dependency | 1 | MISSING |
| WebSocket connections | 4 | MISSING |
| `.env.local` contract address | 5 | EMPTY |
| Testnet deployment | 5 | NOT DEPLOYED |
| Agent invocation testing | 5 | BLOCKED |
| Security audit | 5 | MISSING |
| Mainnet deployment | 6 | BLOCKED |
| Documentation | 6 | MISSING |
| Monitoring setup | 6 | MISSING |
| Community engagement | 7 | MISSING |
| Protocol improvements | 7 | MISSING |

## Quick Start

```bash
# Install all dependencies (root directory)
npm install

# Smart Contracts
# Build contracts
npm run foundry

# Run tests
npm run test

# Frontend
npm run frontend:dev
```

## Project Structure

```
liquidex-omnia/
├── src/                      # Solidity contracts
│   ├── LiquidityManager.sol  # Main contract
│   ├── PoolRegistry.sol      # Pool tracking
│   ├── PositionTracker.sol   # User positions
│   └── AgentInterface.sol    # Agent interfaces
├── script/                   # Foundry deployment scripts
│   └── Deploy.s.sol
├── test/                     # Test files
├── lib/                      # Foundry dependencies
├── Foundry.toml              # Foundry configuration
├── .env                      # Environment variables
├── package.json              # Root package.json (workspaces)
├── frontend/                 # Next.js frontend
│   ├── app/                  # App router
│   ├── lib/                  # Contract utilities
│   └── package.json          # Frontend dependencies
└── README.md
```

## Network Configuration

| Network | RPC | Explorer |
|---------|-----|----------|
| Testnet | `https://api.infra.testnet.somnia.network/` | `https://shannon-explorer.somnia.network/` |
| Testnet (alt) | `https://dream-rpc.somnia.network/` | `https://shannon-explorer.somnia.network/` |
| Mainnet | `https://api.infra.mainnet.somnia.network/` | `https://explorer.somnia.network/` |

## Deployed Contracts (Testnet)

| Contract | Address |
|----------|---------|
| PoolRegistry | `0x8dc237fa4624899BC1Edb4FdCEDa4Dde38fB448f` |
| PositionTracker | `0x657aA4924D4799424B5A30962F0fa0D92aEB70eB` |
| LiquidityManager | `0x4373337946F60376094553CC2339e21F18A1e6e3` |

## Key Features
- **Agent Integration**: JSON API agent (ID: `13174292974160097713`) for price feeds
- **LLM Agent**: ID `13174292974160097714` for allocation optimization
- **On-Chain Reactivity**: Same-block event handling

## Contract Functions
| Function | Description |
|----------|-------------|
| `updatePoolMetrics()` | Update pool APY/TVL |
| `fetchPrice()` | Fetch price via agent |
| `analyzeAndRebalance()` | Agent analysis |
| `executeRebalance()` | Execute rebalance |
| `claimRewards()` | Claim yield |
| `pause()` / `unpause()` | Admin controls |

## Frontend Stack
- **Framework**: Next.js 15.2.4
- **React**: 19.1.0
- **Styling**: Tailwind CSS 3.4.17
- **Wallet**: window.ethereum (MetaMask)
- **Contract**: Ethers.js 6.13.0

## Next Steps

1. Get STT from [faucet](https://testnet.somnia.network/) or [Discord](https://discord.com/invite/somnia)
2. Deploy contracts: `forge script script/Deploy.s.sol:DeployScript --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast`
3. Update `.env.local` with deployed contract addresses
4. Install Wagmi: `npm install @wagmi/core`
5. Add real-time updates with WebSocket connections
6. Test agent invocations on testnet