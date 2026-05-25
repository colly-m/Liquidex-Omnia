#!/bin/bash
# Deploy script for Liquidex-Omnia on Somnia

echo "Deploying LiquidityManager to Somnia Testnet..."

# Get platform contract address from .env or use default
PLATFORM_ADDRESS="${PLATFORM_ADDRESS:-0x037Bb9C718F3f7fe5eCBDB0b600D607b52706776}"

# Deploy the contract
forge create \
  --rpc-url https://api.infra.testnet.somnia.network/ \
  --private-key "$PRIVATE_KEY" \
  --broadcast \
  src/LiquidityManager.sol:LiquidityManager \
  --constructor-args "$PLATFORM_ADDRESS"

echo "Deployment complete!"
echo "Update your .env file with the deployed contract address"