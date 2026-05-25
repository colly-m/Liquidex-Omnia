import { createPublicClient, http } from "viem";
import { somniaTestnet } from "viem/chains";

export const somniaClient = createPublicClient({
  chain: somniaTestnet,
  transport: http(process.env.NETWORK_RPC || "https://dream-rpc.somnia.network"),
});