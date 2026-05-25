# Liquidex-Omnia

Automated Liquidity Management dApp on Somnia Agentic L1

## Status

**Phase 1-2 Complete** ✅
- Smart contracts compiled with Foundry
- Network configuration set for Somnia Testnet (50312)
- Agent integration implemented

## Quick Start

```bash
# Build contracts
forge build

# Deploy to testnet
forge create --rpc-url https://api.infra.testnet.somnia.network/ \
  --private-key $PRIVATE_KEY \
  src/LiquidityManager.sol:LiquidityManager \
  --constructor-args 0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776 0x0000... 0x0000...
```

## Project Structure

```
liquidex-omnia/
├── src/
│   ├── LiquidityManager.sol    # Main contract
│   ├── PoolRegistry.sol        # Pool tracking
│   ├── PositionTracker.sol     # User positions
│   └── AgentInterface.sol      # Agent interfaces
├── scripts/                    # Deployment scripts
├── Foundry.toml                # Foundry configuration
├── .env                        # Environment variables
└── README.md
```

## Network Configuration

| Network | RPC | Explorer |
|---------|-----|----------|
| Testnet | `https://api.infra.testnet.somnia.network/` | `https://shannon-explorer.somnia.network/` |
| Mainnet | `https://api.infra.mainnet.somnia.network/` | `https://explorer.somnia.network/` |

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

## Next Steps

1. Get STT from [faucet](https://testnet.somnia.network/)
2. Deploy contract
3. Build frontend
4. Add more pool integrations