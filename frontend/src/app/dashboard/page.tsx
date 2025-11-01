"use client";

import React from "react";
import { useAccount } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";
import { Navigation } from "@/components/navigation";
import { DashboardHeader } from "@/components/dashboard-header";
import { ComplianceStatus } from "@/components/compliance-status";
import { HoldingsCard } from "@/components/holdings-card";
import { MultiSigQueue } from "@/components/multi-sig-queue";
import { AumBreakdown } from "@/components/aum-breakdown";
import { Footer } from "@/components/footer";

export default function Dashboard() {
  const { address, isConnected } = useAccount();

  if (!isConnected) {
    return (
      <div className="min-h-screen bg-gradient-to-b from-midnight via-slate-900 to-midnight">
        <Navigation isScrolled={false} />
        <div className="flex items-center justify-center px-4 py-24">
          <div className="text-center">
            <h1 className="heading-lg mb-4">Connect Your Wallet</h1>
            <p className="mb-8 text-text-secondary">
              Please connect your wallet to access the investor dashboard
            </p>
            <ConnectButton />
          </div>
        </div>
        <Footer />
      </div>
    );
  }

  return (
    <main className="min-h-screen bg-gradient-to-b from-midnight via-slate-900 to-midnight">
      <Navigation isScrolled={false} />

      <div className="px-4 py-8 sm:px-6 lg:px-8">
        <DashboardHeader walletAddress={address} />

        <div className="mt-12 space-y-8">
          <div className="grid gap-8 md:grid-cols-2">
            <ComplianceStatus />
            <AumBreakdown />
          </div>

          <div className="grid gap-8 lg:grid-cols-3">
            <div className="lg:col-span-2">
              <HoldingsCard />
            </div>
            <div>
              <MultiSigQueue />
            </div>
          </div>
        </div>
      </div>

      <Footer />
    </main>
  );
}
