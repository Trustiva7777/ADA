"use client";

import React from "react";

export function Navigation({ isScrolled }: { isScrolled: boolean }) {
  return (
    <nav
      className={`sticky top-0 z-50 transition-all duration-200 ${
        isScrolled
          ? "border-b border-slate-700 bg-midnight/95 backdrop-blur"
          : "bg-transparent"
      }`}
    >
      <div className="mx-auto flex max-w-7xl items-center justify-between px-4 py-4 sm:px-6 lg:px-8">
        <div className="text-2xl font-bold text-gold">UNYKORN 7777</div>

        <div className="hidden gap-8 md:flex">
          <a href="#" className="text-text-secondary hover:text-gold">
            Features
          </a>
          <a href="#" className="text-text-secondary hover:text-gold">
            Use Cases
          </a>
          <a href="#" className="text-text-secondary hover:text-gold">
            Roadmap
          </a>
        </div>

        <div className="gap-4 md:flex">
          <a href="/dashboard" className="btn-secondary">
            Dashboard
          </a>
        </div>
      </div>
    </nav>
  );
}
