export type Token = {
  symbol: string;
  name: string;
  address: string;
  decimals: number;
  balance: string;
  logo?: string;
};

export type Pool = {
  id: string;
  token0: Token;
  token1: Token;
  liquidity: string;
  fee: number;
  tickCurrent: number;
  sqrtPrice: string;
  feeGrowthGlobal0X128: string;
  feeGrowthGlobal1X128: string;
  totalFees: {
    token0: string;
    token1: string;
  };
};

export type Swap = {
  id: string;
  poolId: string;
  amount0: string;
  amount1: string;
  amount0Out: string;
  amount1Out: string;
  to: string;
  timestamp: number;
};

export type Position = {
  id: string;
  poolId: string;
  tickLower: number;
  tickUpper: number;
  liquidity: string;
  feeGrowthInside0Last: string;
  feeGrowthInside1Last: string;
  tokensOwed0: string;
  tokensOwed1: string;
};

export type Campaign = {
  id: string;
  title: string;
  description: string;
  token: Token;
  rewardPerBlock: string;
  startDate: number;
  endDate: number;
  totalReward: string;
  stakedAmount: string;
};

export type AnalyticsData = {
  volume24h: string;
  volume7d: string;
  volume30d: string;
  fees24h: string;
  fees7d: string;
  fees30d: string;
  tvl: string;
  priceChange24h: number;
};

export type AgentRequest = {
  id: string;
  type: "price" | "analysis";
  status: "pending" | "completed" | "failed";
  timestamp: number;
  result?: string;
  token?: string;
};