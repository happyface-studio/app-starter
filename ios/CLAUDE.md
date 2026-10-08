# Deskmates iOS App

SwiftUI app built with Tuist multi-target architecture. iOS 18+ minimum.

## Build System

- **Tuist** — Project generation and dependency management. Version pinned in `ios/.mise.toml`.
- **Project.swift** — Single project manifest defining all targets, dependencies, and settings.

### Commands

```bash
mise install           # Install Tuist (first time)
tuist generate         # Generate Xcode project from Project.swift
tuist clean            # Clean generated artifacts
```

Open `Deskmates.xcworkspace` in Xcode after generating.

## Module Architecture

```
App (main target)
├── SharedKit          # Utilities, view modifiers, UI primitives
├── SupabaseKit        # Auth (Apple + Email), DB queries, edge function calls
├── AnalyticsKit       # PostHog event tracking
├── InAppPurchaseKit   # RevenueCat subscriptions, paywall
└── NotifKit           # OneSignal push notifications
```

### Module Responsibilities

| Module | Purpose | Key Dependencies |
|--------|---------|------------------|
| **SharedKit** | View modifiers, extensions, constants | — |
| **SupabaseKit** | Auth, DB models, queries | supabase-swift |
| **AnalyticsKit** | PostHog setup, event capture | posthog-ios |
| **InAppPurchaseKit** | Paywall UI, subscription management | RevenueCat |
| **NotifKit** | Push permission flow, notification settings | OneSignal |

## Directory Layout (per module)

```
Targets/<ModuleName>/
├── Sources/           # Swift source files
├── Resources/         # Assets, localizations
└── Config/            # *-Info.plist files (gitignored — generated locally or in CI)
```

## Secrets Configuration

API keys live in `ios/Secrets.xcconfig` (gitignored). Each Kit reads its keys from a `*-Info.plist` at `Targets/<Kit>/Config/<Name>-Info.plist`:

- `Supabase-Info.plist` → `SUPABASE_URL`, `SUPABASE_KEY`
- `PostHog-Info.plist` → `POSTHOG_API_KEY`, `POSTHOG_HOST`
- `RevenueCat-Info.plist` → `REVENUECAT_API_KEY`
- `OneSignal-Info.plist` → `ONESIGNAL_APP_ID`

These plists are **gitignored**. Two ways they get populated:

1. **Local dev** — copy `Secrets.xcconfig.template` to `Secrets.xcconfig`, fill in values, Tuist injects them at build time.
2. **CI (Xcode Cloud)** — `ci_scripts/ci_post_clone.sh` writes the plists directly from workflow env vars.

## Code Style

- Indentation: 4 spaces.
- SwiftUI views use standard patterns (`.sheet`, `.alert`, `@State`, `@Environment`).
- View modifiers in SharedKit: `.requireLogin()`, `.requirePremium()`, `.requireNetwork()`.

### Comments

Default to **no comments**. Well-named types, properties, and functions should make the code self-explanatory. Add a comment **only** when:

- A non-obvious **invariant** or **constraint** the reader needs to know.
- A **workaround** for a SwiftUI / iOS quirk (link the radar / ticket if there is one).
- A **subtle gotcha** that has bitten you before.

Do **not** write comments that restate what the code does, reference the current task/PR, or document trivial layout decisions.

## Key Patterns

- **Bundle ID** — `studio.happyface.deskmates` (set in `Project.swift`)
- **SupabaseKit models** — group queries by domain (`DB+<Domain>.swift`)
- **Onboarding / paywall sheets** — driven by view modifiers in SharedKit

## What's in the box

The template ships with examples for each Kit:

- **SupabaseKit** — Sign in with Apple, email/password auth, account settings, a simple `posts` CRUD example.
- **AnalyticsKit** — PostHog initialization, view-tracking modifier.
- **InAppPurchaseKit** — RevenueCat init, sample paywall sheet, premium-gating modifier.
- **NotifKit** — OneSignal init, push permission prompt.

Strip whatever you don't need.
