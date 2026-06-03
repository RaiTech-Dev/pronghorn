# Pronghorn — Full Deployment & Configuration Handoff

## What This Is

Pronghorn is an open-source AI-powered SDLC platform originally built by the Government of Alberta. This document covers everything done to fork, configure, containerize, and self-host it on a personal homelab using Docker, with Supabase cloud for backend services.

- **Repo:** https://github.com/AlbertaGovernment/pronghorn (original)
- **Stack:** Vite + React 18 SPA, Supabase BaaS, Bun package manager, nginx, Docker

---

## Architecture Overview

```
Browser
  └── nginx container (port 8080)
        └── serves built React SPA
              └── calls Supabase cloud
                    ├── PostgreSQL (all data)
                    ├── Auth (JWT, OAuth)
                    ├── Edge Functions (57x Deno — all AI/LLM calls)
                    ├── Realtime (WebSockets)
                    └── Storage (file uploads)
```

> **Critical:** `VITE_*` environment variables are compile-time — baked into the JS bundle at `bun run build`. Any change to them requires a Docker image rebuild. They are NOT runtime config.

---

## Supabase Project

| Item | Value |
|------|-------|
| Project ID | `rftbiygzpmbyxlinmuaa` |
| Supabase URL | `https://rftbiygzpmbyxlinmuaa.supabase.co` |
| Dashboard | https://supabase.com/dashboard/project/rftbiygzpmbyxlinmuaa |

---

## Environment Variables

**File:** `.env.local` (repo root, never committed)

```env
VITE_SUPABASE_URL=https://rftbiygzpmbyxlinmuaa.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=<your-anon-key>
VITE_SUPABASE_PROJECT_ID=rftbiygzpmbyxlinmuaa
VITE_ADMIN_KEY=<your-admin-key>
VITE_APP_URL=http://YOUR_IP:8080
```

**Rules:**
- `VITE_APP_URL` — use actual homelab IP, no trailing slash. `http://192.168.X.X:8080`
- `VITE_SUPABASE_URL` — must be `https://xxx.supabase.co` format, never the raw DB host
- `VITE_SUPABASE_PUBLISHABLE_KEY` — the anon/public key, not the service role key

---

## Supabase Edge Function Secrets

Set in **Supabase Dashboard → Edge Functions → Manage secrets**

| Secret | Purpose |
|--------|---------|
| `ANTHROPIC_API_KEY` | AI chat features (chat-stream-anthropic and related functions) |
| `SIGNUP_CODE` | Optional — restricts self-registration. If not set, any code is accepted |
| `RESEND_API_KEY` | Email delivery for signup verification and password reset |
| `APP_URL` | Used by send-auth-email function for verification link base URL. Set to `http://YOUR_IP:8080` |

---

## All Code Changes Made (vs Original Repo)

### 1. `src/integrations/supabase/client.ts`
Replaced hardcoded Alberta credentials with env vars:
```typescript
const SUPABASE_URL = import.meta.env.VITE_SUPABASE_URL as string;
const SUPABASE_PUBLISHABLE_KEY = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY as string;
```

### 2. `tsconfig.app.json`
Added `"types": ["vite/client"]` to `compilerOptions` to fix `import.meta.env` TypeScript error.

### 3. `supabase/config.toml`
- Changed `project_id` on line 1 to `rftbiygzpmbyxlinmuaa`
- Deleted `[functions.verify-admin]` block (function file missing from repo)

### 4. `src/contexts/AuthContext.tsx`
Both OAuth functions — changed hardcoded `pronghorn.red` redirects:
```typescript
redirectTo: `${import.meta.env.VITE_APP_URL ?? window.location.origin}/dashboard`
```
Applies to both `signInWithAzure` and `signInWithGoogle`.

### 5. `src/hooks/useProjectUrl.ts`
Replaced hardcoded `"https://pronghorn.red"` default with:
```typescript
import.meta.env.VITE_APP_URL ?? window.location.origin
```

### 6. `src/components/artifacts/ShareArtifactDialog.tsx`
```typescript
const baseUrl = import.meta.env.VITE_APP_URL ?? window.location.origin;
const apiBaseUrl = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1/serve-artifact`;
```

### 7. `src/components/dashboard/AnonymousProjectWarning.tsx`
Replaced hardcoded `pronghorn.red` share URL with env var.

### 8. `src/components/project/TokenManagement.tsx`
All 5 occurrences of `https://pronghorn.red/project/${projectId}/...` replaced with env var equivalent.

### 9. `src/hooks/useAuditPipeline.ts`
```typescript
const BASE_URL = `${import.meta.env.VITE_SUPABASE_URL}/functions/v1`;
```

### 10. `src/pages/project/Chat.tsx`
Two occurrences — hardcoded fetch URL and hardcoded anon key in `Authorization` header replaced with env vars.

### 11. `src/pages/project/Present.tsx`
Two hardcoded Supabase URLs replaced.

