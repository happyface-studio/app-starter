# Deskmates

Build your own little call center on your phone. Hire pixel deskmates, give each one a desk and a real phone number, and they answer calls, take messages and ring people for you. Built on the HappyFace app starter with LiveKit for voice.

```
┌──────────── iOS app (SwiftUI) ────────────┐        ┌──────────── LiveKit Cloud ─────────────┐
│ Office tab  pixel office, desks, phones   │  join  │ Rooms: web-… / call-… / out-…           │
│ Calls tab   log, transcripts, messages    │ ─────▶ │ Agent "deskmates" (agent/)              │
│ Call screen talk, listen in, take over    │        │   STT → LLM → TTS via LiveKit Inference │
└──────────────┬────────────────────────────┘        │ Phone Numbers (US, inbound)             │
               │ Supabase Auth + Realtime            │ SIP trunk (studio numbers, in + out)    │
               ▼                                     └──────────────┬──────────────────────────┘
┌──────────── Supabase ─────────────────────┐                      │ status, transcript,
│ desks · phone_lines · calls (RLS)         │ ◀────────────────────┘ messages (service role)
│ Edge functions: session-token,            │
│ phone-numbers, place-call, end-call       │
└───────────────────────────────────────────┘
```

## What works in this prototype

- **Hire deskmates.** Six desks; each deskmate has a name, role, greeting, job brief, language (English, German or the caller's language), voice and a pixel look you can edit.
- **Talk to a deskmate in the app.** No phone number needed. Opens a LiveKit room with the agent dispatched by the token.
- **Real phone numbers.**
  - *Rent a US number* through LiveKit Phone Numbers (inbound only, LiveKit's current limit).
  - *Claim a studio number* from a SIP trunk you connect once (Twilio, Telnyx, sipgate…). These can call out, and this is how you get +49 numbers.
- **Inbound calls.** Every number shares one dispatch rule. The agent looks up which desk owns the dialed number, answers in that persona, takes messages and pushes you a notification.
- **Outbound calls.** "Have Paula call someone": enter a number and a brief ("book a table for four on Friday"). The agent dials, waits for an answer, and handles the call.
- **Live office.** Supabase Realtime animates the desks: the phone rings, a speech bubble shows talking or thinking, and the transcript streams in.
- **Listen in and take over.** Join any live phone call silently, then tap *Jump in*: the deskmate says "putting you through", goes quiet, and you're on the line. Leave, and they pick the call back up.

## Repo layout

| Path | What |
|---|---|
| `ios/Targets/OfficeKit` | New module: SpriteKit office, desk editor, number picker, dialer, call log, call screen |
| `ios/Targets/SupabaseKit/Sources/Model/Office` | Models and `OfficeStore` (queries, edge functions, Realtime) |
| `ios/Tools/officeart` | Packs the LimeZu office and character art into the app (art is local only, see below) |
| `ios/Tools/pixelart` | Procedural fallback sprites, used when the LimeZu art isn't packed |
| `backend/supabase/migrations/20261008120000_deskmates.sql` | `desks`, `phone_lines`, `calls`, RLS, `plug_line()` |
| `backend/supabase/functions` | `session-token`, `phone-numbers`, `place-call`, `end-call` |
| `agent/` | Python LiveKit agent (Agents 1.8) |

## Setup

Do the base template setup in [`SETUP.md`](./SETUP.md) first (Supabase projects, Sign in with Apple, secrets). Then:

### 1. LiveKit Cloud

1. Create a project at [cloud.livekit.io](https://cloud.livekit.io) and note `LIVEKIT_URL`, `LIVEKIT_API_KEY` and `LIVEKIT_API_SECRET`.
2. Install the CLI (`brew install livekit-cli`) and run `lk cloud auth`.

### 2. Backend

```bash
cd backend
npm run db:link:dev && npm run db:push

supabase secrets set \
  LIVEKIT_URL=wss://<project>.livekit.cloud \
  LIVEKIT_API_KEY=... LIVEKIT_API_SECRET=...

npm run functions:deploy
```

Optional secrets:

| Secret | Default | Purpose |
|---|---|---|
| `LIVEKIT_SIP_OUTBOUND_TRUNK_ID` | none | Outbound trunk (`ST_…`). Without it, nobody can place calls. |
| `SIP_TRUNK_NUMBERS` | none | Comma-separated E.164 numbers on your trunk that users can claim |
| `MAX_LINES_PER_USER` | `2` | Prototype limit on numbers per account |
| `MAX_OUTBOUND_CALLS_PER_DAY` | `20` | Per account |
| `ALLOWED_DIAL_PREFIXES` | `+1,+49,+43,+41,+44` | Toll-fraud guard for outbound calls |

### 3. Agent

```bash
cd agent
cp .env.example .env.local      # LiveKit + Supabase service role (+ OneSignal for push)
uv sync
uv run src/agent.py dev         # local worker, registers as agent "deskmates"
```

Deploy to LiveKit Cloud from `agent/` with `lk agent create --secrets-file .env.local`. It uses the included Dockerfile, and LiveKit injects its own credentials, so the secrets file only needs the Supabase and OneSignal values. Later changes: `lk agent deploy`, and `lk agent update-secrets --secrets-file .env.local`.

STT, LLM and TTS go through LiveKit Inference, billed to the LiveKit project, so you don't need separate provider keys. To change models, set `DESKMATES_LLM`, `DESKMATES_STT` and `DESKMATES_TTS`.

### 4. Studio SIP trunk (outbound calls and German numbers)

1. Buy numbers from a SIP provider and create a SIP trunk there. LiveKit has [provider quickstarts](https://docs.livekit.io/telephony/start/providers/) (e.g. [Telnyx](https://docs.livekit.io/telephony/start/providers/telnyx/)) and a general [SIP trunk setup](https://docs.livekit.io/telephony/start/sip-trunk-setup/) guide.
2. Point the provider's inbound traffic at LiveKit and create an **inbound trunk** with those numbers: `lk sip inbound create`.
3. Create an **outbound trunk**: `lk sip outbound create`. Put its ID in `LIVEKIT_SIP_OUTBOUND_TRUNK_ID`.
4. List the numbers in `SIP_TRUNK_NUMBERS`.

Inbound calls on the trunk reach the same `deskmates-inbound` dispatch rule automatically. The first number anyone rents or claims creates that rule.

### 5. iOS

Needs **Xcode 16.3+**, because LiveKit 2.17 uses Swift tools 6.1.

```bash
cd ios && cp Secrets.xcconfig.template Secrets.xcconfig   # Supabase URL + anon key
python3 Tools/officeart/pack.py --limezu "<folder with the LimeZu packs>"   # office art, see below
mise install && tuist generate && open Deskmates.xcworkspace
```

The office uses LimeZu's Modern Office and Modern Interiors packs. Their license lets us ship the art in the app but not share the files, so they stay out of git and `pack.py` builds them into `Targets/OfficeKit/Resources/OfficeArt` on your machine. Skip that step and the app falls back to simpler procedural sprites. Details in [`ios/Tools/officeart/README.md`](./ios/Tools/officeart/README.md).

Run it on a device so you can test the microphone. Sign in, hire a deskmate, and tap **Talk to …**.

## Known limits and next steps

- **LiveKit Phone Numbers** are US-only and inbound-only today, and calls can't be transferred yet. For European numbers or any outbound calling, use the studio trunk.
- **Calls don't ring your phone.** You listen in from the app. Next step: CallKit with VoIP pushes so a live call can ring the phone like a normal one, plus "transfer to my mobile" via `TransferSIPParticipant` on trunk numbers.
- **Regulation.** AI calls to people in the EU have disclosure and consent rules, and so does recording a call. The agent introduces itself by name but doesn't say it's an AI. Decide on that before any real users touch outbound calls.
- **Billing.** Every rented number and call minute bills to the studio's LiveKit project. Prototype limits are in edge-function env vars. Gate them behind RevenueCat before shipping (InAppPurchaseKit is still in the template).
- **Agent tools.** Only `take_message` and `end_call` so far. Calendar booking, FAQ lookup and SMS follow-ups are natural next tools.
- **Not yet compiled.** The Swift code was reviewed against the LiveKit 2.17.0 and supabase-swift 2.20.5 sources and parse-checked, but it hasn't gone through Xcode yet. Expect a few fixes on the first build.
- **Credits.** LimeZu's Modern Interiors license requires a credit. Add "Pixel art by LimeZu" to the app's about/settings screen before shipping.
