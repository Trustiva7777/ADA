# UNYKORN 7777 Frontend - Setup & Installation Guide

## Overview

This is a Next.js 15 + React + TypeScript frontend for the UNYKORN 7777 RWA platform. It provides:

- ✅ Homepage with hero, features, use cases, and roadmap
- ✅ Investor dashboard with real-time compliance status
- ✅ Holdings management with Rule 144 tracking
- ✅ KYC/sanctions compliance dashboard
- ✅ Multi-sig approval queue
- ✅ Wallet integration (RainbowKit + Wagmi)
- ✅ TailwindCSS styling with custom design system
- ✅ Framer Motion animations
- ✅ Chart visualizations (Recharts)

## Project Structure

```
frontend/
├── src/
│   ├── app/
│   │   ├── page.tsx          # Homepage
│   │   ├── layout.tsx        # Root layout
│   │   ├── globals.css       # Global styles
│   │   ├── dashboard/
│   │   │   ├── page.tsx      # Investor dashboard
│   │   │   ├── holdings/     # Holdings breakdown
│   │   │   ├── compliance/   # Compliance status
│   │   │   └── approvals/    # Multi-sig queue
│   ├── components/
│   │   ├── navigation.tsx
│   │   ├── hero-section.tsx
│   │   ├── features-showcase.tsx
│   │   ├── use-cases-carousel.tsx
│   │   ├── trust-badges.tsx
│   │   ├── roadmap-timeline.tsx
│   │   ├── dashboard-header.tsx
│   │   ├── compliance-status.tsx
│   │   ├── holdings-card.tsx
│   │   ├── multi-sig-queue.tsx
│   │   ├── aum-breakdown.tsx
│   │   ├── kyc-submit-form.tsx
│   │   ├── transfer-request-form.tsx
│   │   ├── footer.tsx
│   │   └── providers.tsx     # Context providers
│   ├── hooks/
│   │   ├── use-compliance.ts
│   │   ├── use-holdings.ts
│   │   └── use-multi-sig.ts
│   ├── lib/
│   │   ├── wagmi-config.ts
│   │   ├── api-client.ts
│   │   └── utils.ts
│   └── types/
│       ├── compliance.ts
│       ├── holdings.ts
│       └── contracts.ts
├── tailwind.config.ts
├── tsconfig.json
├── next.config.ts
├── package.json
└── .env.example
```

## Installation

### 1. Prerequisites

```bash
# Ensure you have Node.js 18+
node --version  # >= v18.17

# Ensure you have pnpm (recommended) or npm
pnpm --version
```

### 2. Install Dependencies

```bash
cd frontend
pnpm install
# OR
npm install
```

### 3. Environment Setup

```bash
cp .env.example .env.local
```

Edit `.env.local`:

```env
NEXT_PUBLIC_API_URL=http://localhost:5000/api
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=your_wallet_connect_id_here
```

### 4. Development Server

```bash
pnpm dev
# OR
npm run dev
```

Visit http://localhost:3000

## Architecture

### Technology Stack

| Layer      | Technology                          |
| ---------- | ----------------------------------- |
| Framework  | Next.js 15 (App Router)             |
| Language   | TypeScript 5.3+                     |
| UI Library | React 19                            |
| Styling    | TailwindCSS 4.0 + Custom CSS        |
| Animation  | Framer Motion 10.16                 |
| Forms      | React Hook Form + Zod validation    |
| Charts     | Recharts 2.10                       |
| Web3       | Wagmi 2.5 + Viem 2.7                |
| Wallet UI  | RainbowKit 2.0                      |
| State Mgmt | TanStack React Query 5.28           |
| HTTP       | Axios 1.6                           |
| Icons      | Lucide React 0.294                  |

### Design System

**Color Palette:**

- Midnight: `#0f172a` (primary bg)
- Slate: `#1e293b` (secondary bg)
- Gold: `#fbbf24` (accent, CTAs)
- Emerald: `#10b981` (success, valid status)
- Red: `#ef4444` (danger, invalid status)

