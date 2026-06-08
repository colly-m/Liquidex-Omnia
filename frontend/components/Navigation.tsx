"use client";

import Link from "next/link";
import { usePathname } from "next/navigation";
import { cn } from "@/lib/utils";
import { LayoutDashboard, Droplets, ArrowLeftRight, Trophy, BarChart3, Brain } from "lucide-react";

const navigation = [
  { name: "Dashboard", href: "/dashboard", icon: LayoutDashboard, description: "Overview & positions" },
  { name: "Pools", href: "/pools", icon: Droplets, description: "Liquidity pools" },
  { name: "Swap", href: "/swap", icon: ArrowLeftRight, description: "Trade tokens" },
  { name: "Agents", href: "/agents", icon: Brain, description: "AI agents & price feeds" },
  { name: "Campaigns", href: "/campaigns", icon: Trophy, description: "Earn rewards" },
  { name: "Analytics", href: "/analytics", icon: BarChart3, description: "Protocol metrics" },
];

export default function Navigation() {
  const pathname = usePathname();

  return (
    <nav className="w-64 h-screen fixed left-0 top-16 bg-gray-950 border-r border-gray-800 pt-6">
      <div className="px-4 space-y-1">
        {navigation.map((item) => {
          const isActive = pathname === item.href;
          return (
            <Link
              key={item.name}
              href={item.href}
              className={cn(
                "flex items-center gap-3 px-3 py-2.5 text-sm font-medium rounded-lg transition-colors group",
                isActive
                  ? "bg-blue-500/10 text-blue-400"
                  : "text-gray-400 hover:bg-gray-800 hover:text-gray-200"
              )}
            >
              <item.icon className="h-5 w-5" />
              <div className="flex-1">
                <div className="flex items-center justify-between">
                  <span>{item.name}</span>
                </div>
                <p className="text-xs text-gray-500 group-hover:text-gray-400 transition-colors">
                  {item.description}
                </p>
              </div>
            </Link>
          );
        })}
      </div>
    </nav>
  );
}