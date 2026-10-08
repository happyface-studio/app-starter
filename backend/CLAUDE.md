# Deskmates Backend

Supabase (Auth + Postgres + Edge Functions + Storage). One runtime: Deno (Edge Functions).

## Directory Structure

```
backend/
├── supabase/
│   ├── config.toml            # Local CLI config + Apple OAuth + storage
│   ├── seed.sql               # Seed data for local development
│   ├── migrations/            # SQL migration files (source of truth)
│   │   └── 00000000000000_posts.sql
│   └── functions/             # Edge Functions (Deno) — add via `supabase functions new`
├── package.json               # DB/edge npm scripts
├── .env.template              # Local script env vars
└── .gitignore
```

## Database & Migrations

### Environment Check (do this first)

Before any migration or deployment, check your git branch and ensure Supabase is linked to the correct project:

| Git Branch | Target | Link Command |
|------------|--------|--------------|
| `dev`, feature branches | Dev/Staging (`{{SUPABASE_PROJECT_REF_DEV}}`) | `npm run db:link:dev` |
| `main` | Production (`{{SUPABASE_PROJECT_REF_PROD}}`) | `npm run db:link:prod` |

**Always verify before `db:push`.** Pushing to the wrong project can break things for real users.

### Rules

- Migrations are plain SQL files managed by **Supabase CLI**.
- `supabase/migrations/` is the source of truth for the DB schema.
- Workflow: `npm run db:link:<env>` → `npm run db:migration:new <name>` → edit the generated SQL → `npm run db:push`.
- Use `npm run db:diff -- <name>` to auto-generate migration SQL from a running local schema.
- Never modify an already-applied migration file. Add a new one instead.

### Key Tables (starter schema)

- `auth.users` — Managed by Supabase Auth.
- `public.posts` — Starter example matching `SupabaseBackend.swift`'s `DatabaseExampleView` (RLS: owner-only).

Extend with your domain tables. Always:

- Reference `auth.users(id)` for user-owned data with `on delete cascade`.
- Enable RLS on every table that holds user data (`alter table ... enable row level security`).
- Add owner policies for `select`, `insert`, `update`, `delete`.

## Edge Functions

The template ships with no edge functions — add yours with `supabase functions new <name>`. They live under `supabase/functions/<name>/index.ts` and are deployed with `npm run functions:deploy`.

Edge functions run in **Deno**, not Node:

- Imports: `import { createClient } from "npm:@supabase/supabase-js@2"`.
- Env: `Deno.env.get("KEY")`. `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` are auto-injected.
- Other secrets: set once per env with `supabase secrets set KEY=value`.

## NPM Scripts

### Local development

- `npm run db:local:dev` — Start the local Supabase stack (Docker).
- `npm run db:local:reset` — Re-apply migrations + seed to the local DB.
- `npm run db:local:stop` — Stop the local stack.
- `npm run functions:dev` — Serve edge functions locally.

### Database

- `npm run db:link:dev` / `db:link:prod` — Link the CLI to the dev or prod project.
- `npm run db:migration:new <name>` — Create a new migration file.
- `npm run db:push` — Apply pending migrations to the linked remote DB.
- `npm run db:diff -- <name>` — Auto-generate migration SQL from local schema changes.

### Deployment

Match deployments to your git branch:

- **`dev` / feature branches →** `npm run db:link:dev && npm run db:push && npm run functions:deploy`
- **`main` →** `npm run db:link:prod && npm run db:push && npm run functions:deploy`

## Environment Variables

### Edge Functions (auto-injected + manual secrets)

- `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` — auto.
- Anything else — `supabase secrets set KEY=value --project-ref <ref>`.

### Local scripts (`backend/.env`, gitignored)

Used by ad-hoc `tsx` / `node` scripts you write under `backend/`. Template:

- `SUPABASE_URL` / `SUPABASE_SERVICE_ROLE_KEY` — **dev** project (always).
- `PROD_SUPABASE_URL` / `PROD_SUPABASE_SERVICE_ROLE_KEY` — only for scripts run with `--prod`.

See `backend/.env.template`.

## Gotchas

- **Edge functions have wall-clock limits**. For anything long-running (scraping, AI extraction, image generation), add a job-queue table and a background worker (Trigger.dev, Inngest, or a Postgres `pg_cron` + worker pattern).
- **RLS bypass via `SERVICE_ROLE_KEY`**. Use it only in server-side code (edge functions, backend scripts) — never in the iOS app.
- **`config.toml` is read by the CLI for local dev only**. Production project settings live in the Supabase dashboard; some `config.toml` flags (auth providers, storage buckets) can also be pushed via `supabase db push --include-config`.
