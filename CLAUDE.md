# Deskmates

Pixel call-center app: AI deskmates with real phone numbers. iOS + Supabase + LiveKit, scaffolded from the HappyFace app starter. Product overview and setup: `README.md`.

## Monorepo Structure

```
deskmates/
├── ios/                    # SwiftUI app (Tuist, iOS 18+)
├── backend/                # Supabase (Postgres + Edge Functions)
├── agent/                  # Python LiveKit voice agent (one worker serves every desk)
├── scripts/                # Template + maintenance scripts
└── CLAUDE.md               # You are here
```

Each subdirectory has its own `CLAUDE.md`:
- `ios/CLAUDE.md` — Tuist modules, SwiftUI patterns, build instructions
- `backend/CLAUDE.md` — DB migrations, edge functions, npm scripts

## Prerequisites

- **mise** — Version manager (installs Tuist for iOS). `curl https://mise.run | sh`
- **Node.js 20+** — Backend tooling
- **Supabase CLI** — `brew install supabase/tap/supabase` (or `npm i -g supabase`)
- **Xcode 16.3+** — iOS 18 toolchain (LiveKit 2.17 needs Swift tools 6.1)
- **uv** — Python agent (`agent/`)

## Architecture

```
iOS App (SwiftUI) ──▶ Supabase (Auth + Postgres + Edge Functions + Realtime)
        │                     ▲
        └──▶ LiveKit rooms ◀──┴── agent/ (writes call status + transcripts)
```

- **LiveKit** — rooms, SIP (phone numbers, inbound dispatch rule `deskmates-inbound`, outbound trunk), Agents + Inference

- **Supabase** — Auth (incl. Sign in with Apple), Postgres DB, Edge Functions, Storage
- **RevenueCat** — Subscriptions / paywall
- **PostHog** — Analytics
- **OneSignal** — Push notifications

## Environments & Branching

| Environment | Supabase Project Ref | Git Branch |
|-------------|----------------------|------------|
| Dev/Staging | `{{SUPABASE_PROJECT_REF_DEV}}` | `dev`, feature branches |
| Production  | `{{SUPABASE_PROJECT_REF_PROD}}` | `main` |

Before any `db:push` or deployment:

1. Check your git branch.
2. Run `npm run db:link:dev` (or `:prod`) so the Supabase CLI points at the right project.
3. Push migrations.

## Key Conventions

- **Database migrations**: Plain SQL in `backend/supabase/migrations/`. See `backend/CLAUDE.md`.
- **iOS modules**: Tuist multi-target architecture. Each Kit is a separate framework — App, SharedKit, SupabaseKit, AnalyticsKit, InAppPurchaseKit, NotifKit, OfficeKit (the pixel office + LiveKit calling).
- **Office art**: LimeZu sprites packed by `ios/Tools/officeart/pack.py` (layout in `scene.py`, sprite picks in `art.py`). The PNGs are licensed and gitignored; never commit them or anything embedding them (e.g. the web preview). `Sources/Sprites/OfficeScene.swift` mirrors `render.py`. When the art isn't packed, OfficeKit falls back to the procedural sprites in `ios/Tools/pixelart` (`design.py` → `gen.py` → `PixelArt.swift`).
- **Agent ↔ app contract**: job metadata `{direction, call_id, desk_id, to, from, trunk_id, brief}`; RPC `deskmates.handoff` (owner takes over); owner participants use identity `owner-<user id>`.
- **Secrets**: Never commit. iOS reads from `ios/Secrets.xcconfig` (gitignored) locally and from Xcode Cloud env vars in CI. Backend reads from Supabase secrets (`supabase secrets set ...`).
- **Bundle ID**: `studio.happyface.deskmates`

## CI/CD — Xcode Cloud

iOS builds run on **Xcode Cloud**. The post-clone script (`ios/ci_scripts/ci_post_clone.sh`) installs Tuist via `mise`, writes per-Kit `*-Info.plist` files from workflow environment variables, then runs `tuist generate`.

Set these env vars in App Store Connect → Xcode Cloud → Workflow → Environment:

| Env var | Used by |
|---|---|
| `SUPABASE_URL`, `SUPABASE_KEY` | SupabaseKit |
| `POSTHOG_API_KEY`, `POSTHOG_HOST` | AnalyticsKit |
| `REVENUECAT_API_KEY` | InAppPurchaseKit |
| `ONESIGNAL_APP_ID` | NotifKit |

Each block in `ci_post_clone.sh` is conditional — apps that don't use a given integration can leave its env vars unset and the build still succeeds.

## Bootstrapping from this template

After cloning the template into a new repo, run:

```bash
./scripts/rename-app.sh "MyApp" "com.example.myapp" "<dev-project-ref>" "<prod-project-ref>"
cd ios && cp Secrets.xcconfig.template Secrets.xcconfig   # fill in dev values
mise install
tuist generate
open MyApp.xcworkspace
```

This rewrites every `{{TOKEN}}` in docs/configs and the three identity constants in `ios/Project.swift`. After running, no `{{...}}` placeholders should remain — verify with `grep -r '{{' .`.
