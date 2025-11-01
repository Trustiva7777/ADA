"use client";

import React, { useState } from "react";
import { motion } from "framer-motion";
import { Navigation } from "@/components/navigation";
import { HeroSection } from "@/components/hero-section";
import { FeaturesShowcase } from "@/components/features-showcase";
import { UseCasesCarousel } from "@/components/use-cases-carousel";
import { TrustBadges } from "@/components/trust-badges";
import { RoadmapTimeline } from "@/components/roadmap-timeline";
import { Footer } from "@/components/footer";

export default function Home() {
  const [isScrolled, setIsScrolled] = useState(false);

  React.useEffect(() => {
    const handleScroll = () => {
      setIsScrolled(window.scrollY > 50);
    };

    window.addEventListener("scroll", handleScroll);
    return () => window.removeEventListener("scroll", handleScroll);
  }, []);

  return (
    <main className="min-h-screen bg-gradient-to-b from-midnight via-slate-900 to-midnight">
      <Navigation isScrolled={isScrolled} />

      <HeroSection />

      <div className="space-y-32 px-4 py-24 sm:px-6 lg:px-8">
        <FeaturesShowcase />
        <UseCasesCarousel />
        <TrustBadges />
        <RoadmapTimeline />
      </div>

      <Footer />
    </main>
  );
}