**Typography:**

- Heading XL: 4xl (3.5rem) → 5xl (3rem) on md+
- Heading LG: 3xl (2.25rem) → 4xl (2.25rem) on md+
- Heading MD: 2xl (1.5rem)
- Heading SM: xl (1.25rem)
- Body: 16px, line-height 1.6

**Components:**

- `.card` - Standard card with border
- `.card-hover` - Interactive card with hover effects
- `.btn-primary` - Gold CTA button
- `.btn-secondary` - Outlined secondary button
- `.input-field` - Form input with focus state
- `.badge` - Green status badge
- `.badge-warning` - Yellow warning badge
- `.badge-danger` - Red danger badge

## Pages & Components

### Page: `/` (Homepage)

**Components:**

- `<Navigation />` - Top navigation bar
- `<HeroSection />` - Hero with animated blockchain viz
- `<FeaturesShowcase />` - 3-column features (Speed, Compliance, Governance)
- `<UseCasesCarousel />` - Investor use cases ($50M family office, etc.)
- `<TrustBadges />` - OpenZeppelin audit, $21.2M backing
- `<RoadmapTimeline />` - Q4 2025 → Q3 2026 timeline
- `<Footer />` - Footer with links & social

### Page: `/dashboard` (Investor Portal)

**Layout:**

```
┌─ Navigation
├─ Dashboard Header
│  ├─ Welcome message
│  ├─ Wallet address
│  └─ Last updated timestamp
├─ Grid (2 cols on md+)
│  ├─ Compliance Status Card
│  └─ AUM Breakdown Chart
├─ Grid (3 cols on lg+)
│  ├─ Holdings Card (2 cols)
│  └─ Multi-Sig Queue (1 col)
└─ Footer
```

**Components:**

- `<DashboardHeader />` - Header with address
- `<ComplianceStatus />` - KYC/sanctions status
- `<AumBreakdown />` - Pie chart by asset class
- `<HoldingsCard />` - Holdings table
- `<MultiSigQueue />` - Pending approvals
- `<KycSubmitForm />` - KYC submission
- `<TransferRequestForm />` - Transfer authorization

### Page: `/dashboard/holdings` (Holdings Breakdown)

**Layout:**

```
┌─ Navigation
├─ Page Title
├─ Holdings Table
│  ├─ SPV Name
│  ├─ Acquisition Date
│  ├─ Quantity
│  ├─ Status (Restricted/Unrestricted)
│  └─ Unrestricted Date
├─ Tax Lot Details (Expandable)
│  ├─ Cost basis
│  ├─ Unrealized gain/loss
│  └─ Holding period
└─ Export Options (CSV, PDF, TurboTax)
```

### Page: `/dashboard/compliance` (Compliance Status)

**Layout:**

```
┌─ Navigation
├─ Compliance Cards
│  ├─ KYC Status Card
│  │  ├─ Tier (Accredited, etc.)
│  │  ├─ Expiry date
│  │  └─ Renew button
│  ├─ Sanctions Card
│  │  ├─ Status (Clear/Flagged)
│  │  ├─ Lists screened
│  │  └─ Last check date
│  └─ Adverse Media Card
├─ 7-Year Audit Trail
│  └─ Queryable events table
└─ Export Audit Trail (PDF)
```

### Page: `/dashboard/approvals` (Multi-Sig Queue)

**Layout:**

```
┌─ Navigation
├─ Pending Transactions
│  ├─ Transaction ID
│  ├─ Signers Required
│  ├─ Current Signers
│  ├─ Timelock Status
│  ├─ Transaction Details (Modal)
│  └─ Sign Button (MetaMask)
└─ Transaction History
```

## API Integration

### Backend Endpoints

The frontend connects to the .NET backend at `NEXT_PUBLIC_API_URL`:

