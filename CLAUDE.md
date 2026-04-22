# Pronghorn — Claude Code Configuration

## What this project is

Pronghorn is an open-source, AI-powered SDLC platform originally built by the **Government of Alberta, Ministry of Technology and Innovation** (upstream: https://github.com/AlbertaGovernment/pronghorn, live at https://pronghorn.red). It turns unstructured requirements into production code using multi-agent AI orchestration across Design, Audit, Build, Present, and Deploy modes.

**This repo is Gurpreet's fork**, self-hosted on his homelab with Docker + nginx and pointed at his own Supabase project (`rftbiygzpmbyxlinmuaa`). Gurpreet uses Claude Code to **add features to this fork**. Match Pronghorn's existing patterns — do not impose external conventions.

Full product tour: [README.md](./README.md).

## Global defaults waiver

This project does **not** follow Gurpreet's global `~/.claude/CLAUDE.md` stack defaults. Specifically:

- **No Next.js, no .NET, no Python, no local Postgres, no Vitest.** The stack is Vite + React 18 SPA + Supabase Cloud + Bun + Playwright.
- The mandatory `pm-spec → architect → …` pipeline is **relaxed** for Pronghorn. Small features: implement directly, mirroring an existing feature folder. Large changes (new top-level mode, new auth pathway, new DB provider, schema changes touching multiple tables): talk through the approach first.
- `code-reviewer` is still mandatory before merge. Build verification = `bun run build` exits 0 **plus** the grep check below.
- When in doubt about patterns: read neighbouring code first, `docs/` second, ask Gurpreet third.

## Authoritative references

Before any non-trivial change, read the relevant guide:

- [`docs/pronghorn-deployment-handoff.md`](./docs/pronghorn-deployment-handoff.md) — every fork change, env vars, Edge Function secrets, troubleshooting table.
- [`docs/pronghorn-deployment-guide.md`](./docs/pronghorn-deployment-guide.md) — step-by-step self-deployment walkthrough (what/before/after/why/validate per change).
- [`docs/pronghorn-database-guide.md`](./docs/pronghorn-database-guide.md) — full Postgres schema reference. **Read before any schema, RLS, or migration work.**
- [`docs/pronghorn-sa-deployment-package.md`](./docs/pronghorn-sa-deployment-package.md) — solution-architect-grade deployment package.
- [`README.md`](./README.md) — product and feature source of truth.
- `.lovable/plan.md` — Lovable's internal plan (context only; do not edit).

## Stack (as-built on `main`)

- **Frontend:** Vite 5.4 + React 18.3 + TypeScript 5.8 (lenient: `noImplicitAny: false`, strict null checks off), React Router 6.30.
- **UI:** Tailwind 3.4, shadcn/ui (40+ Radix primitives), lucide-react, sonner, React Flow 11.11, Monaco Editor, Recharts, jsPDF/docx/ExcelJS, react-force-graph-2d.
- **State/data:** TanStack Query 5.83, React Context, `@supabase/supabase-js` 2.81.
- **Forms:** react-hook-form 7.61 + zod 3.25 + `@hookform/resolvers`.
- **Backend:** Supabase Cloud — Postgres + Auth + 58 Edge Functions (Deno) + Realtime + Storage. Project ID `rftbiygzpmbyxlinmuaa`.
- **Deploy:** Docker (multi-stage: Bun builder → nginx runner) on homelab; `.env` drives compose build args; PWA + Brotli/Gzip compression baked into the Vite build.
- **Package manager:** **Bun** (`bun.lockb` is authoritative). `package-lock.json` is stale — don't update it.
- **Tests:** Playwright only (via `lovable-agent-playwright-config`). No Vitest.
- **Build pin:** Rollup `4.24.0` via `package.json` `overrides` (fixes a build crash). Don't bump casually.

## Run / build / deploy

`Makefile` is the canonical interface — use it:

```
make help                # list targets
make build               # docker compose build (cached)
make up                  # docker compose up -d
make deploy              # build + up
make rebuild             # down + cached build + up
make rebuild-clean       # down + --no-cache build + up (after .env or package.json changes)
make logs                # tail frontend logs
make status              # ps
make health              # container healthcheck status
make shell               # exec into running container
make supabase-push       # npx supabase db push
make supabase-functions  # npx supabase functions deploy
```

Non-Docker local dev:

- `bun install`
- `bun dev` — Vite dev server on port **8080**
- `bun run build` / `bun run build:dev` / `bun run preview`
- `bun run lint`

Supabase CLI: `supabase login`, `supabase link --project-ref rftbiygzpmbyxlinmuaa`, then the make targets above or `npx supabase functions deploy <name>` for single-function deploys.

## Env var convention (fork-critical)

This is the single most important rule for any new frontend code:

- **Never hardcode the app URL, Supabase URL, or Supabase anon key.** Always read from `import.meta.env.VITE_*`.
- `VITE_APP_URL` → use as `import.meta.env.VITE_APP_URL ?? window.location.origin`.
- `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `VITE_SUPABASE_PROJECT_ID`, `VITE_ADMIN_KEY` — direct reads.
- `VITE_*` values are **compile-time** — Vite substitutes them into the JS bundle at `bun run build`. Changing them requires `make rebuild-clean` (or `docker compose build --no-cache && docker compose up -d`). Container env overrides at runtime will **not** work.
- `.env` (loaded by `docker compose --env-file`) and `.env.local` (gitignored, local dev) hold the `VITE_*` values. See [`docs/pronghorn-deployment-handoff.md`](./docs/pronghorn-deployment-handoff.md) for the full table.
- **Edge Function secrets** live in the Supabase dashboard (Edge Functions → Manage secrets), not in `.env`: `ANTHROPIC_API_KEY`, `SIGNUP_CODE`, `RESEND_API_KEY`, `APP_URL`.

**Grep check before every commit** — both must return zero matches in new/changed files:

```
pronghorn.red
obkzdksfayygnrzdqoam
```

If you need the app URL in a Supabase Edge Function, use `Deno.env.get("APP_URL")`.

## Repo layout

```
src/
  components/           # folder-per-feature; NO barrel index.ts files
    ui/                 # shadcn/ui primitives (40+ Radix-based components)
    canvas/ build/ deploy/ audit/ present/ buildbook/ artifacts/
    collaboration/ dashboard/ project/ …
  pages/                # route-level components
    project/            # project-scoped sub-routes
  hooks/                # 28+ custom hooks; useRealtime* for Supabase subs
  contexts/             # AuthContext, AdminContext
  integrations/supabase/
    client.ts           # singleton — import { supabase } from '@/integrations/supabase/client'
    types.ts            # AUTO-GENERATED (8k+ lines) — never hand-edit
  lib/                  # shared utilities
  assets/ styles/
supabase/
  config.toml           # project_id = rftbiygzpmbyxlinmuaa (fork's, not upstream's)
  functions/            # 58 Deno Edge Functions
  migrations/           # 238+ SQL migrations
docs/                   # see Authoritative references above
Dockerfile  nginx.conf  docker-compose.yml  Makefile
.lovable/               # Lovable tooling — do not edit
```

Path alias: `@/*` → `src/*`.

## Supabase patterns

- **Client:** `import { supabase } from '@/integrations/supabase/client'`. Never construct a second client.
- **Types:** `src/integrations/supabase/types.ts` is **auto-generated**. After any migration, regenerate with the Supabase CLI and commit the updated file. Hand-edited PRs will break.
- **Migrations:** add to `supabase/migrations/YYYYMMDDHHMMSS_description.sql`. Apply via `make supabase-push`. Regenerate types.
- **RLS:** mandatory on every new table. Project-scoped access must go through the `authorize_project_access()` / `require_role()` RPCs. Role hierarchy: `owner > editor > viewer` (from `project_tokens.role`).
- **Platform admin:** `user_roles` table + `app_role` enum (`admin`, `user`). `VITE_ADMIN_KEY` is only a frontend gate — the DB still enforces via `user_roles`.
- **Edge Functions:** one folder per function under `supabase/functions/<name>/index.ts`. Most have `verify_jwt = false` in `supabase/config.toml` and validate tokens via RPC. Mirror an existing function's structure (CORS, token validation, error envelope). Deploy with `make supabase-functions` or `npx supabase functions deploy <name>`.
- **Realtime:** new live features follow the `useRealtime<Thing>` hook pattern in `src/hooks/`. Always clean up channels on unmount.
- **Schema reference:** [`docs/pronghorn-database-guide.md`](./docs/pronghorn-database-guide.md) documents every table group (Identity & Access, Projects, Requirements, Standards, Tech Stacks, Canvas, Audit, Build, Deploy, Agent, …).

## Frontend conventions

- PascalCase component files, camelCase hooks prefixed `use*`, Realtime hooks prefixed `useRealtime*`.
- Tailwind + shadcn/ui. Use the HSL variables already defined in `tailwind.config.ts`. Don't introduce a parallel design system.
- Forms: react-hook-form + zod + shadcn `Form` primitives.
- Icons: **lucide-react only**.
- Toasts: sonner (already wired).
- Dark mode via Tailwind `class` strategy. `next-themes` is in deps — check actual usage before adopting it in new code.
- `tsconfig` is intentionally lenient. Match the surrounding code's strictness, don't ratchet it tighter in isolated files.

## Lovable coexistence

- `lovable-tagger`'s `componentTagger()` runs in dev mode inside `vite.config.ts`. Keep it.
- Upstream Alberta + Lovable may push to the public repo. This fork deliberately diverges — when pulling upstream, **carefully review** any re-introduction of `pronghorn.red` or `obkzdksfayygnrzdqoam`. Run the grep check on every merge.
- Don't restructure Lovable-generated folders casually.

## How to add a feature (happy path)

1. Find the closest existing feature folder under `src/components/<feature>/` and mirror its structure.
2. **DB-bound?** Write a migration, `make supabase-push`, regenerate `types.ts`, commit. Update [`docs/pronghorn-database-guide.md`](./docs/pronghorn-database-guide.md) if the schema change is notable. RLS is mandatory.
3. **Backend logic?** Add an Edge Function mirroring an existing one. Register it in `supabase/config.toml` if it needs `verify_jwt = false`. Set any new secrets in the Supabase dashboard. Deploy.
4. **Realtime?** Add a `useRealtime<Thing>` hook following existing examples.
5. Wire into a page under `src/pages/` and the existing router.
6. **New `VITE_*` var?** Add to `.env` / `.env.local`, `Dockerfile` (ARG + ENV), `docker-compose.yml` (build args). Document in [`docs/pronghorn-deployment-handoff.md`](./docs/pronghorn-deployment-handoff.md). Remember: `make rebuild-clean` after env changes.
7. Playwright test following the project's existing convention.
8. `bun run lint` and `bun run build` — both exit 0.
9. Grep check: no new matches for `pronghorn.red` or `obkzdksfayygnrzdqoam`.
10. Touching Docker? Rebuild `--no-cache` before testing.

## Known tech debt / gotchas

- **Pending fix** — `supabase/functions/send-auth-email/index.ts` has hardcoded `https://pronghorn.red`. Replace with `Deno.env.get("APP_URL") ?? "https://pronghorn.red"` and set the `APP_URL` Edge Function secret. Safe quick win if a task touches email flows.
- Rollup pinned to `4.24.0` via `overrides` — don't bump without testing the full build.
- Bun and npm lockfiles both present; Bun is authoritative. Don't regenerate `package-lock.json`.
- `types.ts` is auto-generated and huge — never hand-edit.
- Docker healthchecks on Alpine images must use `wget -qO-`, not `curl` (curl is not in BusyBox).
- `VITE_*` env changes require an image rebuild — runtime container env overrides do not apply.
- Supabase anon key appearing in client bundles is **intentional and safe** (RLS is the security boundary).

## Sub-agent routing (relaxed)

Implement small features directly. Bring in agents only when scope genuinely warrants it (multi-file schema change, new Edge Function + RLS + UI wiring, or cross-cutting refactors). When used, map to Pronghorn's stack:

- `database-architect` → Supabase migrations + RLS (not EF Core or raw Postgres).
- `api-designer` → new Edge Functions as "APIs".
- `ui-ux-designer` → React + Tailwind + shadcn component specs.
- `ai-ml-engineer` → agent orchestration Edge Functions (the `*-agent*` / `*-orchestrator*` functions).
- `code-reviewer` → **mandatory pre-merge.** Passing criteria: `bun run build` exits 0, `bun run lint` exits 0, grep check clean, no hand-edits to `types.ts`.

## Scope of Claude's help here

Gurpreet uses Claude Code to add features and services to this Pronghorn fork. Match Pronghorn's patterns, not external defaults. **Ask before** introducing a new dependency, new test framework, new architectural pattern, or any change that re-introduces upstream Alberta values (`pronghorn.red`, `obkzdksfayygnrzdqoam`).