### 12. `src/pages/project/Specifications.tsx`
Hardcoded Supabase URL replaced.

### 13. `src/pages/project/Artifacts.tsx`
Hardcoded Supabase URL replaced.

### 14. `src/components/artifacts/VisualRecognitionDialog.tsx`
Hardcoded Supabase URL replaced.

### 15. `src/components/artifacts/VisualRecognitionImportDialog.tsx`
Hardcoded Supabase URL replaced.

### 16. `src/components/build/UnifiedAgentInterface.tsx`
```typescript
const supabaseUrl = import.meta.env.VITE_SUPABASE_URL;
const supabaseAnonKey = import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY;
```

### 17. `src/components/deploy/DatabaseAgentInterface.tsx`
Same URL and anon key fixes as above.

### 18. `src/components/buildbook/BuildBookChat.tsx`
Hardcoded Supabase URL replaced.

### 19. `src/components/collaboration/ArtifactCollaborator.tsx`
Fixed wrong env var name — `VITE_SUPABASE_ANON_KEY` (doesn't exist) → `VITE_SUPABASE_PUBLISHABLE_KEY`.

### 20. `package.json`
Added Rollup version pin to fix build crash:
```json
"overrides": {
  "rollup": "4.24.0"
}
```

### 21. `supabase/functions/send-auth-email/index.ts`
**Pending fix** — hardcoded baseUrl:
```typescript
// Change this:
const baseUrl = "https://pronghorn.red";
// To this:
const baseUrl = Deno.env.get("APP_URL") ?? "https://pronghorn.red";
```
Then set `APP_URL` secret in Supabase Edge Functions → Manage secrets.

---

## New Files Added

### `Dockerfile`
```dockerfile
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

FROM nginx:1.27-alpine AS runner
RUN rm /etc/nginx/conf.d/default.conf
COPY nginx.conf /etc/nginx/conf.d/pronghorn.conf
COPY --from=builder /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
```

### `nginx.conf`
SPA fallback config — all routes serve `index.html`, gzip compression, security headers, asset caching.

### `docker-compose.yml`
Passes `.env.local` values as build args to bake into the image at build time.

### `.env.local`
Not committed. Template under the Environment Variables section above.

---

## Database Migration

Applied via Supabase CLI:
```bash
supabase login
supabase link --project-ref rftbiygzpmbyxlinmuaa
supabase db push
```

**Issue encountered:** `cannot change return type of existing function` on `get_repo_files_with_token`. Fix:
```sql
-- Run in Supabase SQL Editor before re-running db push
DROP FUNCTION IF EXISTS get_repo_files_with_token(uuid, uuid);
DROP FUNCTION IF EXISTS get_repo_files_with_token(uuid, text);
-- Then re-run: supabase db push
```

---

## Docker Build & Run

```bash
# Build
docker compose build --no-cache

# Run
docker compose up -d

# Logs
docker compose logs -f

# Rebuild after .env.local change
docker compose down
docker compose build --no-cache
docker compose up -d
```

App runs at `http://YOUR_IP:8080`

---

## Supabase Dashboard Configuration

### Authentication → URL Configuration

| Field | Value |
|-------|-------|
| Site URL | `http://YOUR_IP:8080` |
| Redirect URLs | `http://YOUR_IP:8080/**` |

### Authentication → Providers → Azure

| Field | Value |
|-------|-------|
| Enable | ON |
| Application (client) ID | `26b5d293-3ae4-47db-9cfc-2940b7211e72` |
| Secret Value | Azure client secret Value (not the ID) |
| Azure Tenant URL | `https://login.microsoftonline.com/d478654f-0af4-495d-8c8c-273512c9f8e0` |

### Azure App Registration (poc-pronghorn)

| Field | Value |
|-------|-------|
| Application (client) ID | `26b5d293-3ae4-47db-9cfc-2940b7211e72` |
| Directory (tenant) ID | `d478654f-0af4-495d-8c8c-273512c9f8e0` |
| Supported account types | My organization only (single tenant) |
| Redirect URI (Web) | `https://rftbiygzpmbyxlinmuaa.supabase.co/auth/v1/callback` |

> **Important:** The redirect URI registered in Azure must be the Supabase callback URL, not the app URL. Azure → Supabase → app is the flow.

---

## First User Setup

The app requires a signup code for self-registration (set via `SIGNUP_CODE` edge function secret). To bypass for first user:

**1. Create user in Supabase Dashboard → Authentication → Users → Add user → Create new user**
- Enter email + password
- Toggle **Auto Confirm User: ON**
- Copy the User UID

**2. Run in Supabase SQL Editor:**
```sql
-- Create org
INSERT INTO organizations (name) VALUES ('Your Org Name') RETURNING id;

-- Create/update profile (after first login, or manually)
INSERT INTO profiles (user_id, display_name, org_id)
VALUES ('<user-uuid>', 'Your Name', '<org-uuid>')
ON CONFLICT (user_id) DO UPDATE
  SET org_id = EXCLUDED.org_id,
      display_name = EXCLUDED.display_name;

-- Grant admin role
INSERT INTO user_roles (user_id, role)
VALUES ('<user-uuid>', 'admin');
```

**3. Sign in at** `http://YOUR_IP:8080/auth`

---

## Adding Standards and Tech Stacks

### Via UI (requires admin role)
- **Standards:** `/standards` → New Category → Add Standard
  - "Long Description" field = paste full markdown file content
  - 📁 Resources button = attach files, URLs, YouTube, GitHub repos
- **Tech Stacks:** `/tech-stacks` → New Tech Stack → Add Item
  - Same long description field for markdown content
  - Version constraint field for pinning versions

### Via SQL (bulk insert)
```sql
-- Standard category
INSERT INTO standard_categories (name, short_description, org_id, is_system)
VALUES ('Your Category', 'Description', '<org-id>', false);

-- Standard with markdown content
INSERT INTO standards (category_id, code, title, long_description, content, org_id, is_system)
VALUES ('<cat-id>', 'POL-001', 'Title', '## Full markdown here...', 'Rules list', '<org-id>', false);

-- Tech stack group
INSERT INTO tech_stacks (name, type, org_id, order_index)
VALUES ('Backend', 'category', '<org-id>', 1);

-- Tech stack item
INSERT INTO tech_stacks (name, type, parent_id, org_id, metadata)
VALUES ('.NET 9', 'Framework', '<backend-id>', '<org-id>',
  '{"version": "9.0", "docs": "https://docs.microsoft.com/dotnet"}');
```

---

## Known Remaining Items

| Item | Status | Notes |
|------|--------|-------|
| `send-auth-email` hardcoded `pronghorn.red` | Pending | Change `baseUrl` to read `APP_URL` env secret. Affects email verification links. |
| `ANTHROPIC_API_KEY` | Set in Supabase secrets | Required for `chat-stream-anthropic` edge function |
| `RESEND_API_KEY` | Optional | Only needed for email/password self-registration flow |
| Google SSO | Not configured | Same pattern as Azure — add Google provider in Supabase and register OAuth app in Google Cloud Console |

---

## Troubleshooting Reference

| Symptom | Cause | Fix |
|---------|-------|-----|
| Build fails — Rollup crash | Rollup version conflict | `"overrides": {"rollup": "4.24.0"}` in `package.json` |
| `import.meta.env` TypeScript error | Missing vite types | Add `"types": ["vite/client"]` to `tsconfig.app.json` compilerOptions |
| CORS error on API calls | Wrong SUPABASE_URL format | Must be `https://xxx.supabase.co` not the raw DB host |
| 403 on edge function calls | Wrong or missing anon key | Check `VITE_SUPABASE_PUBLISHABLE_KEY` — must be anon key, not service role |
| Old Alberta project ID in JS | Hardcoded URL missed | Grep for `obkzdksfayygnrzdqoam` — replace all with `VITE_SUPABASE_URL` env var |
| `cannot change return type` migration error | Existing function signature conflict | Drop the function in SQL Editor, re-run `db push` |
| Azure login → Unable to exchange external code | Wrong client secret | Regenerate secret in Azure, copy Value column, re-enter in Supabase |
| Azure login → redirects to localhost | `VITE_APP_URL` wrong | Set to actual IP with no trailing slash, rebuild Docker image |
| Azure login → double slash `//dashboard` | Trailing slash in `VITE_APP_URL` | Remove trailing slash from `VITE_APP_URL`, rebuild |
| Signup email links to wrong server | Supabase Site URL not set | Supabase → Auth → URL Configuration → set Site URL to your IP |
| Email verification link broken | `send-auth-email` hardcoded URL | Apply pending fix: read `APP_URL` env secret instead of hardcoded string |
| Admin buttons not showing in UI | User missing admin role | `INSERT INTO user_roles (user_id, role) VALUES ('<uuid>', 'admin');` |

---

## Key File Locations

| File | Purpose |
|------|---------|
| `src/integrations/supabase/client.ts` | Supabase client init — URL and key |
| `src/contexts/AuthContext.tsx` | All auth methods — sign in, sign up, OAuth |
| `src/pages/Auth.tsx` | Auth UI — sign in, sign up, reset password |
| `supabase/config.toml` | Supabase CLI config — project ID |
| `supabase/migrations/` | 238 SQL migration files — full DB schema |
| `supabase/functions/` | 57 Deno edge functions |
| `Dockerfile` | Multi-stage build: bun builder → nginx runner |
| `nginx.conf` | SPA fallback, compression, headers |
| `docker-compose.yml` | Passes env vars as build args |
| `.env.local` | Local credentials — not committed |
| `package.json` | Rollup version override under `overrides` |
| `tsconfig.app.json` | Added `"types": ["vite/client"]` |