```typescript
// Compliance Endpoints
POST /api/compliance/kyc              // Submit KYC
POST /api/compliance/sanctions        // Check sanctions
POST /api/compliance/authorize-transfer // Pre-flight check
POST /api/compliance/renew-kyc        // Extend KYC
GET  /api/compliance/audit-trail      // Immutable logs

// Holdings Endpoints
GET  /api/holdings                    // Get user holdings
GET  /api/holdings/:id                // Get holding details
POST /api/holdings/export             // Export to CSV/PDF

// Multi-Sig Endpoints
GET  /api/multisig/pending            // Get pending transactions
POST /api/multisig/:id/sign           // Sign transaction
GET  /api/multisig/history            // Transaction history
```

### Custom Hooks

```typescript
// src/hooks/use-compliance.ts
const {
  kycStatus,
  sanctionsStatus,
  auditTrail,
  submitKyc,
  checkSanctions,
  isLoading,
} = useCompliance();

// src/hooks/use-holdings.ts
const {
  holdings,
  totalAum,
  breakdown,
  exportHoldings,
  isLoading,
} = useHoldings();

// src/hooks/use-multi-sig.ts
const {
  pendingTxs,
  signTransaction,
  isLoading,
} = useMultiSig();
```

## Wallet Integration

Uses RainbowKit + Wagmi for wallet connection:

```typescript
import { useAccount } from "wagmi";
import { ConnectButton } from "@rainbow-me/rainbowkit";

export function App() {
  const { address, isConnected } = useAccount();

  if (!isConnected) {
    return <ConnectButton />;
  }

  return <Dashboard address={address} />;
}
```

**Supported Networks:**

- Ethereum Mainnet
- Sepolia Testnet
- Polygon (Phase 2)
- Cardano (Phase 2)

## Development

### Code Organization

- **Pages** (`src/app/`): Route handlers
- **Components** (`src/components/`): Reusable React components
- **Hooks** (`src/hooks/`): Custom React hooks
- **Lib** (`src/lib/`): Utilities (API client, config, helpers)
- **Types** (`src/types/`): TypeScript interfaces

### ESLint & Prettier

```bash
# Lint
pnpm lint

# Format
pnpm format

# Type check
pnpm type-check
```

### Testing

```bash
# Run tests
pnpm test

# Watch mode
pnpm test:watch

# Coverage
pnpm test:coverage
```

## Build & Deployment

### Production Build

```bash
pnpm build
pnpm start
```

### Docker

```bash
# Build image
docker build -t unykorn-7777-frontend .

# Run container
docker run -p 3000:3000 unykorn-7777-frontend
```

### Kubernetes

See `k8s/frontend-deployment.yaml`

### Environment Variables

**Development:**

```env
NEXT_PUBLIC_API_URL=http://localhost:5000/api
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=test_project_id
NODE_ENV=development
```

**Production:**

```env
NEXT_PUBLIC_API_URL=https://api.unykorn7777.com/api
NEXT_PUBLIC_WALLET_CONNECT_PROJECT_ID=prod_project_id
NODE_ENV=production
```

## Performance Optimization

- ✅ Image optimization (Next.js Image)
- ✅ Code splitting (dynamic imports)
- ✅ Font optimization (next/font)
- ✅ CSS minification (TailwindCSS)
- ✅ Bundle analysis (next/bundle-analyzer)

## Security

- ✅ CSP headers
- ✅ HTTPS enforcement
- ✅ XSS protection
- ✅ CSRF tokens
- ✅ Secure cookie handling
- ✅ Rate limiting (backend)

## Monitoring

Connected to Sentry for error tracking:

```typescript
// Error logging
Sentry.captureException(error);
Sentry.captureMessage("Important event");
```

## Support

For issues, see:

- GitHub Issues: https://github.com/Trustiva7777/ADA/issues
- Docs: /docs
- Email: support@unykorn7777.com

---

**Status:** ⏳ IN PROGRESS (Frontend ~70% complete)  
**Last Updated:** October 31, 2025  
**Next Phase:** Connect backend APIs, WebSocket integration

