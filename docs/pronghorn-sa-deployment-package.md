# Pronghorn — Solution Architect Deployment Package
**Prepared for:** Gurpreet Rai  
**Target:** Home Web Server (LAN / Self-Hosted)  
**Stack:** Vite + React SPA · Docker + Nginx · Supabase (Cloud) · 56 Deno Edge Functions  
**Estimated Total Time:** 2.5–3 hours (first deployment)

---

## Table of Contents

1. [System Architecture Overview](#1-system-architecture-overview)
2. [Component Inventory](#2-component-inventory)
3. [Pre-Deployment Requirements](#3-pre-deployment-requirements)
4. [Phase 0 — Accounts & API Keys](#4-phase-0--accounts--api-keys)
5. [Phase 1 — Code Changes (9 files, 18 line edits)](#5-phase-1--code-changes)
6. [Phase 2 — New Files to Create](#6-phase-2--new-files-to-create)
7. [Phase 3 — Supabase Cloud Configuration](#7-phase-3--supabase-cloud-configuration)
8. [Phase 4 — Build & Launch](#8-phase-4--build--launch)
9. [Phase 5 — End-to-End Validation](#9-phase-5--end-to-end-validation)
10. [Phase 6 — Domain + HTTPS (Future State)](#10-phase-6--domain--https-future-state)
11. [Operational Runbook](#11-operational-runbook)
12. [Troubleshooting Reference](#12-troubleshooting-reference)
13. [Security Checklist](#13-security-checklist)
14. [Complete Change Inventory](#14-complete-change-inventory)
15. [Database Schema Reference](#15-database-schema-reference)
16. [User Setup & Management](#16-user-setup--management)
17. [Adding Standards & Tech Stacks](#17-adding-standards--tech-stacks)

---

## 1. System Architecture Overview

### How the pieces fit together

Pronghorn is a single-page React application. At runtime it has no backend of its own — all persistence, authentication, and AI logic lives in Supabase (cloud-managed Postgres + Auth + 56 Deno edge functions). Your home server's only job is to serve the compiled static JavaScript bundle over HTTP.

```
Your Home Network
┌─────────────────────────────────────────────────┐
│  Browser (192.168.x.x:8080)                     │
│       │                                         │
│       ▼                                         │
│  Docker Container                               │
│  ┌──────────────────────────────────────┐      │
│  │  Nginx 1.27-alpine                   │      │
│  │  Serves: dist/ (compiled React SPA)  │      │
│  │  Port: 80 (mapped to host 8080)      │      │
│  └──────────────────────────────────────┘      │
└─────────────────────────────────────────────────┘
         │ HTTPS API calls
         ▼
Supabase Cloud (your project)
┌─────────────────────────────────────────────────┐
│  Auth (JWT · Email · Google · Azure OAuth)      │
│  Postgres DB (15+ tables, RLS, RPCs)            │
│  Edge Functions (56 Deno functions)             │
│  Storage (artifacts, file uploads)              │
└─────────────────────────────────────────────────┘
         │ LLM API calls (from edge functions)
         ▼
External AI Providers
  Gemini API · Anthropic API · GitHub (PAT)
```

### The Vite compile-time variable trap

The most important architectural fact about this codebase: **all `VITE_*` environment variables are baked into the JavaScript bundle at build time, not read at runtime**. This means:

- You cannot change Supabase credentials by setting environment variables on a running container.
- Every time you change a `VITE_*` value (new Supabase project, new domain, etc.) you must **rebuild the Docker image**.
- The original codebase had a critical bug: `client.ts` hardcoded Alberta's Supabase credentials directly — it didn't even read `VITE_*` vars. Fix 1 resolves this.

---

## 2. Component Inventory

| Component | Technology | Location | Your Responsibility |
|-----------|-----------|----------|-------------------|
| Frontend SPA | React 18 + Vite + TypeScript | Your Docker container | Build + serve |
| Web server | Nginx 1.27-alpine | Inside container | Configure (nginx.conf) |
| Container runtime | Docker + Compose | Your home server | Install + operate |
| Database | Supabase Postgres | Supabase cloud | Run migrations |
| Authentication | Supabase Auth | Supabase cloud | Configure redirect URLs |
| Edge Functions | 56 Deno functions | Supabase cloud | Deploy + set secrets |
| File storage | Supabase Storage | Supabase cloud | Automatic on project creation |
| LLM — primary | Google Gemini | External API | Provide API key |
| LLM — chat | Anthropic Claude | External API | Provide API key |
| Repo integration | GitHub PAT | External | Provide PAT |

---

## 3. Pre-Deployment Requirements

### Hardware & OS

- Any machine capable of running Docker (Linux, macOS, Windows with WSL2)
- Minimum 2 GB RAM for Docker build (Node.js compilation)
- Minimum 10 GB free disk space (Docker images + build layers)
- Network: standard home LAN with static or DHCP-reserved IP recommended

### Software

| Tool | Version | Install |
|------|---------|---------|
| Docker Engine or Docker Desktop | 24+ | docker.com/get-docker |
| Docker Compose plugin | V2 | Included with Docker Desktop; `apt install docker-compose-plugin` on Linux |
| Supabase CLI | Latest | `npx supabase` (see note below) |
| Node.js | 18+ (for CLI only) | nodejs.org |
| Git | Any | git-scm.com |

### Accounts required

| Service | URL | Cost |
|---------|-----|------|
| Supabase | supabase.com | Free tier sufficient |
| Google AI Studio | aistudio.google.com | Free tier has limits; pay-as-you-go for heavy use |
| Anthropic Console | console.anthropic.com | Pay-as-you-go |
| GitHub | github.com | Free |

---

## 4. Phase 0 — Accounts & API Keys

Complete this phase before touching any code. You will need all of these values for `.env.local`.

### 4.1 Create Supabase project

1. Go to supabase.com → New Project
2. Choose the region closest to your physical location (reduces edge function latency)
3. Set a strong database password and save it securely
4. Wait approximately 2 minutes for provisioning

After provisioning, collect the following from your dashboard:

| Value | Location in Dashboard |
|-------|----------------------|
| Project URL | Settings → API → Project URL |
| Anon (public) key | Settings → API → Project API keys → `anon public` |
| Reference ID | Settings → General → Reference ID |

### 4.2 Get API keys

**Gemini (required — primary LLM)**
1. Go to aistudio.google.com → Get API key
2. Enable "Generative Language API" in Google Cloud Console for your project

**Anthropic (required — streaming chat)**
1. Go to console.anthropic.com → API Keys → Create key
2. Copy the key — it's only shown once

**GitHub PAT (required — repository and build features)**
1. GitHub → Settings → Developer Settings → Personal Access Tokens → Tokens (classic)
2. Generate new token with scopes: `repo` (full), `read:org`
3. Copy the token — shown once only

---

## 5. Phase 1 — Code Changes

Work through these changes in order. All are required unless marked optional.

> **Important — fixing `client.ts` alone is not enough.** A full audit of the source revealed 11 additional files with hardcoded Supabase credentials in raw `fetch()` calls — both the project URL in fetch endpoints and the anon key in `Authorization: Bearer` headers. Two separate grep passes were required to catch both. Changes 1–9 are the originally documented fixes; Change 10 covers the full credential audit including both patterns. See Change 10 for the complete file list and the greps you must run after every upstream pull.

### Change 1 — Supabase Client (CRITICAL)

**File:** `src/integrations/supabase/client.ts`  
**Lines:** 5–6

This is the most important fix. Without it, every user of your deployment authenticates against Alberta's Supabase project.

**Before:**
```typescript
const SUPABASE_URL = "https://obkzdksfayygnrzdqoam.supabase.co";
const SUPABASE_PUBLISHABLE_KEY = "eyJhbGci...";
```

**After:**
```typescript
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL as string;
const SUPABASE_PUBLISHABLE_KEY = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string;
```

**Validate:** After building, run this inside the container — must return empty:
```bash
docker exec pronghorn-frontend grep -ro "obkzdksfayygnrzdqoam" /usr/share/nginx/html/assets/
```
Any match means a file was missed and needs to be fixed, then the image rebuilt.

---

### Change 2 — Supabase CLI Config

**File:** `supabase/config.toml`  
**Line:** 1

**Before:**
```toml
project_id = "obkzdksfayygnrzdqoam"
```

**After:**
```toml
project_id = "YOUR_NEW_PROJECT_REFERENCE_ID"
```

**Validate:** `supabase status` should report your project ID, not the old one.

---

### Change 3 — OAuth Redirect URLs

**File:** `src/contexts/AuthContext.tsx`  
**Lines:** 104, 115

**Before (both occurrences):**
```typescript
redirectTo: 'https://pronghorn.red/dashboard',
```

**After (both occurrences):**
```typescript
redirectTo: `${import.meta.env.VITE_APP_URL ?? window.location.origin}/dashboard`,
```

The `window.location.origin` fallback means OAuth redirect works from any LAN IP without setting `VITE_APP_URL` — useful if you access from multiple devices. Set `VITE_APP_URL` in `.env.local` if you have a fixed domain.

**Validate:** During a Google/Azure login attempt, check the browser's network tab for the OAuth redirect_uri — it must contain your IP/domain.

---

### Change 4 — Share URL Hook

**File:** `src/hooks/useProjectUrl.ts`  
**Line:** 41

**Before:**
```typescript
const getShareUrl = (path: string, domain: string = "https://pronghorn.red"): string => {
```

**After:**
```typescript
const getShareUrl = (path: string, domain: string = import.meta.env.VITE_APP_URL ?? window.location.origin): string => {
```

**Validate:** Copy a share link from Project → Settings → Token Management. It must start with your IP/domain.

---

### Change 5 — Share Artifact Dialog

**File:** `src/components/artifacts/ShareArtifactDialog.tsx`  
**Lines:** 45–46

**Before:**
```typescript
const baseUrl = "https://pronghorn.red";
const apiBaseUrl = "https://api.pronghorn.red/functions/v1/serve-artifact";
```

**After:**
```typescript
const baseUrl = import.meta.env.VITE_APP_URL ?? window.location.origin;
const apiBaseUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/serve-artifact`;
```

Note: `baseUrl` points to your Nginx frontend. `apiBaseUrl` points to your Supabase edge function — the function that physically serves stored files. The original used a custom CNAME (`api.pronghorn.red`); you use your Supabase project URL directly.

**Validate:** Artifacts tab → share an artifact → toggle Publish on → Raw URL must contain your Supabase project URL.

---

### Change 6 — Anonymous Project Warning

**File:** `src/components/dashboard/AnonymousProjectWarning.tsx`  
**Line:** 29

**Before:**
```typescript
const shareUrl = `https://pronghorn.red/project/${projectId}/settings/t/${shareToken}`;
```

**After:**
```typescript
const shareUrl = `${import.meta.env.VITE_APP_URL ?? window.location.origin}/project/${projectId}/settings/t/${shareToken}`;
```

---

### Change 7 — Token Management Component (5 occurrences)

**File:** `src/components/project/TokenManagement.tsx`  
**Lines:** 212, 225, 274, 303, 304

Find all occurrences with:
```bash
grep -n "pronghorn.red" src/components/project/TokenManagement.tsx
```

**Before (all 5):**
```typescript
`https://pronghorn.red/project/${projectId}/...`
```

**After (all 5):**
```typescript
`${import.meta.env.VITE_APP_URL ?? window.location.origin}/project/${projectId}/...`
```

---

### Change 10 — Hardcoded Supabase Credential Audit (11 files)

**Required.** Fixing `client.ts` only fixes calls made through the Supabase JS client (`supabase.functions.invoke()`). A grep of the full source revealed 11 additional files that used raw `fetch()` calls with the project URL and/or anon key hardcoded directly as string literals — completely bypassing the client. These components were built on Lovable which auto-injected environment context, so the developers hardcoded values as a shortcut that worked on Lovable but breaks on any other deployment.

**The pattern in every affected file:**
```typescript
// Before
fetch('https://obkzdksfayygnrzdqoam.supabase.co/functions/v1/...')
const supabaseAnonKey = 'eyJhbGci...hardcoded...';

// After
fetch(`${import.meta.env.VITE_SUPABASE_URL}/functions/v1/...`)
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
```

A **second pass** was also required for hardcoded anon keys in `Authorization: Bearer` headers — a separate string in the same fetch calls that the URL grep missed entirely:

```typescript
// Before
Authorization: `Bearer eyJhbGci...hardcoded key...`

// After
Authorization: `Bearer ${import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY}`
```

**Special case — `ArtifactCollaborator.tsx`:** This file used a fallback pattern that still embedded the hardcoded key, and also used the wrong env var name:

```typescript
// Before — wrong var name + hardcoded fallback
`Bearer ${import.meta.env.VITE_SUPABASE_ANON_KEY || 'eyJhbGci...'}`

// After — correct var name, no fallback
`Bearer ${import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY}`
```

`VITE_SUPABASE_ANON_KEY` does not exist. The correct variable is `VITE_SUPABASE_PUBLISHABLE_KEY`.

**Files requiring fixes (URL + Authorization header):**

| File | Hardcoded URL | Hardcoded Bearer key |
|------|:---:|:---:|
| `src/hooks/useAuditPipeline.ts` | BASE_URL constant | — |
| `src/pages/project/Chat.tsx` | 2 occurrences | 2 occurrences |
| `src/pages/project/Present.tsx` | 2 occurrences | — |
| `src/pages/project/Specifications.tsx` | 1 occurrence | 1 occurrence |
| `src/pages/project/Artifacts.tsx` | 1 occurrence | 1 occurrence |
| `src/components/artifacts/VisualRecognitionDialog.tsx` | 1 occurrence | 1 occurrence |
| `src/components/artifacts/VisualRecognitionImportDialog.tsx` | 1 occurrence | 1 occurrence |
| `src/components/build/UnifiedAgentInterface.tsx` | URL + anon key variable | — |
| `src/components/deploy/DatabaseAgentInterface.tsx` | URL + anon key variable | — |
| `src/components/buildbook/BuildBookChat.tsx` | 1 occurrence | 1 occurrence |
| `src/components/collaboration/ArtifactCollaborator.tsx` | — | Fallback pattern + wrong var name |

**Full audit — run both greps. Both must return empty before rebuilding:**
```bash
# Check for hardcoded project URL
grep -rn "obkzdksfayygnrzdqoam" src/

# Check for hardcoded anon key
grep -rn "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ia3pka3NmYXl5Z25yemRxb2FtIiwicm9sZSI6ImFub24i" src/
```

**Validate after rebuild — both must return empty:**
```bash
docker exec pronghorn-frontend grep -ro "obkzdksfayygnrzdqoam" /usr/share/nginx/html/assets/
docker exec pronghorn-frontend grep -ro "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9" /usr/share/nginx/html/assets/
```

> **Upstream sync warning:** After every pull from `pronghorn-red/pronghorn`, run **both** greps above before rebuilding. New components from the upstream team will likely contain both hardcoded patterns. Two separate greps are required — the URL and the anon key are different strings in different parts of the same fetch calls.

---

### Change 11 — index.html Metadata (cosmetic)

**File:** `index.html`  
**Lines:** 14, 28–31, 37–40

Update canonical URL, og:url, og:title, og:image, and equivalent Twitter card tags to reflect your instance. This does not affect functionality — it controls link previews in Slack, Discord, etc.

---

### Change 12 — Branding Links (optional)

**Files:** `src/pages/Landing.tsx` line 944, `src/pages/Viewer.tsx` lines 230 and 368

Change the three `<a href="https://pronghorn.red">` attribution links to your own domain if you want to rebrand the instance. MIT license permits this.

---

## 6. Phase 2 — New Files to Create

These 5 files do not exist in the repo. Create them in the repo root.

### File 1 — `.env.local`

```env
# ── Supabase ──────────────────────────────────────────────
VITE_SUPABASE_URL=https://YOUR_PROJECT_ID.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=YOUR_SUPABASE_ANON_KEY
VITE_SUPABASE_PROJECT_ID=YOUR_PROJECT_ID

# ── Admin panel password ──────────────────────────────────
VITE_ADMIN_KEY=CHOOSE_A_STRONG_PASSWORD_HERE

# ── App URL (for OAuth redirects and share links) ─────────
# Use http:// for LAN-only. Use https:// once you have TLS.
VITE_APP_URL=http://192.168.1.X:8080
```

**Security:** Add these two lines to `.gitignore` immediately:
```
.env.local
.env.production
```

---

### File 2 — `Dockerfile`

> **Context:** This repo was built entirely on Lovable's managed cloud platform — no Dockerfile ever existed. Lovable abstracts the build environment, so dependencies were never pinned, the lockfile was allowed to drift, and nothing needed to be. Containerizing it required solving several gaps manually. None of these are bugs in the app itself.

**Final working configuration:**

```dockerfile
# ── Stage 1: Build ─────────────────────────────────────────────────
FROM oven/bun:1-alpine AS builder

WORKDIR /app

COPY package.json bun.lockb ./
RUN bun install

COPY . .

ARG VITE_SUPABASE_URL
ARG VITE_SUPABASE_PUBLISHABLE_KEY
ARG VITE_SUPABASE_PROJECT_ID
ARG VITE_ADMIN_KEY
ARG VITE_APP_URL

ENV VITE_SUPABASE_URL=$VITE_SUPABASE_URL
ENV VITE_SUPABASE_PUBLISHABLE_KEY=$VITE_SUPABASE_PUBLISHABLE_KEY
ENV VITE_SUPABASE_PROJECT_ID=$VITE_SUPABASE_PROJECT_ID
ENV VITE_ADMIN_KEY=$VITE_ADMIN_KEY
ENV VITE_APP_URL=$VITE_APP_URL

RUN bun run build

# ── Stage 2: Serve ─────────────────────────────────────────────────
FROM nginx:1.27-alpine AS runner

RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/pronghorn.conf
COPY --from=builder /app/dist /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
```

**Also required — `package.json` overrides block:**

```json
"overrides": {
  "rollup": "4.24.0"
}
```

Add this to `package.json`, then run `npx bun install` locally and commit the updated `bun.lockb` before building the container.

#### Build issues encountered during containerization

**Issue 1 — Wrong package manager (`node:20-alpine` + `npm ci`)**

The initial Dockerfile used `node:20-alpine` and `npm ci --frozen-lockfile`. This failed because the repo uses Bun — `package-lock.json` is not maintained.

```
npm error `npm ci` can only install packages when your package.json
and package-lock.json are in sync.
```

Fix: Switch base image to `oven/bun:1-alpine`, use `bun install`, use `bun run build`.

---

**Issue 2 — Lockfile out of sync (`--frozen-lockfile` fails)**

After switching to Bun, `bun install --frozen-lockfile` failed because `bun.lockb` had drifted out of sync with `package.json`. On Lovable's platform this never surfaced — their build environment resolved dependencies independently.

```
error: lockfile had changes, but lockfile is frozen
note: try re-running without --frozen-lockfile
```

Fix: Remove `--frozen-lockfile` from the Dockerfile (`RUN bun install`). Long-term: run `npx bun install` locally and commit `bun.lockb` after any `package.json` change.

---

**Issue 3 — Rollup version conflict crashing the build**

`bun run build` failed with a cryptic Rollup parse error. Bun, resolving dependencies fresh inside Alpine, pulled Rollup `4.60.x` — a newer version with breaking changes. The codebase was built against Rollup `4.24.0`. Lovable's fixed build environment masked this entirely.

```
Error at parseAsync (unknown)
at setSource (rollup/dist/es/shared/node-entry.js:15923:37)
error: script "build" exited with code 1
```

Fix: Add a Rollup version override to `package.json`, regenerate `bun.lockb` locally, rebuild container with `--no-cache`.

```json
"overrides": {
  "rollup": "4.24.0"
}
```

---

**Issue 4 — PWA plugin incorrectly suspected (red herring)**

The Rollup error showed `[vite-plugin-pwa:build]` in the stack trace. The PWA plugin was removed from `vite.config.ts` as a suspected cause. It was not the cause — the PWA plugin was simply the first module Rollup attempted to process, so it appeared first in the error. Once Rollup was pinned to `4.24.0`, the PWA plugin was restored and the build succeeded with PWA fully intact.

---

### File 3 — `nginx.conf`

```nginx
server {
    listen 80;
    server_name _;

    root /usr/share/nginx/html;
    index index.html;

    # Serve pre-compressed .gz files (Vite produces these automatically)
    gzip_static on;

    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;

    # Long cache for hashed assets (safe — Vite content-hashes all filenames)
    location /assets/ {
        expires 30d;
        add_header Cache-Control "public, immutable";
    }

    # Medium cache for static assets
    location ~* \.(ico|png|svg|webmanifest)$ {
        expires 7d;
        add_header Cache-Control "public";
    }

    # SPA fallback — critical for React Router
    # If the file exists, serve it; otherwise serve index.html
    location / {
        try_files $uri $uri/ /index.html;
    }

    # Never cache index.html — it bootstraps the entire app
    location = /index.html {
        add_header Cache-Control "no-cache, no-store, must-revalidate";
        expires 0;
    }
}
```

**Important:** Do NOT add `brotli_static on`. The standard `nginx:1.27-alpine` image does not include the ngx_brotli module. `gzip_static on` is included and sufficient.

---

### File 4 — `docker-compose.yml`

```yaml
services:
  frontend:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        VITE_SUPABASE_URL: ${VITE_SUPABASE_URL}
        VITE_SUPABASE_PUBLISHABLE_KEY: ${VITE_SUPABASE_PUBLISHABLE_KEY}
        VITE_SUPABASE_PROJECT_ID: ${VITE_SUPABASE_PROJECT_ID}
        VITE_ADMIN_KEY: ${VITE_ADMIN_KEY}
        VITE_APP_URL: ${VITE_APP_URL}
    image: pronghorn-frontend:local
    container_name: pronghorn-frontend
    restart: unless-stopped
    ports:
      - "8080:80"
    healthcheck:
      test: ["CMD-SHELL", "wget -qO- http://localhost/index.html || exit 1"]
      interval: 30s
      timeout: 5s
      retries: 3
      start_period: 15s
```

### File 5 — `Makefile`

Wraps all Docker and Supabase operations into single-word commands. See the full target reference in Phase 4.

```makefile
.PHONY: build up down restart rebuild rebuild-clean logs status health \
        shell prune prune-all deploy supabase-push supabase-functions help

ENV_FILE  := .env.local
CONTAINER := pronghorn-frontend
COMPOSE   := docker compose --env-file $(ENV_FILE)

.DEFAULT_GOAL := help

build:          ; $(COMPOSE) build
rebuild-clean:  ; $(COMPOSE) build --no-cache
up:             ; $(COMPOSE) up -d
deploy: build up
down:           ; $(COMPOSE) down
restart: down build up
rebuild: down rebuild-clean up
status:         ; $(COMPOSE) ps
health:         ; docker inspect $(CONTAINER) --format='{{.State.Health.Status}}'
logs:           ; $(COMPOSE) logs -f frontend
shell:          ; docker exec -it $(CONTAINER) /bin/sh
prune:          ; $(COMPOSE) down --rmi local
prune-all:      ; $(COMPOSE) down --rmi all --volumes --remove-orphans
supabase-push:  ; npx supabase db push
supabase-functions: ; npx supabase functions deploy

help:
	@echo "" && echo "Pronghorn — make targets" && echo ""
	@awk 'BEGIN {FS=":.*##"} /^##/{desc=$$0; sub(/^## /,"",desc)} \
	     /^[a-zA-Z_-]+:/{printf "  \033[36m%-20s\033[0m %s\n",$$1,desc; desc=""}' $(MAKEFILE_LIST)
	@echo ""
```

---

## 7. Phase 3 — Supabase Cloud Configuration

All steps below are done via Supabase CLI and the Supabase Dashboard web UI. No code changes required.

### 7.1 Link CLI to your project

> **Windows note:** `npm install -g supabase` is not supported. Use `npx supabase` for all CLI commands. If winget/Scoop are unavailable, `npx` is the most reliable option on Windows.

```bash
npx supabase login
npx supabase link --project-ref YOUR_PROJECT_REFERENCE_ID
```

### 7.2 Push database migrations

```bash
npx supabase db push
```

This applies all 15+ migration files from `supabase/migrations/` to your Postgres database in order. It creates all tables, enums, indexes, RLS policies, and RPC functions.

> **Known issue — `ERROR: cannot change return type of existing function (SQLSTATE 42P13)`**
>
> The migration chain modifies `get_repo_files_with_token` across multiple files, changing its return type mid-sequence. PostgreSQL allows `CREATE OR REPLACE` for a function only if the return type stays the same — a type change requires a `DROP` first. The original team's database was never affected because it was already in the final state. A fresh `db push` replays every migration in order and hits the conflict.
>
> **Fix:** Before running `db push`, open Supabase Dashboard → SQL Editor and run:
> ```sql
> DROP FUNCTION IF EXISTS public.get_repo_files_with_token(uuid, uuid, text);
> DROP FUNCTION IF EXISTS public.get_repo_files_with_token(uuid, text);
> DROP FUNCTION IF EXISTS public.get_repo_files_with_token(uuid);
> ```
> Drop all three signature variants — PostgreSQL overloads functions by argument types and you may not know which was registered. Then re-run `npx supabase db push`. Already-applied migrations are skipped; only the failed one and anything after it will run.

After completion, verify in Dashboard → Table Editor that you can see: `projects`, `requirements`, `canvas_nodes`, `canvas_edges`, `audit_runs`, `build_sessions`, `artifacts`, `profiles`, `organizations`, `share_tokens`, `standards`, `build_books`.

### 7.3 Configure Auth URL settings

In Supabase Dashboard → Authentication → URL Configuration:

| Setting | Value |
|---------|-------|
| Site URL | `http://192.168.1.X:8080` |
| Redirect URLs | `http://192.168.1.X:8080/**` |

The `/**` wildcard is required — it allows Supabase Auth to redirect to any path (e.g., `/dashboard`, `/project/123`) after OAuth login.

### 7.4 Azure AD Setup

Required if you want users to sign in with Microsoft / Azure AD accounts.

**Step 1 — Azure App Registration**

Go to portal.azure.com → Azure Active Directory → App registrations → New registration.

| Field | Value |
|-------|-------|
| Name | Anything — e.g. `Pronghorn` |
| Supported account types | Single tenant = your org only. Multitenant = any Azure AD org. |
| Redirect URI | Leave blank for now |

Click Register. From the Overview page copy and save your **Application (client) ID** and **Directory (tenant) ID**.

**Step 2 — Add Supabase Redirect URI**

App Registration → Authentication → Add a platform → Web. Set Redirect URI to:

```
https://YOUR_PROJECT_ID.supabase.co/auth/v1/callback
```

This is Supabase's callback — not your app URL. Supabase handles the OAuth token exchange with Microsoft, then redirects the user on to your app.

**Step 3 — Create Client Secret**

Certificates & secrets → New client secret. Copy the **Value** (not the ID) immediately — Azure only shows it once.

**Step 4 — Configure Azure provider in Supabase**

Dashboard → Authentication → Providers → Azure → Enable

| Field | Value |
|-------|-------|
| Client ID | Application (client) ID from Step 1 |
| Client Secret | Secret Value from Step 3 |
| Azure Tenant URL | `https://login.microsoftonline.com/YOUR_TENANT_ID` |

**Step 5 — Confirm .env.local**

The code change in `AuthContext.tsx` is already done. Make sure your `.env.local` has:

```env
VITE_APP_URL=http://YOUR_IP:8080
```

**How the full flow works:**

```
User clicks Sign in with Azure
        ↓
Supabase redirects to Microsoft login
        ↓
User authenticates with Microsoft account
        ↓
Microsoft → YOUR_PROJECT_ID.supabase.co/auth/v1/callback
        ↓
Supabase validates token, creates session
        ↓
Supabase → YOUR_IP:8080/dashboard  (your redirectTo value)
        ↓
User lands on dashboard, logged in
```

### 7.5 Fix send-auth-email Function

Before deploying functions, fix this hardcoded URL in the email function. Verification links in signup emails point to `pronghorn.red` until this is changed.

**File:** `supabase/functions/send-auth-email/index.ts`

```typescript
// Before
const baseUrl = "https://pronghorn.red";

// After
const baseUrl = Deno.env.get("APP_URL") ?? "https://pronghorn.red";
```

Then add `APP_URL` as an edge function secret (separate from `VITE_APP_URL` — edge functions are server-side and cannot read Vite build-time vars):

```
APP_URL = http://YOUR_IP:8080
```

### 7.6 Deploy all edge functions

Before deploying, remove the orphaned `verify-admin` entry from `supabase/config.toml`. The function file was never committed but the config entry was left in — the CLI will hit a 400 error and stop at that function if you don't remove it first.

Open `supabase/config.toml` and delete this block:
```toml
[functions.verify-admin]
verify_jwt = false
```

No frontend code calls `verify-admin` anywhere in the codebase — removing it has no impact.

Then deploy:
```bash
npx supabase functions deploy --project-ref YOUR_PROJECT_ID
```

This deploys all 56 functions from `supabase/functions/`. Takes 2–5 minutes.

> **Known issue — `WARN: failed to read file` / `unexpected deploy status 400: Entrypoint path does not exist`**
>
> This happens when `config.toml` declares a function entry that has no matching `index.ts` file. The original dev removed or never committed `verify-admin/index.ts` but left the config block. The CLI fails at that function and stops. Fix: delete the orphaned `[functions.verify-admin]` block from `config.toml` as described above, then re-run.

> **Note for future upstream syncs:** When pulling upstream changes, check whether `config.toml` gains new `[functions.*]` entries. If a new entry appears without a matching file in `supabase/functions/`, the entire deploy run will fail at that function. Always verify `config.toml` entries have corresponding `index.ts` files before deploying.

Verify in Dashboard → Edge Functions: all 56 functions should show as "Active". Key functions to spot-check: `chat-stream-gemini`, `audit-orchestrator`, `coding-agent-orchestrator`, `validate-signup-code`.

### 7.7 Set edge function secrets

In Supabase Dashboard → Settings → Edge Functions → Manage Secrets:

**Required secrets (app will not function without these):**

| Secret Name | Where to Get |
|-------------|-------------|
| `GEMINI_API_KEY` | aistudio.google.com → API Keys |
| `ANTHROPIC_API_KEY` | console.anthropic.com → API Keys |
| `GITHUB_PAT` | github.com → Settings → Developer Settings → Personal Access Tokens |

**Optional secrets (unlock specific features):**

| Secret Name | Feature |
|-------------|---------|
| `GROK_API_KEY` | xAI Grok as alternative LLM |
| `RENDER_API_KEY` | Deploy tab — Render.com provisioning |
| `RENDER_OWNER_ID` | Deploy tab (same feature) |
| `RESEND_API_KEY` | Custom branded auth emails |

**Signup code gate:** The `validate-signup-code` function checks for a `SIGNUP_CODE` secret. If the secret is not set, the function returns `{ valid: true }` and accepts all signups automatically. Do not set `SIGNUP_CODE` unless you want to restrict who can register.

---

## 8. Phase 4 — Build & Launch

### Makefile (recommended)

A `Makefile` is included in the repo root that wraps all Docker and Supabase commands. Place it alongside `Dockerfile` and `docker-compose.yml`.

```makefile
.PHONY: build up down restart rebuild rebuild-clean logs status health \
        shell prune prune-all deploy supabase-push supabase-functions help

ENV_FILE := .env.local
CONTAINER := pronghorn-frontend
COMPOSE   := docker compose --env-file $(ENV_FILE)

.DEFAULT_GOAL := help

build:
	$(COMPOSE) build

rebuild-clean:
	$(COMPOSE) build --no-cache

up:
	$(COMPOSE) up -d

deploy: build up

down:
	$(COMPOSE) down

restart: down build up

rebuild: down rebuild-clean up

status:
	$(COMPOSE) ps

health:
	docker inspect $(CONTAINER) --format='{{.State.Health.Status}}'

logs:
	$(COMPOSE) logs -f frontend

shell:
	docker exec -it $(CONTAINER) /bin/sh

prune:
	$(COMPOSE) down --rmi local

prune-all:
	$(COMPOSE) down --rmi all --volumes --remove-orphans

supabase-push:
	npx supabase db push

supabase-functions:
	npx supabase functions deploy

help:
	@echo ""
	@echo "Pronghorn — available make targets"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^##/ { desc=$$0; sub(/^## /,"",desc) } \
	      /^[a-zA-Z_-]+:/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, desc; desc="" }' $(MAKEFILE_LIST)
	@echo ""
```

**Quick reference:**

| Target | What it does |
|--------|-------------|
| `make build` | Build image using layer cache |
| `make rebuild-clean` | Full rebuild with `--no-cache` |
| `make up` | Start container detached |
| `make deploy` | Build + start in one step |
| `make down` | Stop and remove container (keeps image) |
| `make restart` | Down → cached rebuild → up |
| `make rebuild` | Down → no-cache rebuild → up |
| `make status` | Show container status |
| `make health` | Print health check status |
| `make logs` | Tail live logs |
| `make shell` | Open `/bin/sh` inside the container |
| `make prune` | Remove container + image |
| `make prune-all` | Remove container, image, volumes, orphans |
| `make supabase-push` | `npx supabase db push` |
| `make supabase-functions` | `npx supabase functions deploy` |
| `make help` | Print all targets |

### First deployment

```bash
docker compose --env-file .env.local build
```

Docker Compose reads `.env.local`, passes all `VITE_*` values as build args to the Dockerfile, and runs the two-stage build. Stage 1 uses `oven/bun:1-alpine` — `bun install` is significantly faster than `npm ci`. First build: 3–5 minutes (pulling the Bun + Nginx images). Subsequent builds where only source code changed: ~1 minute due to layer cache.

### Start the container

```bash
docker compose --env-file .env.local up -d
```

### Verify it's running

```bash
# Container status
docker compose ps

# Health check (should say "healthy" after ~30 seconds)
docker inspect pronghorn-frontend --format='{{.State.Health.Status}}'

# Live logs
docker compose logs -f frontend
```

The app should now be accessible at `http://YOUR_LAN_IP:8080`.

---

## 9. Phase 5 — End-to-End Validation

Work through all 7 layers in order. Each validates a distinct part of the stack.

### Layer 1 — Container + Nginx

- `http://YOUR_IP:8080` loads the landing page
- `http://YOUR_IP:8080/dashboard` (typed directly in address bar, not via nav) loads the app — not a 404
- `http://YOUR_IP:8080/any-fake-path` loads the app — not a 404 (SPA fallback working)
- DevTools → Network → reload → a `vendor-react-*.js` response header shows `Content-Encoding: gzip`

### Layer 2 — Supabase Connection

- DevTools → Console: no "supabase" errors on page load
- DevTools → Network: successful XHR/Fetch requests to `YOUR_PROJECT_ID.supabase.co`
- No requests to `obkzdksfayygnrzdqoam.supabase.co`

### Layer 3 — Authentication

- Sign up with email + password → verification email arrives
- Verification link in email redirects to your IP/domain (not pronghorn.red)
- Sign in → dashboard loads
- Signup code modal accepts any input (SIGNUP_CODE not set)

### Layer 4 — Database Read/Write

- Create a new project from dashboard → project card appears
- Open project → all sidebar sections load
- Add a requirement → text persists on page reload

### Layer 5 — Edge Functions + LLM

- Requirements tab → type a requirement → decompose/expand triggers → AI response streams back
- Open Chat → send a message → reply streams back
- Canvas → AI architect button → generates canvas nodes

### Layer 6 — Share Links

- Project Settings → Token Management → create Viewer token → copy URL
- URL starts with your IP/domain, not `pronghorn.red`
- Paste URL in incognito window → project opens in read-only mode

### Layer 7 — Artifacts

- Upload a PDF in the Artifacts tab → upload succeeds
- Share icon on artifact → Publish toggle on → Raw URL shows your Supabase project URL (not `api.pronghorn.red`)

---

## 10. Phase 6 — Domain + HTTPS (Future State)

When you're ready to put Pronghorn behind a real domain with TLS certificates:

### Reverse proxy setup

Add a reverse proxy on your host that handles TLS termination. Three good options for homelab:

**Caddy (recommended for simplicity):**
```caddyfile
pronghorn.yourdomain.com {
    reverse_proxy localhost:8080
}
```
Caddy handles Let's Encrypt certificate acquisition and renewal automatically.

**Nginx on host:**
```nginx
server {
    listen 443 ssl;
    server_name pronghorn.yourdomain.com;
    ssl_certificate /etc/letsencrypt/live/pronghorn.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/pronghorn.yourdomain.com/privkey.pem;
    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

**Traefik:** Works well with Docker Compose — add labels to the service definition.

### Steps to migrate from LAN IP to domain

1. Update DNS to point your domain to your server's public IP
2. Configure your router for port forwarding (80/443 → your server)
3. Update `VITE_APP_URL` in `.env.local` to `https://yourdomain.com`
4. Rebuild Docker image: `docker compose --env-file .env.local build --no-cache`
5. Update Supabase Auth: Site URL and Redirect URLs to `https://yourdomain.com/**`
6. Restart container: `docker compose --env-file .env.local up -d`

The Pronghorn Nginx container requires no changes — it keeps listening on port 80. The host reverse proxy handles HTTPS → HTTP internally.

---

## 11. Operational Runbook

All commands below have a `make` equivalent. Use whichever you prefer — they do the same thing.

### First build and launch

```bash
make deploy          # build (cached) + start detached
# or manually:
docker compose --env-file .env.local build
docker compose --env-file .env.local up -d
```

### Rebuild after code changes (fast — uses layer cache)

```bash
make restart
# or manually:
docker compose down
docker compose --env-file .env.local build
docker compose --env-file .env.local up -d
```

### Force full rebuild (after changing .env.local or package.json)

```bash
make rebuild
# or manually:
docker compose down
docker compose --env-file .env.local build --no-cache
docker compose --env-file .env.local up -d
```

### Stop the container

```bash
make down
# or: docker compose down
```

### Remove container + image

```bash
make prune            # removes container and image
make prune-all        # also removes volumes and orphaned containers
```

### View logs

```bash
make logs             # tail live
# or manually:
docker compose logs -f frontend
docker compose logs --tail=100 frontend
```

### Open a shell inside the container

```bash
make shell
# or: docker exec -it pronghorn-frontend /bin/sh
```

### Check container status and health

```bash
make status           # docker compose ps
make health           # prints "healthy" / "unhealthy" / "starting"
```

### Check what VITE_* values were baked in

```bash
docker exec pronghorn-frontend grep -r "YOUR_PROJECT_ID" /usr/share/nginx/html/assets/ | head -5
```

### Update Supabase edge functions

```bash
make supabase-functions
# or: npx supabase functions deploy --project-ref YOUR_PROJECT_ID
```

### Update database schema after migration changes

```bash
make supabase-push
# or: npx supabase db push
```

---

## 12. Troubleshooting Reference

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| Signup email verification link points to pronghorn.red | `send-auth-email/index.ts` has hardcoded `pronghorn.red` as base URL | Fix `baseUrl` to use `Deno.env.get("APP_URL")`; add `APP_URL` secret; redeploy functions |
| Signup fails with Resend error | `RESEND_API_KEY` not set as edge function secret | Add `RESEND_API_KEY` to edge function secrets, or use Method 1 (Dashboard user creation) to bypass Resend |
| `npm ci can only install packages when package.json and package-lock.json are in sync` | Dockerfile uses `node:20-alpine` + `npm ci` but repo uses Bun | Switch to `oven/bun:1-alpine`, use `bun install`, `bun run build` |
| `lockfile had changes, but lockfile is frozen` | `bun.lockb` has drifted out of sync with `package.json` | Remove `--frozen-lockfile` from Dockerfile (`RUN bun install`); run `npx bun install` locally and commit updated `bun.lockb` |
| `Error at parseAsync (unknown)` / Rollup crash during build | Bun pulled Rollup `4.60.x` inside Alpine; codebase requires `4.24.0` | Add `"overrides": { "rollup": "4.24.0" }` to `package.json`, run `npx bun install`, rebuild with `--no-cache` |
| `[vite-plugin-pwa:build]` appears in Rollup error | Red herring — PWA plugin is the first module Rollup processes, not the cause | Fix the Rollup version conflict (above); do not remove the PWA plugin |
| `WARN: failed to read file` / `deploy status 400: Entrypoint path does not exist` | `config.toml` has a `[functions.verify-admin]` entry but the file doesn't exist | Delete the `[functions.verify-admin]` block from `config.toml`, then re-run `functions deploy` |
| `ERROR: cannot change return type of existing function` during `db push` | Migration chain changes `get_repo_files_with_token` return type mid-sequence — `CREATE OR REPLACE` cannot change return types | Drop all variants in SQL Editor first: `DROP FUNCTION IF EXISTS public.get_repo_files_with_token(uuid, uuid, text);` etc. Then re-run `db push` |
| App loads but all API calls fail with 401/403 | `client.ts` still has hardcoded old project credentials | Verify Change 1 was applied; rebuild with `--no-cache` |
| App loads, auth works, but specific features (chat, audit, artifacts) return 401/fetch errors | Raw `fetch()` calls in 11 files still have hardcoded project URL and/or anon key in `Authorization` headers — two separate strings, two separate greps required | Apply Change 10 to all 11 files; run both greps (`obkzdksfayygnrzdqoam` AND the JWT prefix) — both must return empty before rebuilding |
| "Invalid API key" in browser console | Build ran before `.env.local` had correct values | Verify `.env.local` values; rebuild with `--no-cache` |
| `/dashboard` or any deep URL returns 404 | `nginx.conf` missing or `try_files` fallback not present | Check `nginx.conf` has `try_files $uri $uri/ /index.html;` |
| After Google/Azure login, redirected to pronghorn.red | Change 3 (AuthContext.tsx) not applied; or Supabase redirect URL not updated | Apply Change 3; rebuild; update Supabase Auth redirect allowlist |
| Signup fails with edge function error | `send-auth-email` missing Resend key | Set `RESEND_API_KEY` or use Supabase's native auth emails |
| "Signup code invalid" for any input | `SIGNUP_CODE` secret is set in your Supabase project | Dashboard → Settings → Edge Functions → Manage Secrets → delete `SIGNUP_CODE` |
| Share links still show pronghorn.red | Changes 4–7 not applied; image not rebuilt | Apply all Phase 1 changes; rebuild with `--no-cache` |
| Container starts, health check stays "unhealthy" | Nginx failed to start — likely bad `nginx.conf` syntax | `docker compose logs frontend` — look for Nginx error output |
| Old project ID in network tab after rebuild | Docker used cached layer | `docker compose build --no-cache` |
| Edge functions return 500 errors | Secrets not set or set incorrectly | Check Dashboard → Settings → Edge Functions → Manage Secrets |
| AI features return errors but auth works | LLM API keys not set as edge function secrets | Add `GEMINI_API_KEY` and `ANTHROPIC_API_KEY` as edge function secrets |

---

## 13. Security Checklist

- [ ] `.env.local` is listed in `.gitignore` — verify with `git status` (should not appear)
- [ ] `.env.local` has never been committed — verify with `git log --all -- .env.local` (should return nothing)
- [ ] `VITE_ADMIN_KEY` is a strong unique password — not a default or dictionary word
- [ ] Supabase anon key is stored only in `.env.local` — not hardcoded in any source file
- [ ] GitHub PAT has minimum necessary scopes (`repo` + `read:org` only)
- [ ] Supabase RLS (Row Level Security) is active — all tables enforce RLS by default via migrations
- [ ] Port 8080 is not exposed to the public internet (router firewall)
- [ ] If adding HTTPS, port 443 is the only port exposed publicly — port 8080 remains LAN-only
- [ ] API keys for Gemini and Anthropic are set as Supabase secrets — not in frontend code
- [ ] Docker container runs as non-root (Nginx default — verify with `docker exec pronghorn-frontend whoami`)

---

## 14. Complete Change Inventory

| # | File | Lines | Type | Required |
|---|------|-------|------|----------|
| 1 | `src/integrations/supabase/client.ts` | 5–6 | Bug fix | **Yes** |
| 2 | `supabase/config.toml` | 1 | Config | **Yes** |
| 3 | `src/contexts/AuthContext.tsx` | 104, 115 | Bug fix | **Yes** |
| 4 | `src/hooks/useProjectUrl.ts` | 41 | Bug fix | **Yes** |
| 5 | `src/components/artifacts/ShareArtifactDialog.tsx` | 45–46 | Bug fix | **Yes** |
| 6 | `src/components/dashboard/AnonymousProjectWarning.tsx` | 29 | Bug fix | **Yes** |
| 7 | `src/components/project/TokenManagement.tsx` | 212, 225, 274, 303, 304 | Bug fix | **Yes** |
| 8 | `src/hooks/useAuditPipeline.ts` | BASE_URL constant | Credential audit | **Yes** |
| 9 | `src/pages/project/Chat.tsx` | 2 fetch URLs | Credential audit | **Yes** |
| 10 | `src/pages/project/Present.tsx` | 2 fetch URLs | Credential audit | **Yes** |
| 11 | `src/pages/project/Specifications.tsx` | 1 fetch URL | Credential audit | **Yes** |
| 12 | `src/pages/project/Artifacts.tsx` | 1 fetch URL | Credential audit | **Yes** |
| 13 | `src/components/artifacts/VisualRecognitionDialog.tsx` | 1 fetch URL | Credential audit | **Yes** |
| 14 | `src/components/artifacts/VisualRecognitionImportDialog.tsx` | 1 fetch URL | Credential audit | **Yes** |
| 15 | `src/components/build/UnifiedAgentInterface.tsx` | URL + anon key | Credential audit | **Yes** |
| 16 | `src/components/deploy/DatabaseAgentInterface.tsx` | URL + anon key | Credential audit | **Yes** |
| 17 | `src/components/buildbook/BuildBookChat.tsx` | 1 fetch URL | Credential audit | **Yes** |
| 18 | `src/components/collaboration/ArtifactCollaborator.tsx` | Hardcoded fallback | Credential audit | **Yes** |
| 19 | `index.html` | 14, 28–31, 37–40 | Metadata | Cosmetic |
| 20 | `src/pages/Landing.tsx` | 944 | Branding | Optional |
| 21 | `src/pages/Viewer.tsx` | 230, 368 | Branding | Optional |
| 22 | `.env.local` | New file | Credentials | **Yes** |
| 23 | `.gitignore` | +2 lines | Security | **Yes** |
| 24 | `Dockerfile` | New file | Container | **Yes** |
| 25 | `nginx.conf` | New file | Container | **Yes** |
| 26 | `docker-compose.yml` | New file | Container | **Yes** |
| 27 | `Makefile` | New file | Operations | **Yes** |

**Total required changes: 24 files (18 code edits, 1 config edit, 5 new files)**  
**Total optional/cosmetic: 3 files**

---

*Document generated from: `pronghorn-deployment-guide.md`*  
*Architecture: Single-container Docker SPA + Supabase cloud backend*

---

## 15. Database Schema Reference

Applied by `supabase db push` from `supabase/migrations/`. 16 table groups, 50+ tables. Reference this when writing queries, adding data, or customizing the platform for your deployment.

### ENUMs

| Enum | Values |
|------|--------|
| `project_status` | DESIGN, AUDIT, BUILD |
| `requirement_type` | EPIC, FEATURE, STORY, ACCEPTANCE_CRITERIA |
| `node_type` | COMPONENT, API, DATABASE, SERVICE, WEBHOOK, FIREWALL, SECURITY, REQUIREMENT, STANDARD, TECH_STACK, WEB_COMPONENT, HOOK_COMPOSABLE, API_SERVICE, API_ROUTER, API_MIDDLEWARE, API_CONTROLLER, API_UTIL, EXTERNAL_SERVICE, SCHEMA, TABLE, AGENT, OTHER, PAGE, PROJECT |
| `audit_severity` | CRITICAL, HIGH, MEDIUM, LOW |
| `build_status` | RUNNING, COMPLETED, FAILED |
| `app_role` | admin, user |
| `project_token_role` | owner, editor, viewer |
| `deployment_environment` | development, staging, production |
| `deployment_status` | pending, building, deploying, running, stopped, failed, deleted |
| `deployment_platform` | pronghorn_cloud, local, dedicated_vm |
| `database_provider` | render_postgres, supabase |
| `database_status` | pending, creating, available, suspended, restarting, updating, failed, deleted |
| `database_plan` | free, starter, standard, pro, pro_plus, custom |
| `resource_type` | file, website, youtube, image |

---

### Group 1 — Identity & Access

**`organizations`** — Top-level tenant container. Every project, standard, and tech stack belongs to an org.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | gen_random_uuid() |
| name | text NOT NULL | Org display name |
| created_at | timestamptz | |
| updated_at | timestamptz | |

**`profiles`** — User profile extending Supabase auth.users. Created automatically on first login.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK → auth.users | UNIQUE, CASCADE DELETE |
| org_id | uuid FK → organizations | CASCADE DELETE |
| display_name | text | |
| avatar_url | text | |

**`user_roles`** — Grants admin or user app-level roles.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| user_id | uuid FK → auth.users | CASCADE DELETE |
| role | app_role | DEFAULT user |
| created_by | uuid FK → auth.users | |

**`project_tokens`** — Shareable access tokens. Used for share links and external integrations.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| project_id | uuid FK → projects | CASCADE DELETE |
| token | uuid | UNIQUE, gen_random_uuid() |
| role | project_token_role | owner / editor / viewer |
| label | text | Friendly name |
| expires_at | timestamptz | NULL = never expires |
| last_used_at | timestamptz | |

---

### Group 2 — Projects

**`projects`** — Central project record. Contains all metadata, LLM configuration, and lifecycle status.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| name | text NOT NULL | |
| status | project_status | DEFAULT DESIGN |
| org_id | uuid FK → organizations | CASCADE DELETE |
| github_repo | text | |
| github_branch | text | DEFAULT main |
| selected_model | text | DEFAULT gemini-2.5-flash |
| max_tokens | integer | DEFAULT 32768 |
| thinking_enabled | boolean | DEFAULT false |
| thinking_budget | integer | DEFAULT -1 (unlimited) |
| budget | numeric(15,2) | |
| priority | text | DEFAULT medium |
| tags | text[] | |

> **Customization:** `selected_model` controls which LLM is used per project. Change the DEFAULT to set your preferred model for all new projects:
> ```sql
> ALTER TABLE projects ALTER COLUMN selected_model SET DEFAULT 'claude-sonnet-4-5';
> ```

---

### Group 3 — Requirements

**`requirements`** — Hierarchical tree: EPIC → FEATURE → STORY → ACCEPTANCE_CRITERIA.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| project_id | uuid FK → projects | CASCADE DELETE |
| parent_id | uuid FK → requirements | CASCADE DELETE (self-ref) |
| type | requirement_type | |
| title | text NOT NULL | |
| content | text | Full description |
| code | text | Short ID e.g. EPIC-001 |
| order_index | integer | |

**`project_specifications`** — AI-generated technical spec document (Markdown).

**`requirement_standards`** — Many-to-many: requirements ↔ compliance standards. UNIQUE on (requirement_id, standard_id).

**`project_standards`** — Project-level standard assignments. UNIQUE on (project_id, standard_id).

---

### Group 4 — Standards & Compliance

**`standard_categories`** — Top-level groupings (e.g. "Cyber Security", "Accessibility", "Privacy").

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| name | text NOT NULL | |
| org_id | uuid FK → organizations | NULL = system-wide |
| is_system | boolean | true = ships with platform |
| icon | text | |
| color | text | |
| order_index | integer | |

**`standards`** — Individual compliance standards. Hierarchical via parent_id. UNIQUE code (e.g. OWASP-A01, WCAG-1.1).

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| category_id | uuid FK → standard_categories | |
| parent_id | uuid FK → standards | Hierarchy |
| code | text UNIQUE | |
| title | text NOT NULL | |
| content | text | Full standard text |
| org_id | uuid FK → organizations | NULL = system-wide |
| is_system | boolean | |

> **Customization:** Add your own standards and categories:
> ```sql
> -- Create a category
> INSERT INTO standard_categories (name, short_description, icon, color, org_id, is_system)
> VALUES ('Internal Policy', 'Your internal policies', 'shield', '#6366F1', '<your_org_id>', false);
> 
> -- Add standards under it
> INSERT INTO standards (category_id, code, title, content, org_id, is_system)
> VALUES ('<category_id>', 'POL-001', 'All code must be reviewed', 'Full policy text...', '<your_org_id>', false);
> ```

**`standard_attachments`** — File/URL attachments for standards (PDFs, reference links).

**`standard_resources`** — Enhanced resource attachments supporting file, website, youtube, image types. CHECK: exactly one of standard_id or standard_category_id must be set.

---

### Group 5 — Technology Stacks

**`tech_stacks`** — Hierarchical technology definitions (e.g. "Frontend" → "React" → "React 18"). Includes metadata jsonb for version, docs URL, etc.

| Column | Type | Notes |
|--------|------|-------|
| id | uuid PK | |
| org_id | uuid FK → organizations | NULL = system-wide |
| name | text NOT NULL | |
| type | text | language, framework, tool, platform |
| parent_id | uuid FK → tech_stacks | Hierarchy |
| metadata | jsonb | version, docs, language etc. |
| is_active (via canvas_node_types) | | |

> **Customization:** Replace Alberta's stacks with your own:
> ```sql
> -- Add a parent category
> INSERT INTO tech_stacks (name, type, org_id, order_index)
> VALUES ('Backend', 'category', '<your_org_id>', 1);
> 
> -- Add a specific stack under it
> INSERT INTO tech_stacks (name, type, parent_id, org_id, order_index, metadata)
> VALUES ('.NET 9', 'framework', '<backend_id>', '<your_org_id>', 1,
>   '{"version": "9.0", "docs": "https://docs.microsoft.com/dotnet", "language": "C#"}');
> ```

**`tech_stack_standards`** — Many-to-many: standards ↔ tech stacks. UNIQUE on (tech_stack_id, standard_id).

**`tech_stack_resources`** — Learning resources (file/website/youtube/image) attached to a tech stack.

**`project_tech_stacks`** — Many-to-many: tech stacks selected for a project. UNIQUE on (project_id, tech_stack_id).

---

### Group 6 — Canvas & Visualization

**`canvas_nodes`** — Architectural diagram nodes. `position` is `{"x": 0, "y": 0}` jsonb. `data` holds node content, labels, metadata.

**`canvas_edges`** — Directed connections between canvas nodes. source_id and target_id both CASCADE DELETE.

**`canvas_layers`** — Named layer groups. `node_ids` is a text[] of node IDs.

**`canvas_node_types`** — Dynamic UI configuration for node types. Controls what appears in the canvas toolbar.

| Column | Type | Notes |
|--------|------|-------|
| system_name | text UNIQUE | Maps to node_type enum |
| display_label | text | Shown in UI |
| is_active | boolean | DEFAULT true — set false to hide |
| is_legacy | boolean | DEFAULT false |
| category | text | DEFAULT general |

> **Customization:** Hide node types you don't use: `UPDATE canvas_node_types SET is_active = false WHERE system_name = 'WEBHOOK';`

---

### Group 7 — Repositories & Source Control

**`project_repos`** — Git repository configuration. UNIQUE on (project_id, organization, repo).

**`repo_files`** — Source files synced from a repo. UNIQUE on (repo_id, path). Stores full file content.

**`repo_staging`** — Uncommitted agent changes staged before committing. operation_type: add/edit/delete/rename.

**`repo_commits`** — Commit history for repos managed through the platform.

**`repo_pats`** — Encrypted GitHub PATs for repository operations. UNIQUE on (user_id, repo_id).

---

### Group 8 — Agents

**`agent_sessions`** — Tracks autonomous agent execution. mode: task / iterative_loop / continuous_improvement.

**`agent_blackboard`** — Episodic memory for agents. entry_type: planning / progress / decision / reasoning / next_steps / reflection.

**`agent_session_context`** — Snapshots of project context used as agent input at session start.

**`agent_file_operations`** — Real-time tracking of file operations. operation_type: create/edit/delete/read.

**`agent_messages`** — Persistent conversation history between users and agents. role: user/agent/system.

**`agent_llm_logs`** — Raw LLM API call log — full prompts, responses, token counts, parse success tracking.

---

### Group 9 — Chat

**`chat_sessions`** — Conversation groupings within a project. Has both user-set title and AI-generated ai_title/ai_summary.

**`chat_messages`** — Individual messages. role: user/assistant/system.

---

### Group 10 — Artifacts & Collaboration

**`artifacts`** — Reusable content blocks (code, documents, diagrams, images). Has ai_title and ai_summary.

**`artifact_collaborations`** — Active collaborative editing sessions. Tracks current_content (working copy) vs base_content (original). status: active/completed/merged.

**`artifact_collaboration_messages`** — Chat during a collaboration session. Supports share token access via token_id.

**`artifact_collaboration_history`** — Full version history with rollback support. UNIQUE on (collaboration_id, version_number). Stores full_content_snapshot at each version.

**`artifact_collaboration_blackboard`** — Agent reasoning notes during collaboration.

---

### Group 11 — Audit System

**`audit_sessions`** — Orchestrates multi-agent compliance audits. Supports Tesseract 3D analysis grid, Venn set intersection, and consensus voting across agents.

**`audit_blackboard`** — Shared working memory for all agents in an audit. Includes confidence float (0.0–1.0) and target_agent for directed messages.

**`audit_tesseract_cells`** — 3D evidence grid. z_polarity: -1.0 (fail) to 1.0 (pass). UNIQUE on (session_id, x_element_id, y_step).

**`audit_agent_instances`** — Individual agent instances within a session. UNIQUE on (session_id, agent_role).

**`audit_graph_nodes`** / **`audit_graph_edges`** — Knowledge graph discovered during auditing.

**`audit_activity_stream`** — Real-time event log displayed live in the UI during audits.

---

### Group 12 — Deployment & Infrastructure

**`project_deployments`** — Deployment configuration per environment. Supports pronghorn_cloud, local, dedicated_vm platforms. Has Render.com integration fields. `secrets` and `env_vars` stored as jsonb.

**`deployment_logs`** — Event log for deployment operations.

**`project_testing_logs`** — Real-time error telemetry from running deployments. Tracks stack_trace, file_path, line_number. is_resolved flag.

---

### Group 13 — Database Management

**`project_databases`** — Provisioned database instances. Supports render_postgres and supabase providers.

**`project_database_connections`** — External database connections. connection_string is encrypted. ssl_mode DEFAULT require. status: untested/connected/failed.

**`project_database_sql`** — Saved SQL queries associated with a project database.

**`project_migrations`** — Schema migration history for project databases. Tracks sequence_number, statement_type, object_type.

---

### Group 14 — Build Books

**`build_books`** — Curated collections of best practices and standards packaged for teams. is_published flag controls visibility.

**`build_book_standards`** — Standard categories included in a build book. UNIQUE on (build_book_id, standard_category_id).

**`build_book_tech_stacks`** — Tech stacks included in a build book. UNIQUE on (build_book_id, tech_stack_id).

---

### Group 15 — Gallery & Publishing

**`published_projects`** — Projects published to the public gallery. Tracks clone_count and view_count. is_visible flag.

---

### Group 16 — Activity & Audit Trails

**`activity_logs`** — General project activity log for events not captured elsewhere.

**`audit_runs`** (Legacy) — Early audit execution tracking. Superseded by audit_sessions.

**`audit_findings`** (Legacy) — Issues from legacy audit runs. severity: CRITICAL/HIGH/MEDIUM/LOW.

**`build_sessions`** (Legacy) — Early build execution tracking. Superseded by agent_sessions.

---

### Customization Quick Reference

**Make a user an admin:**
```sql
INSERT INTO user_roles (user_id, role)
VALUES ('<auth_user_uuid>', 'admin');
```

**Set up your organization:**
```sql
-- Create the org
INSERT INTO organizations (name) VALUES ('Your Org Name') RETURNING id;

-- Assign a user's profile to it
UPDATE profiles SET org_id = '<org_id>' WHERE user_id = '<auth_user_uuid>';
```

**Change the default LLM for all new projects:**
```sql
ALTER TABLE projects ALTER COLUMN selected_model SET DEFAULT 'claude-sonnet-4-5';
```

**Add internal standards:**
```sql
INSERT INTO standard_categories (name, short_description, icon, color, org_id, is_system)
VALUES ('Internal Policy', 'Your internal policies', 'shield', '#6366F1', '<your_org_id>', false);

INSERT INTO standards (category_id, code, title, content, org_id, is_system)
VALUES ('<category_id>', 'POL-001', 'All code must be reviewed', 'Full policy text...', '<your_org_id>', false);
```

**Add your tech stacks:**
```sql
INSERT INTO tech_stacks (name, type, org_id, order_index)
VALUES ('Frontend', 'category', '<your_org_id>', 1);

INSERT INTO tech_stacks (name, type, parent_id, org_id, order_index, metadata)
VALUES ('React 18', 'framework', '<frontend_id>', '<your_org_id>', 1,
  '{"version": "18.3", "docs": "https://react.dev", "language": "TypeScript"}');
```

**Hide unused canvas node types:**
```sql
UPDATE canvas_node_types SET is_active = false WHERE system_name IN ('WEBHOOK', 'FIREWALL');
```

---

## 16. User Setup & Management

### How the Auth System Works

| Method | How |
|--------|-----|
| Email + Password | Via the Sign In tab on `/auth` |
| Google SSO | OAuth via Supabase → Google provider |
| Microsoft SSO | OAuth via Supabase → Azure/Entra ID provider |

Sign up (email/password) requires a signup code. The app calls `validate-signup-code` first. If no `SIGNUP_CODE` secret is configured, any value is accepted. If one is set, the user must enter it exactly.

The actual account creation goes through `send-auth-email`, which uses Resend to deliver the verification email. Resend must be configured for email/password signups to work end-to-end.

### Fix Required — Hardcoded URL in Email Function

Before creating any users via signup, fix this. The `send-auth-email` edge function has `pronghorn.red` hardcoded as the base URL for verification links.

**File:** `supabase/functions/send-auth-email/index.ts`

**Before:**
```typescript
const baseUrl = "https://pronghorn.red";
```

**After:**
```typescript
const baseUrl = Deno.env.get("APP_URL") ?? "https://pronghorn.red";
```

Then add `APP_URL` to Supabase Edge Function secrets:
```
APP_URL = http://YOUR_IP:8080
```

> **Note:** This is a different secret from `VITE_APP_URL`. Edge functions run server-side on Supabase's infrastructure and cannot read Vite build-time vars.

---

### Method 1 — Create First User via Supabase Dashboard (Recommended)

This bypasses the signup form entirely — no signup code, no Resend dependency, no email needed. Use this to bootstrap your first admin account.

1. Supabase Dashboard → Authentication → Users → **Add user → Create new user**
2. Enter email and password
3. Toggle **Auto Confirm User** to ON — skips email verification
4. Click **Create User** — copy the User UID shown

Then run in SQL Editor:

```sql
-- Step 1: Create your organization
INSERT INTO organizations (name)
VALUES ('Your Org Name')
RETURNING id;
-- Copy the returned org ID

-- Step 2: Create profile (runs automatically on first login via trigger,
-- but do it manually here since you haven't logged in yet)
INSERT INTO profiles (user_id, display_name, org_id)
VALUES ('<auth-user-uuid>', 'Your Name', '<org-id>')
ON CONFLICT (user_id) DO UPDATE
  SET org_id = EXCLUDED.org_id,
      display_name = EXCLUDED.display_name;

-- Step 3: Grant admin role
INSERT INTO user_roles (user_id, role)
VALUES ('<auth-user-uuid>', 'admin');
```

Go to `http://YOUR_IP:8080/auth` → Sign In tab → enter credentials.

---

### Method 2 — Sign Up via the App

**Option A — No signup code (open registration):**  
Don't set a `SIGNUP_CODE` secret. `validate-signup-code` returns `valid: true` for any input.

**Option B — Restricted signup:**  
Supabase Dashboard → Edge Functions → Manage secrets → add `SIGNUP_CODE = YOURCODE123`. Share this code with users you want to allow.

**Resend requirement:** The signup flow sends verification email via Resend. You need:
- A Resend account (free tier: 3,000 emails/month)
- A verified sending domain in Resend
- `RESEND_API_KEY = re_xxxxxxxxxxxx` added as an edge function secret

If Resend is not configured, `send-auth-email` will throw an error and signup will fail. Use Method 1 to bootstrap without Resend.

---

### Method 3 — Microsoft or Google SSO

No signup code required. User clicks the button, authenticates with their identity provider, and Supabase creates the account automatically on first login.

Profile and org assignment must happen manually after first login:

```sql
UPDATE profiles
SET org_id = '<org-id>',
    display_name = 'Their Name'
WHERE user_id = '<auth-user-uuid>';

-- Grant admin if needed
INSERT INTO user_roles (user_id, role)
VALUES ('<auth-user-uuid>', 'admin');
```

---

### Post-Signup Checklist

After any user is created, verify these are in place:

| Check | Where | What to Look For |
|-------|-------|-----------------|
| Auth user exists | Dashboard → Authentication → Users | Row with email and confirmed status |
| Profile row exists | Table Editor → profiles | Row with matching user_id |
| Org assigned | profiles table | org_id is not NULL |
| Role assigned | user_roles table | Row with user_id and desired role |

**Quick verification SQL:**
```sql
SELECT
  u.email,
  u.confirmed_at,
  p.display_name,
  p.org_id,
  o.name AS org_name,
  array_agg(r.role) AS roles
FROM auth.users u
LEFT JOIN profiles p ON p.user_id = u.id
LEFT JOIN organizations o ON o.id = p.org_id
LEFT JOIN user_roles r ON r.user_id = u.id
GROUP BY u.email, u.confirmed_at, p.display_name, p.org_id, o.name;
```

---

### Role Reference

| Role | What It Can Do |
|------|----------------|
| `admin` | Create/edit/delete standards, tech stacks, categories, node types. Manage resources. All user operations. |
| `user` (default) | View standards and tech stacks. Create and manage their own projects. Cannot modify global library data. |

Users have no role row by default — the app treats them as `user`. Only add a row to `user_roles` to grant `admin`.

---

### Managing Additional Users

**Invite someone (admin creates their account):**
```sql
INSERT INTO profiles (user_id, display_name, org_id)
VALUES ('<new-user-uuid>', 'Colleague Name', '<your-org-id>')
ON CONFLICT (user_id) DO UPDATE
  SET org_id = EXCLUDED.org_id;

-- To make them admin:
INSERT INTO user_roles (user_id, role) VALUES ('<new-user-uuid>', 'admin');
```

**Revoke admin:**
```sql
DELETE FROM user_roles
WHERE user_id = '<user-uuid>' AND role = 'admin';
```

**Deactivate a user:** Supabase Dashboard → Authentication → Users → click user → **Ban user** or **Delete user**. No soft-disable exists at the app layer — use Supabase's ban feature to block access without deleting project data.

---

### Edge Function Secrets Reference

All set in Supabase Dashboard → Edge Functions → Manage secrets.

| Secret | Required For | Value |
|--------|-------------|-------|
| `SIGNUP_CODE` | Optional — restricts self-registration | Any string e.g. MYCODE2025 |
| `RESEND_API_KEY` | Email/password signup + password reset | From Resend dashboard |
| `APP_URL` | Email verification links (after code fix) | `http://YOUR_IP:8080` |
| `ANTHROPIC_API_KEY` | AI chat (chat-stream-anthropic) | From Anthropic console |
| `GEMINI_API_KEY` | Primary LLM for all AI features | From Google AI Studio |
| `GITHUB_PAT` | Repository and build features | GitHub PAT with repo + read:org scopes |

---

### Fastest Path to a Working First User

1. Supabase Dashboard → Authentication → Users → **Add user** → enter email + password → **Auto Confirm User: ON** → **Create User** → copy UID
2. SQL Editor:
```sql
INSERT INTO organizations (name) VALUES ('My Org') RETURNING id;
-- use returned id below
INSERT INTO profiles (user_id, display_name, org_id)
VALUES ('<uid>', 'Your Name', '<org-id>')
ON CONFLICT (user_id) DO UPDATE
  SET org_id = EXCLUDED.org_id, display_name = EXCLUDED.display_name;
INSERT INTO user_roles (user_id, role) VALUES ('<uid>', 'admin');
```
3. Go to `http://YOUR_IP:8080/auth` → Sign In → enter credentials → done

---

## 17. Adding Standards & Tech Stacks

### Prerequisites — Admin Role Required

All create/edit operations in Standards and Tech Stacks are gated behind `isAdmin`. Grant admin first:

```sql
INSERT INTO user_roles (user_id, role)
VALUES ('<your-auth-user-uuid>', 'admin');
```

Once done, edit/add/delete buttons appear in the UI.

---

### Method 1 — Through the UI (Recommended)

#### Adding Standards

Navigate to `/standards`.

**Step 1 — Create a Category**  
Click **New Category** (admin only). Fill in: Name, Short Description, Icon, Color (hex).

**Step 2 — Add Standards Under the Category**  
Click **Add Standard** inside the category.

| Field | What to Put Here |
|-------|-----------------|
| Code | Short unique identifier — e.g. ARCH-001, SEC-042 |
| Title | Full standard name |
| Short Description | One-paragraph summary shown in lists |
| Long Description | Paste your entire MD file here. Renders as a full docs page via the 📖 icon. This is `standards.long_description` — the primary field for KB article content. No size limit. |
| Content | Specific rules, criteria, or checklists. Also accepts markdown. |

**Step 3 — Add Sub-Standards (Optional)**  
Each standard has a + button to add child standards. Hierarchy goes as deep as needed: Category → Standard → Sub-standard → Sub-sub-standard.

**Step 4 — Attach Resources (📁 button)**  
The folder icon on every standard opens the Resource Manager:

| Type | Use Case |
|------|---------|
| File | Upload your actual .md file — stored in Supabase Storage (`standard-attachments` bucket) |
| Website | Internal wiki, Confluence, or external reference |
| YouTube | Training videos — auto-thumbnails |
| Image | Architecture diagrams, compliance charts |
| Repository | GitHub link to policy or standards repo |
| Library | npm, nuget, pypi, maven package references |

#### Adding Tech Stacks

Navigate to `/tech-stacks`.

**Step 1 — Create Top-Level Groups**  
Click **New Tech Stack** (admin only). Leave Parent blank for top-level groups: Backend, Frontend, Infrastructure, Databases, DevOps, etc.

**Step 2 — Add Items Under Each Group**

| Field | What to Put Here |
|-------|-----------------|
| Name | Technology name — e.g. .NET 9, React 18, PostgreSQL 16 |
| Type | Language / Framework / Library / Tool / IDE / Component / Resource / Other |
| Version Constraint | ^ (compatible), ~ (patch only), >= (or higher), = (exact), latest |
| Long Description | Paste your MD file here — ADRs, usage guides, internal coding standards. Rendered as docs page via 📖 icon. |

**Step 3 — Attach Resources**  
Same 📁 folder icon as standards. Particularly useful for: internal coding standards docs (File), official docs (Website), tutorial videos (YouTube), the actual package (Library type), your org's fork or boilerplate (Repository).

---

### Method 2 — Bulk SQL Insert

Use when you have many standards or want to script population from existing MD files.

**Bulk insert standard categories and standards:**
```sql
-- Create categories
INSERT INTO standard_categories (name, short_description, icon, color, org_id, is_system, order_index)
VALUES
  ('Internal Architecture', 'Internal architecture and design policies', 'cpu', '#6366F1', '<org_id>', false, 1),
  ('Security Policy', 'Internal security requirements', 'shield', '#EF4444', '<org_id>', false, 2),
  ('API Governance', 'API design and versioning rules', 'plug', '#10B981', '<org_id>', false, 3)
RETURNING id, name;

-- Add standards under a category
INSERT INTO standards (category_id, code, title, description, long_description, content, org_id, is_system, order_index)
VALUES
  ('<category_id>', 'ARCH-001', 'Microservices must expose health endpoints',
   'All services must implement a /health endpoint',
   '## Health Endpoint Standard\n\nAll microservices must expose...',
   '- GET /health returns 200 when healthy\n- Returns 503 when degraded',
   '<org_id>', false, 1),

  ('<category_id>', 'ARCH-002', 'All APIs must be versioned',
   'Version prefix required on all API routes',
   '## API Versioning\n\nAll APIs must include...',
   '- URL versioning: /v1/, /v2/\n- Breaking changes require new version',
   '<org_id>', false, 2);
```

**Bulk insert tech stacks:**
```sql
-- Parent groups
INSERT INTO tech_stacks (name, type, org_id, order_index)
VALUES
  ('Backend', 'category', '<org_id>', 1),
  ('Frontend', 'category', '<org_id>', 2),
  ('Infrastructure', 'category', '<org_id>', 3),
  ('Databases', 'category', '<org_id>', 4)
RETURNING id, name;

-- Technologies under Backend
INSERT INTO tech_stacks (name, type, parent_id, org_id, order_index, description, long_description, metadata)
VALUES
  ('.NET 9', 'Framework', '<backend_id>', '<org_id>', 1,
   'Primary backend framework for all API services',
   '## .NET 9 Standards\n\n### Project Structure\n...',
   '{"version": "9.0", "docs": "https://docs.microsoft.com/dotnet", "language": "C#"}'),

  ('Python 3.12', 'Language', '<backend_id>', '<org_id>', 2,
   'Used for AI/ML services and data pipelines',
   '## Python Standards\n\n### Code Style\n...',
   '{"version": "3.12", "docs": "https://docs.python.org/3.12/"}'),

  ('FastAPI', 'Framework', '<backend_id>', '<org_id>', 3,
   'Python REST API framework for ML services',
   '## FastAPI Standards\n\n...',
   '{"version": "^0.115", "docs": "https://fastapi.tiangolo.com"}');

-- Technologies under Frontend
INSERT INTO tech_stacks (name, type, parent_id, org_id, order_index, description, long_description, metadata)
VALUES
  ('React 18', 'Framework', '<frontend_id>', '<org_id>', 1,
   'Primary frontend framework',
   '## React Standards\n\n...',
   '{"version": "^18.3", "docs": "https://react.dev"}'),

  ('TypeScript 5', 'Language', '<frontend_id>', '<org_id>', 2,
   'Required for all frontend code',
   '## TypeScript Standards\n\n...',
   '{"version": "^5.0", "docs": "https://www.typescriptlang.org/docs/"}'),

  ('Next.js 15', 'Framework', '<frontend_id>', '<org_id>', 3,
   'App Router — used for all new frontend projects',
   '## Next.js Standards\n\n...',
   '{"version": "^15.0", "docs": "https://nextjs.org/docs"}');
```

**Link tech stacks to standards:**
```sql
SELECT id, code FROM standards WHERE code LIKE 'WCAG%';
SELECT id, name FROM tech_stacks WHERE name = 'React 18';

INSERT INTO tech_stack_standards (tech_stack_id, standard_id)
VALUES ('<react_id>', '<wcag_id>');
```

---

### Where Your MD File Content Goes

| Your MD File | Where to Put It | Column |
|-------------|----------------|--------|
| Full policy/standard document | Long Description field | `standards.long_description` |
| Short rule list | Content field | `standards.content` |
| Tech architecture decision record | Long Description field | `tech_stacks.long_description` |
| Uploaded .md file (binary) | Resources → File → Upload | `standard_resources.url` (Supabase Storage) |
| GitHub-hosted MD | Resources → Website or Repository | `standard_resources.url` |

The Long Description field is the primary one — it accepts raw markdown and renders as a full documentation page via the 📖 icon. No size limit — paste entire file contents.

---

### Page Locations Quick Reference

| What You Want | URL |
|--------------|-----|
| Manage all standards & categories | `/standards` |
| Manage all tech stacks | `/tech-stacks` |
| Assign standards to a project | Project → Standards tab |
| Assign tech stacks to a project | Project → Canvas (Tech Stack node type) |
| Link a requirement to a standard | Project → Requirements → link icon |
