-- ================================================================
-- RAI-TECH — Tech Stacks Seed Script v2
-- Supabase Studio → SQL Editor: http://127.0.0.1:54323
--
-- STRUCTURE: 4 parent stacks, each with:
--   - Version profiles (current + LTS tiers)
--   - Individual technology entries
--   - Linked standards via tech_stack_standards
--
-- VERSIONS (all verified current stable as of May 2026):
--   .NET 10.0 LTS (Nov 2025) / .NET 8.0 LTS (active client projects)
--   C# 14 / ASP.NET Core 10 / EF Core 10
--   React 19.2 / TypeScript 5.8 / Vite 6
--   Python 3.13 / LangGraph latest / vLLM latest
--   PostgreSQL 17 / Supabase latest / pgvector 0.8
--
-- Safe to re-run: WHERE NOT EXISTS on name + parent_id
-- ================================================================

DO $$
DECLARE
  v_user_id uuid;

  -- Parent stack IDs
  v_stack_dotnet    uuid;
  v_stack_supabase  uuid;
  v_stack_python    uuid;
  v_stack_frontend  uuid;

  -- .NET version profile IDs
  v_dotnet_v10      uuid;
  v_dotnet_v8       uuid;
  v_dotnet_v6       uuid;

  -- Frontend version profile IDs
  v_fe_current      uuid;
  v_fe_stable       uuid;

  -- Python version profile IDs
  v_py_current      uuid;

BEGIN
  SELECT id INTO v_user_id FROM auth.users ORDER BY created_at LIMIT 1;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No users found — log into Pronghorn first.';
  END IF;
  RAISE NOTICE 'Seeding as user: %', v_user_id;

  -- ================================================================
  -- PARENT STACKS
  -- ================================================================

  INSERT INTO tech_stacks (id, name, description, short_description, long_description, icon, color, type, order_index, created_by, metadata)
  SELECT gen_random_uuid(),
    'Rai-Tech .NET Stack',
    'Primary backend stack for all Rai-Tech and client application development',
    'C# / .NET backend stack with Clean Architecture, EF Core, and Azure AD',
    'The Rai-Tech standard backend stack. Built on .NET 10 LTS with Clean Architecture, ASP.NET Core Minimal API, Entity Framework Core, MediatR for CQRS, FluentValidation, and Azure AD authentication. Deployed to OpenShift via Azure DevOps CI/CD. Version profiles cover .NET 10 (new projects), .NET 8 LTS (active client projects), and .NET 6 LTS (legacy maintenance).',
    'Code2', '#2563EB', NULL, NULL, 10, v_user_id,
    '{"default_version": "10.0", "primary": true}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Rai-Tech .NET Stack' AND parent_id IS NULL);
  SELECT id INTO v_stack_dotnet FROM tech_stacks WHERE name = 'Rai-Tech .NET Stack' AND parent_id IS NULL;

  INSERT INTO tech_stacks (id, name, description, short_description, long_description, icon, color, type, order_index, created_by, metadata)
  SELECT gen_random_uuid(),
    'Rai-Tech Supabase Stack',
    'Backend-as-a-service stack using self-hosted Supabase, PostgreSQL 17, and pgvector',
    'Supabase + PostgreSQL 17 + pgvector for data, auth, storage, and real-time',
    'The Rai-Tech data and BaaS stack centred on self-hosted Supabase. PostgreSQL 17 for relational data, pgvector 0.8 for vector similarity search, Row Level Security on all tables, Edge Functions (Deno), Supabase Auth with Azure AD SSO, S3-compatible Storage, and Realtime subscriptions. Powers all Rai-Tech and client applications that need a managed backend.',
    'Database', '#0D9488', NULL, NULL, 20, v_user_id,
    '{"primary": true}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Rai-Tech Supabase Stack' AND parent_id IS NULL);
  SELECT id INTO v_stack_supabase FROM tech_stacks WHERE name = 'Rai-Tech Supabase Stack' AND parent_id IS NULL;

  INSERT INTO tech_stacks (id, name, description, short_description, long_description, icon, color, type, order_index, created_by, metadata)
  SELECT gen_random_uuid(),
    'Rai-Tech AI / ML Stack',
    'Python-based AI and ML stack with vLLM, LangGraph, pgvector RAG, and custom models',
    'Python 3.13 · LangGraph · vLLM · Nemotron · DistilBERT · RAG',
    'The Rai-Tech AI/ML stack for agentic systems, RAG pipelines, and custom ML models. Anchored on self-hosted vLLM serving Nemotron models on the DGX Spark, LangGraph for stateful multi-agent orchestration, pgvector for retrieval, and a DistilBERT classifier trained on 700k healthcare IT tickets (90-95% accuracy). Python 3.13 with uv, ruff, mypy strict, and Pydantic v2.',
    'Brain', '#EA580C', NULL, NULL, 30, v_user_id,
    '{"primary": true}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Rai-Tech AI / ML Stack' AND parent_id IS NULL);
  SELECT id INTO v_stack_python FROM tech_stacks WHERE name = 'Rai-Tech AI / ML Stack' AND parent_id IS NULL;

  INSERT INTO tech_stacks (id, name, description, short_description, long_description, icon, color, type, order_index, created_by, metadata)
  SELECT gen_random_uuid(),
    'Rai-Tech Frontend Stack',
    'TypeScript and React frontend stack for web applications and internal tools',
    'TypeScript 5.8 · React 19 · Vite 6 · TanStack Query · Tailwind · shadcn/ui',
    'The Rai-Tech frontend stack for all web applications. TypeScript 5.8 in strict mode, React 19 with compiler, Actions API, and Server Components, Vite 6 for build tooling, TanStack Query v5 for server state, Zustand for client state, Tailwind CSS v4 with shadcn/ui components, and Playwright for E2E and accessibility testing.',
    'FileCode', '#7C3AED', NULL, NULL, 40, v_user_id,
    '{"primary": true}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Rai-Tech Frontend Stack' AND parent_id IS NULL);
  SELECT id INTO v_stack_frontend FROM tech_stacks WHERE name = 'Rai-Tech Frontend Stack' AND parent_id IS NULL;

  RAISE NOTICE 'Parent stacks done';

  -- ================================================================
  -- .NET — VERSION PROFILES
  -- ================================================================

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet,
    '.NET 10 — Current LTS',
    'Default for all new Rai-Tech and new client projects. LTS until November 2028.',
    'C# 14 / .NET 10.0 LTS — released November 11 2025, supported until November 2028',
    'Star', '#2563EB', 'version_profile', '10.0', '>=10.0', 10, v_user_id,
    '{"is_default": true, "lts": true, "lts_until": "2028-11-14", "use_for": "All new projects", "csharp_version": "14"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = '.NET 10 — Current LTS' AND parent_id = v_stack_dotnet);
  SELECT id INTO v_dotnet_v10 FROM tech_stacks WHERE name = '.NET 10 — Current LTS' AND parent_id = v_stack_dotnet;

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet,
    '.NET 8 — LTS (Active Client Projects)',
    'For existing client projects already on .NET 8. Do not start new projects on this version.',
    'C# 12 / .NET 8.0 LTS — released November 2023, supported until November 2026',
    'Clock', '#64748B', 'version_profile', '8.0', '>=8.0 <10.0', 20, v_user_id,
    '{"is_default": false, "lts": true, "lts_until": "2026-11-10", "use_for": "Active client projects on .NET 8", "csharp_version": "12"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = '.NET 8 — LTS (Active Client Projects)' AND parent_id = v_stack_dotnet);
  SELECT id INTO v_dotnet_v8 FROM tech_stacks WHERE name = '.NET 8 — LTS (Active Client Projects)' AND parent_id = v_stack_dotnet;

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet,
    '.NET 6 — LTS Legacy (Maintenance Only)',
    'Legacy maintenance only. No new features. Plan migration to .NET 10 before November 2024 EOL.',
    'C# 10 / .NET 6.0 LTS — EOL November 2024. Maintenance mode only.',
    'AlertTriangle', '#DC2626', 'version_profile', '6.0', '>=6.0 <8.0', 30, v_user_id,
    '{"is_default": false, "lts": false, "eol": "2024-11-12", "use_for": "Legacy maintenance only — plan migration", "csharp_version": "10"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = '.NET 6 — LTS Legacy (Maintenance Only)' AND parent_id = v_stack_dotnet);
  SELECT id INTO v_dotnet_v6 FROM tech_stacks WHERE name = '.NET 6 — LTS Legacy (Maintenance Only)' AND parent_id = v_stack_dotnet;

  -- ================================================================
  -- .NET — INDIVIDUAL TECHNOLOGIES
  -- ================================================================

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet, 'C# 14',
    'Primary language — C# 14 with extension members, field keyword, null-conditional assignment, partial constructors',
    'C# 14 on .NET 10 — extension members, field keyword, null-conditional assignment, partial constructors/events',
    'Code2', '#2563EB', 'language', '14.0', '>=12.0', 40, v_user_id,
    '{"nuget_package": null, "docs": "https://learn.microsoft.com/en-us/dotnet/csharp/whats-new/csharp-14"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'C# 14' AND parent_id = v_stack_dotnet);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet, 'ASP.NET Core 10',
    'Web framework — Minimal API with built-in validation, OpenAPI 3.1/YAML, SSE. MVC for complex UI only.',
    'ASP.NET Core 10 — Minimal API preferred. Built-in validation, OpenAPI 3.1, Server-Sent Events',
    'Globe', '#2563EB', 'framework', '10.0', '>=8.0', 50, v_user_id,
    '{"nuget_package": "Microsoft.AspNetCore.App", "docs": "https://learn.microsoft.com/en-us/aspnet/core"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'ASP.NET Core 10' AND parent_id = v_stack_dotnet);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet, 'Entity Framework Core 10',
    'ORM — code-first migrations, Fluent API, complex types, Native AOT support, Left/RightJoin, named filters',
    'EF Core 10 with PostgreSQL provider (Npgsql), code-first migrations, complex types, Native AOT',
    'Database', '#2563EB', 'library', '10.0', '>=8.0', 60, v_user_id,
    '{"nuget_package": "Microsoft.EntityFrameworkCore", "provider": "Npgsql.EntityFrameworkCore.PostgreSQL"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Entity Framework Core 10' AND parent_id = v_stack_dotnet);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet, 'MediatR',
    'CQRS and mediator pattern for commands, queries, and domain events in Clean Architecture',
    'MediatR 12+ for CQRS — commands, queries, notifications, pipeline behaviours',
    'GitBranch', '#2563EB', 'library', '12.0', '>=12.0', 70, v_user_id,
    '{"nuget_package": "MediatR"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'MediatR' AND parent_id = v_stack_dotnet);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet, 'FluentValidation',
    'Validation library for Application layer — rule-based validation with clean syntax',
    'FluentValidation 11+ for Application layer input validation',
    'CheckSquare', '#2563EB', 'library', '11.0', '>=11.0', 80, v_user_id,
    '{"nuget_package": "FluentValidation"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'FluentValidation' AND parent_id = v_stack_dotnet);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet, 'xUnit + NSubstitute + FluentAssertions',
    'Standard .NET testing stack — xUnit for tests, NSubstitute for mocking, FluentAssertions for readable assertions',
    'xUnit · NSubstitute · FluentAssertions — the Rai-Tech .NET testing standard',
    'TestTube2', '#16A34A', 'library', 'latest', null, 90, v_user_id,
    '{"nuget_packages": ["xunit", "NSubstitute", "FluentAssertions"], "coverage_tool": "Coverlet"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'xUnit + NSubstitute + FluentAssertions' AND parent_id = v_stack_dotnet);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet, 'Serilog',
    'Structured logging — Serilog with Seq/Grafana Loki sinks. No string interpolation in log messages.',
    'Serilog 4+ with structured logging — Seq (dev) and Grafana Loki (prod) sinks',
    'Activity', '#EA580C', 'library', '4.0', '>=3.0', 100, v_user_id,
    '{"nuget_package": "Serilog", "sinks": ["Serilog.Sinks.Console", "Serilog.Sinks.Seq", "Serilog.Sinks.Grafana.Loki"]}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Serilog' AND parent_id = v_stack_dotnet);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet, 'OpenTelemetry .NET',
    'Distributed tracing and metrics — W3C TraceContext, Prometheus exporter, Jaeger/Grafana Tempo',
    'OpenTelemetry .NET — W3C trace propagation, Prometheus metrics, OTLP exporter',
    'Activity', '#EA580C', 'library', 'latest', '>=1.0', 110, v_user_id,
    '{"nuget_package": "OpenTelemetry", "exporters": ["Prometheus", "OTLP", "Jaeger"]}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'OpenTelemetry .NET' AND parent_id = v_stack_dotnet);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet, 'Azure AD / Microsoft Identity',
    'Auth via Microsoft.Identity.Web — OIDC/OAuth 2.0 with PKCE, MFA via Conditional Access, no custom auth',
    'Microsoft.Identity.Web — Azure AD authentication, OIDC/OAuth 2.0, PKCE, MFA',
    'Shield', '#DC2626', 'service', 'latest', null, 120, v_user_id,
    '{"nuget_package": "Microsoft.Identity.Web", "flow": "authorization_code+PKCE"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Azure AD / Microsoft Identity' AND parent_id = v_stack_dotnet);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet, 'Azure Key Vault',
    'Secret management — all connection strings and API keys via Key Vault with managed identity',
    'Azure Key Vault with managed identity — no secrets in config files or source control',
    'Lock', '#DC2626', 'service', 'latest', null, 130, v_user_id,
    '{"nuget_package": "Azure.Extensions.AspNetCore.Configuration.Secrets"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Azure Key Vault' AND parent_id = v_stack_dotnet);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet, 'Docker + OpenShift',
    'Multi-stage Docker builds to OpenShift (OCP) — non-root user, health probes, resource limits required',
    'Docker multi-stage builds → OpenShift deployment with health probes and resource limits',
    'Box', '#1B3A6B', 'platform', 'latest', null, 140, v_user_id,
    '{"base_image": "mcr.microsoft.com/dotnet/aspnet:10.0", "build_image": "mcr.microsoft.com/dotnet/sdk:10.0"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Docker + OpenShift' AND parent_id = v_stack_dotnet);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_dotnet, 'Azure DevOps',
    'CI/CD — pipelines as code in azure-pipelines.yml, variable groups for secrets, environments for approvals',
    'Azure DevOps — pipeline-as-code, branch policies, artifact registry, work tracking',
    'GitBranch', '#1B3A6B', 'platform', 'latest', null, 150, v_user_id,
    '{"pipeline_file": "azure-pipelines.yml", "stages": ["Build", "Test", "Security", "Package", "Deploy"]}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Azure DevOps' AND parent_id = v_stack_dotnet);

  RAISE NOTICE '.NET stack done';

  -- ================================================================
  -- SUPABASE STACK — TECHNOLOGIES
  -- ================================================================

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_supabase, 'Supabase (Self-Hosted)',
    'Self-hosted Supabase via Docker Compose — full stack: Auth, Storage, Realtime, Edge Functions, PostgREST',
    'Self-hosted Supabase — API on :8000, Studio on :54323, DB on :5432',
    'Database', '#0D9488', 'platform', 'latest', null, 10, v_user_id,
    '{"deployment": "self-hosted", "local_dev_port": 54321, "studio_port": 54323, "db_port": 54322}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Supabase (Self-Hosted)' AND parent_id = v_stack_supabase);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_supabase, 'PostgreSQL 17',
    'Primary relational database — UUID PKs, timestamptz, RLS on all tables, migrations via Supabase CLI',
    'PostgreSQL 17 — primary database, UUID PKs, RLS enforced, Supabase CLI migrations',
    'Database', '#0D9488', 'database', '17', '>=15', 20, v_user_id,
    '{"extensions": ["uuid-ossp", "pgcrypto", "vector", "pg_stat_statements"], "docs": "https://www.postgresql.org/docs/17/"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'PostgreSQL 17' AND parent_id = v_stack_supabase);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_supabase, 'pgvector 0.8',
    'Vector similarity search — HNSW indexes, cosine/L2/inner product, hybrid search with full-text',
    'pgvector 0.8 — HNSW indexes, cosine similarity, hybrid BM25 + vector search for RAG',
    'Brain', '#0D9488', 'extension', '0.8', '>=0.5', 30, v_user_id,
    '{"index_type": "hnsw", "ops": "vector_cosine_ops", "dimensions": {"nemotron": 4096, "openai_small": 1536}}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'pgvector 0.8' AND parent_id = v_stack_supabase);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_supabase, 'Supabase Auth',
    'Authentication — email/password, Azure AD SSO via OIDC, JWT access tokens (1hr), custom SMTP required in prod',
    'Supabase Auth — email/password + Azure AD SSO, JWT, MFA, custom SMTP for production',
    'Shield', '#0D9488', 'service', 'latest', null, 40, v_user_id,
    '{"sso_provider": "Azure AD (OIDC)", "access_token_expiry": "1h", "refresh_token_expiry": "7d"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Supabase Auth' AND parent_id = v_stack_supabase);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_supabase, 'Supabase Edge Functions',
    'Deno-based serverless functions — business logic, third-party API calls, privileged operations (service_role)',
    'Deno edge functions — server-side business logic, secrets in env vars, never in client code',
    'Zap', '#0D9488', 'runtime', 'latest', null, 50, v_user_id,
    '{"runtime": "Deno", "timeout_default": "60s", "cors": "explicit only — no wildcard in production"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Supabase Edge Functions' AND parent_id = v_stack_supabase);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_supabase, 'Supabase Realtime',
    'WebSocket subscriptions — postgres_changes for DB events, broadcast for ephemeral messaging',
    'Supabase Realtime — postgres_changes (RLS-enforced) and broadcast channels',
    'Activity', '#0D9488', 'service', 'latest', null, 60, v_user_id,
    '{"modes": ["postgres_changes", "broadcast", "presence"], "rls": "enforced on postgres_changes"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Supabase Realtime' AND parent_id = v_stack_supabase);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_supabase, 'Supabase Storage',
    'S3-compatible file storage — RLS on all buckets, signed URLs for private files, no public buckets for PHI',
    'Supabase Storage (S3-compatible) — RLS-enforced buckets, signed URLs, no PHI in public buckets',
    'Archive', '#0D9488', 'service', 'latest', null, 70, v_user_id,
    '{"s3_compatible": true, "private_buckets": true, "signed_url_expiry": "1h for downloads, 15m for uploads"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Supabase Storage' AND parent_id = v_stack_supabase);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_supabase, 'Supabase CLI',
    'Local development toolchain — supabase start, db push, migration management, functions serve',
    'Supabase CLI — local dev stack, migration management, edge function deployment',
    'Terminal', '#0D9488', 'tool', 'latest', null, 80, v_user_id,
    '{"install": "npm install supabase --save-dev", "key_commands": ["supabase start", "supabase db push", "supabase migration new", "supabase functions serve"]}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Supabase CLI' AND parent_id = v_stack_supabase);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_supabase, 'PgBouncer',
    'Connection pooler — transaction mode for API workloads. Use port 6543 for serverless, 5432 for migrations only.',
    'PgBouncer — connection pooler in transaction mode for APIs and edge functions',
    'Database', '#0D9488', 'tool', 'latest', null, 90, v_user_id,
    '{"mode": "transaction", "api_port": 6543, "migration_port": 5432}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'PgBouncer' AND parent_id = v_stack_supabase);

  RAISE NOTICE 'Supabase stack done';

  -- ================================================================
  -- AI / ML STACK — VERSION PROFILE + TECHNOLOGIES
  -- ================================================================

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_python,
    'Python 3.13 — Current',
    'Default Python version for all Rai-Tech AI/ML work. Free-threaded mode available (experimental).',
    'Python 3.13 — current stable, free-threaded GIL removal (experimental), improved error messages',
    'Star', '#16A34A', 'version_profile', '3.13', '>=3.11', 10, v_user_id,
    '{"is_default": true, "package_manager": "uv", "linter": "ruff", "type_checker": "mypy --strict"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Python 3.13 — Current' AND parent_id = v_stack_python);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_python, 'Python 3.13',
    'Primary AI/ML language — 3.13 with uv package manager, ruff linter/formatter, mypy strict type checking',
    'Python 3.13 · uv · ruff · mypy strict — Rai-Tech AI/ML language standard',
    'Terminal', '#16A34A', 'language', '3.13', '>=3.11', 20, v_user_id,
    '{"package_manager": "uv", "linter_formatter": "ruff", "type_checker": "mypy --strict", "project_layout": "src/"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Python 3.13' AND parent_id = v_stack_python);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_python, 'LangGraph',
    'Agentic workflow orchestration — typed state, checkpointing with PostgreSQL, human-in-the-loop, interrupt_before',
    'LangGraph — stateful multi-agent workflows, typed state, PostgreSQL checkpointing',
    'GitBranch', '#16A34A', 'framework', 'latest', '>=0.2', 30, v_user_id,
    '{"checkpointer": "PostgreSQL (production), InMemory (dev)", "pattern": "TypedDict state, pure node functions"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'LangGraph' AND parent_id = v_stack_python);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_python, 'vLLM',
    'Self-hosted LLM inference — OpenAI-compatible API, served on DGX Spark, exponential backoff required',
    'vLLM — self-hosted on DGX Spark, OpenAI-compatible API, serving Nemotron models',
    'Zap', '#EA580C', 'platform', 'latest', '>=0.4', 40, v_user_id,
    '{"hardware": "DGX Spark", "api_compatible": "OpenAI", "model_env_var": "VLLM_MODEL_NAME"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'vLLM' AND parent_id = v_stack_python);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_python, 'NVIDIA Nemotron',
    'Primary LLM family — Nemotron-Orchestrator-8B and variants. Temperature 0 for deterministic, 0.7 for creative.',
    'Nemotron-Orchestrator-8B — primary model for all Rai-Tech agentic and generative AI workflows',
    'Brain', '#EA580C', 'model', 'latest', null, 50, v_user_id,
    '{"models": ["Nemotron-Orchestrator-8B"], "deterministic_temp": 0.0, "creative_temp": 0.7, "max_tokens_default": 1000}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'NVIDIA Nemotron' AND parent_id = v_stack_python);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_python, 'DistilBERT Healthcare IT Router',
    'Custom classifier — fine-tuned on 700k healthcare IT tickets, 90-95% accuracy, served via FastAPI on vLLM',
    'DistilBERT fine-tuned on 700k healthcare IT tickets — 90-95% routing accuracy',
    'Brain', '#16A34A', 'model', 'latest', null, 60, v_user_id,
    '{"training_data": "700k healthcare IT tickets", "accuracy": "90-95%", "serving": "FastAPI", "monitoring": "distribution drift alerts"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'DistilBERT Healthcare IT Router' AND parent_id = v_stack_python);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_python, 'Pydantic v2',
    'Data validation and settings — v2 with Rust core, 5-50x faster than v1. Used for LLM output parsing.',
    'Pydantic v2 — data validation, settings management, structured LLM output parsing',
    'CheckSquare', '#16A34A', 'library', '2.0', '>=2.0', 70, v_user_id,
    '{"pip_package": "pydantic", "settings": "pydantic-settings", "rust_core": true}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Pydantic v2' AND parent_id = v_stack_python);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_python, 'FastAPI',
    'Python API framework — async, auto-documented, type-safe. Used for ML model serving and Python APIs.',
    'FastAPI — async Python APIs, OpenAPI docs, type-safe, used for ML model serving',
    'Globe', '#16A34A', 'framework', 'latest', '>=0.100', 80, v_user_id,
    '{"pip_package": "fastapi[standard]", "docs": "auto-generated at /docs"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'FastAPI' AND parent_id = v_stack_python);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_python, 'Prometheus + Grafana',
    'Observability stack — Prometheus scrapes metrics, Grafana dashboards, Loki for logs, Tempo for traces',
    'Prometheus + Grafana + Loki + Tempo — full observability stack in Rai-Tech homelab',
    'Activity', '#EA580C', 'platform', 'latest', null, 90, v_user_id,
    '{"components": ["Prometheus", "Grafana", "Grafana Loki", "Grafana Tempo"], "hosted": "Rai-Tech homelab"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Prometheus + Grafana' AND parent_id = v_stack_python);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_python, 'ClickHouse',
    'Analytics database — high-volume event storage, time-series, log aggregation. Hosted in Rai-Tech homelab.',
    'ClickHouse — analytics, event storage, time-series data in Rai-Tech homelab',
    'Database', '#EA580C', 'database', 'latest', null, 100, v_user_id,
    '{"hosted": "Rai-Tech homelab", "use_cases": ["event storage", "log aggregation", "time-series", "analytics"]}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'ClickHouse' AND parent_id = v_stack_python);

  RAISE NOTICE 'AI/ML stack done';

  -- ================================================================
  -- FRONTEND STACK — VERSION PROFILES + TECHNOLOGIES
  -- ================================================================

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_frontend,
    'React 19 — Current (New Projects)',
    'Default for all new frontend projects. React Compiler, Actions API, Server Components, built-in form handling.',
    'React 19.2 — React Compiler, Actions API, Activity component, useEffectEvent — default for new projects',
    'Star', '#7C3AED', 'version_profile', '19.2', '>=19.0', 10, v_user_id,
    '{"is_default": true, "compiler": true, "server_components": true, "actions_api": true}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'React 19 — Current (New Projects)' AND parent_id = v_stack_frontend);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_frontend,
    'React 18 — LTS (Existing Projects)',
    'For existing projects on React 18. Concurrent features, Suspense. Plan migration to React 19.',
    'React 18 — concurrent features, Suspense, useTransition — for existing client projects only',
    'Clock', '#64748B', 'version_profile', '18.x', '>=18.0 <19.0', 20, v_user_id,
    '{"is_default": false, "use_for": "Existing projects — plan migration to React 19"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'React 18 — LTS (Existing Projects)' AND parent_id = v_stack_frontend);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_frontend, 'TypeScript 5.8',
    'Strict mode — noUncheckedIndexedAccess, exactOptionalPropertyTypes. No any. No @ts-ignore.',
    'TypeScript 5.8 strict mode — noUncheckedIndexedAccess, exactOptionalPropertyTypes, no any',
    'FileCode', '#7C3AED', 'language', '5.8', '>=5.0', 30, v_user_id,
    '{"strict": true, "noUncheckedIndexedAccess": true, "exactOptionalPropertyTypes": true, "noImplicitReturns": true}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'TypeScript 5.8' AND parent_id = v_stack_frontend);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_frontend, 'Vite 6',
    'Build tool — HMR, code splitting, optimised production builds. Environment API in v6.',
    'Vite 6 — fast HMR, Environment API, optimised production builds with code splitting',
    'Zap', '#7C3AED', 'tool', '6.0', '>=5.0', 40, v_user_id,
    '{"config_file": "vite.config.ts", "new_in_v6": "Environment API for SSR/RSC"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Vite 6' AND parent_id = v_stack_frontend);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_frontend, 'TanStack Query v5',
    'Server state management — replaces useEffect data fetching, handles caching, loading, error states',
    'TanStack Query v5 — all server state, replaces useEffect fetching, stale-while-revalidate',
    'RefreshCw', '#7C3AED', 'library', '5.0', '>=5.0', 50, v_user_id,
    '{"npm_package": "@tanstack/react-query", "devtools": "@tanstack/react-query-devtools"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'TanStack Query v5' AND parent_id = v_stack_frontend);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_frontend, 'Zustand',
    'Client state — global state that persists across routes. Not for server data (use TanStack Query).',
    'Zustand — global client state across routes, replaces Redux, minimal boilerplate',
    'Box', '#7C3AED', 'library', '5.0', '>=4.0', 60, v_user_id,
    '{"npm_package": "zustand", "use_for": "Global client state only — not server data"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Zustand' AND parent_id = v_stack_frontend);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_frontend, 'Tailwind CSS v4',
    'Utility-first CSS — v4 with CSS-native config, faster build engine, no tailwind.config.js needed',
    'Tailwind CSS v4 — CSS-native config, Lightning CSS engine, no config file required',
    'Palette', '#7C3AED', 'framework', '4.0', '>=3.0', 70, v_user_id,
    '{"npm_package": "tailwindcss", "new_in_v4": "CSS-native config (@theme), Lightning CSS, 10x faster builds"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Tailwind CSS v4' AND parent_id = v_stack_frontend);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_frontend, 'shadcn/ui',
    'Component library — copy-paste Radix UI primitives with Tailwind. Accessible by default.',
    'shadcn/ui — accessible Radix UI primitives with Tailwind, copy-paste not npm install',
    'Layout', '#7C3AED', 'library', 'latest', null, 80, v_user_id,
    '{"install": "npx shadcn@latest add [component]", "base": "Radix UI", "accessible": true}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'shadcn/ui' AND parent_id = v_stack_frontend);

  INSERT INTO tech_stacks (id, parent_id, name, description, short_description, icon, color, type, version, version_constraint, order_index, created_by, metadata)
  SELECT gen_random_uuid(), v_stack_frontend, 'Playwright',
    'E2E testing — browser automation, accessibility testing with axe-core, visual regression',
    'Playwright — E2E tests, axe-core accessibility checks, visual regression testing',
    'TestTube2', '#16A34A', 'library', 'latest', '>=1.40', 90, v_user_id,
    '{"npm_package": "@playwright/test", "accessibility": "axe-core via @axe-core/playwright"}'::jsonb
  WHERE NOT EXISTS (SELECT 1 FROM tech_stacks WHERE name = 'Playwright' AND parent_id = v_stack_frontend);

  RAISE NOTICE 'Frontend stack done';

  -- ================================================================
  -- LINK ALL STACKS TO RELEVANT STANDARDS
  -- ================================================================

  RAISE NOTICE 'Linking standards to parent stacks...';

  -- .NET stack → APP, TST, DEV, SEC, ARC, OBS, PRV standards
  INSERT INTO tech_stack_standards (id, tech_stack_id, standard_id, created_at)
  SELECT gen_random_uuid(), v_stack_dotnet, s.id, now()
  FROM standards s
  WHERE s.code LIKE ANY(ARRAY['APP-%','TST-%','DEV-%','SEC-%','ARC-%','OBS-%','PRV-%'])
  AND NOT EXISTS (SELECT 1 FROM tech_stack_standards WHERE tech_stack_id = v_stack_dotnet AND standard_id = s.id);

  -- Supabase stack → DB, SUP, SEC, API, PER, PRV standards
  INSERT INTO tech_stack_standards (id, tech_stack_id, standard_id, created_at)
  SELECT gen_random_uuid(), v_stack_supabase, s.id, now()
  FROM standards s
  WHERE s.code LIKE ANY(ARRAY['DB-%','SUP-%','SEC-%','API-%','PER-%','PRV-%'])
  AND NOT EXISTS (SELECT 1 FROM tech_stack_standards WHERE tech_stack_id = v_stack_supabase AND standard_id = s.id);

  -- AI/ML stack → AI, PY, DB, ARC, PRV, OBS standards
  INSERT INTO tech_stack_standards (id, tech_stack_id, standard_id, created_at)
  SELECT gen_random_uuid(), v_stack_python, s.id, now()
  FROM standards s
  WHERE s.code LIKE ANY(ARRAY['AI-%','PY-%','DB-%','ARC-%','PRV-%','OBS-%'])
  AND NOT EXISTS (SELECT 1 FROM tech_stack_standards WHERE tech_stack_id = v_stack_python AND standard_id = s.id);

  -- Frontend stack → TSR, ACC, PER, TST, SEC, API standards
  INSERT INTO tech_stack_standards (id, tech_stack_id, standard_id, created_at)
  SELECT gen_random_uuid(), v_stack_frontend, s.id, now()
  FROM standards s
  WHERE s.code LIKE ANY(ARRAY['TSR-%','ACC-%','PER-%','TST-%','SEC-%','API-%'])
  AND NOT EXISTS (SELECT 1 FROM tech_stack_standards WHERE tech_stack_id = v_stack_frontend AND standard_id = s.id);

  RAISE NOTICE '=== Rai-Tech Tech Stacks Seed v2 Complete ===';
  RAISE NOTICE '4 parent stacks · version profiles · 40 technologies · standards linked';

END $$;

-- ================================================================
-- VERIFY
-- ================================================================
SELECT
  CASE
    WHEN ts.parent_id IS NULL THEN '◆ ' || ts.name
    WHEN ts.type = 'version_profile' THEN '  ▸ [VERSION] ' || ts.name
    ELSE '  · ' || ts.name
  END AS stack_tree,
  ts.type,
  ts.version,
  COUNT(tss.id) AS linked_standards
FROM tech_stacks ts
LEFT JOIN tech_stack_standards tss ON tss.tech_stack_id = ts.id
GROUP BY ts.id, ts.name, ts.parent_id, ts.type, ts.version, ts.order_index
ORDER BY
  COALESCE(ts.parent_id::text, ts.id::text),
  ts.parent_id IS NOT NULL,
  ts.order_index;
