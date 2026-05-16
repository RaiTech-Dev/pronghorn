-- ================================================================
-- RAI-TECH — Build Books Seed Script
-- Supabase Studio → SQL Editor: http://127.0.0.1:54323
--
-- 5 Build Books — structure + standards + tech stack links
-- Prompts are PLACEHOLDERS — refine in the Pronghorn UI
-- Safe to re-run: WHERE NOT EXISTS on name
-- ================================================================

DO $$
DECLARE
  v_user_id uuid;

  -- Build Book IDs
  v_bb_dotnet     uuid;
  v_bb_supabase   uuid;
  v_bb_healthcare uuid;
  v_bb_ai         uuid;
  v_bb_frontend   uuid;

  -- Tech Stack IDs
  v_stack_dotnet    uuid;
  v_stack_supabase  uuid;
  v_stack_python    uuid;
  v_stack_frontend  uuid;

BEGIN
  SELECT id INTO v_user_id FROM auth.users ORDER BY created_at LIMIT 1;
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'No users found — log into Pronghorn first.';
  END IF;

  -- Get tech stack IDs
  SELECT id INTO v_stack_dotnet   FROM tech_stacks WHERE name = 'Rai-Tech .NET Stack'       AND parent_id IS NULL;
  SELECT id INTO v_stack_supabase FROM tech_stacks WHERE name = 'Rai-Tech Supabase Stack'   AND parent_id IS NULL;
  SELECT id INTO v_stack_python   FROM tech_stacks WHERE name = 'Rai-Tech AI / ML Stack'    AND parent_id IS NULL;
  SELECT id INTO v_stack_frontend FROM tech_stacks WHERE name = 'Rai-Tech Frontend Stack'   AND parent_id IS NULL;

  IF v_stack_dotnet IS NULL THEN
    RAISE EXCEPTION 'Tech stacks not found — run raitech_techstacks_seed.sql first.';
  END IF;

  RAISE NOTICE 'Seeding Build Books as user: %', v_user_id;

  -- ================================================================
  -- BUILD BOOK 1: .NET Clean Architecture API
  -- ================================================================
  INSERT INTO build_books (
    id, name, short_description, long_description,
    tags, is_published, created_by, prompt, deploy_count
  )
  SELECT
    gen_random_uuid(),
    'Rai-Tech .NET Clean Architecture API',
    'ASP.NET Core 10 Minimal API with Clean Architecture, EF Core, Azure AD, and OpenShift deployment',
    'Standard Rai-Tech template for building production .NET 10 backend APIs. Enforces Clean Architecture ' ||
    '(Domain / Application / Infrastructure / Web), Minimal API endpoints, Entity Framework Core with ' ||
    'PostgreSQL, MediatR for CQRS, FluentValidation, Serilog structured logging, Azure AD authentication, ' ||
    'health check endpoints, and Docker multi-stage builds targeting OpenShift via Azure DevOps. ' ||
    'Use this for all new Rai-Tech and client backend API projects.',
    ARRAY['dotnet', 'api', 'clean-architecture', 'azure-ad', 'openshift', 'backend'],
    true,
    v_user_id,
    -- PLACEHOLDER PROMPT — refine in Pronghorn UI
    'You are a senior .NET 10 engineer at Rai-Tech building a Clean Architecture API.' || E'\n\n' ||
    'ARCHITECTURE: Enforce 4 layers — Domain (entities, interfaces, no external deps), Application ' ||
    '(use cases, MediatR commands/queries, FluentValidation, DTOs), Infrastructure (EF Core, repositories, ' ||
    'external services), Web (Minimal API endpoints, middleware). Never reference outer layers from inner layers.' || E'\n\n' ||
    'CODE STANDARDS: C# 14, async/await everywhere (no .Result or .Wait()), Result pattern for expected ' ||
    'failures (no throwing exceptions for business rules), constructor injection only, ' ||
    'file-scoped namespaces, nullable reference types enabled and treated as errors.' || E'\n\n' ||
    'DATABASE: EF Core 10 with Npgsql provider, Fluent API configuration only (no Data Annotations on ' ||
    'domain entities), UUID primary keys (gen_random_uuid()), timestamptz for all dates, ' ||
    'explicit column types for all decimals, soft delete with DeletedAt column.' || E'\n\n' ||
    'API: Minimal API preferred, URL versioning (/api/v1/), ProblemDetails (RFC 7807) for all errors, ' ||
    'health checks at /health/live and /health/ready.' || E'\n\n' ||
    'LOGGING: Serilog structured logging — never use string interpolation in log messages. ' ||
    'All logs enriched with CorrelationId, MachineName, Environment.' || E'\n\n' ||
    'DEPLOYMENT: Multi-stage Dockerfile (SDK build → aspnet:10.0 runtime), non-root user, ' ||
    'azure-pipelines.yml with Build/Test/Security/Package/Deploy stages.' || E'\n\n' ||
    '[REFINE THIS PROMPT IN PRONGHORN UI — add project-specific context here]',
    0
  WHERE NOT EXISTS (SELECT 1 FROM build_books WHERE name = 'Rai-Tech .NET Clean Architecture API');
  SELECT id INTO v_bb_dotnet FROM build_books WHERE name = 'Rai-Tech .NET Clean Architecture API';

  -- ================================================================
  -- BUILD BOOK 2: Supabase Full-Stack App
  -- ================================================================
  INSERT INTO build_books (
    id, name, short_description, long_description,
    tags, is_published, created_by, prompt, deploy_count
  )
  SELECT
    gen_random_uuid(),
    'Rai-Tech Supabase Full-Stack App',
    'React 19 + TypeScript + Supabase — RLS enforced, Edge Functions, Realtime, and TanStack Query',
    'Standard Rai-Tech template for full-stack web applications backed by self-hosted Supabase. ' ||
    'TypeScript 5.8 strict mode, React 19 with Compiler and Actions API, Vite 6, TanStack Query v5 ' ||
    'for server state, Zustand for client state, Tailwind CSS v4, shadcn/ui components. ' ||
    'Supabase handles auth (Azure AD SSO), storage, real-time subscriptions, and Edge Functions ' ||
    'for server-side business logic. RLS enforced on every table. ' ||
    'Use this for new SaaS apps, internal tools, and client web applications.',
    ARRAY['supabase', 'react', 'typescript', 'fullstack', 'rls', 'realtime'],
    true,
    v_user_id,
    -- PLACEHOLDER PROMPT — refine in Pronghorn UI
    'You are a senior full-stack developer at Rai-Tech building a Supabase-backed web application.' || E'\n\n' ||
    'DATABASE: Enable RLS on every table before inserting any data — no exceptions. Separate policies ' ||
    'for SELECT, INSERT, UPDATE, DELETE. UUID primary keys, timestamptz for dates, soft delete with ' ||
    'deleted_at column. All migrations via Supabase CLI (supabase migration new).' || E'\n\n' ||
    'SUPABASE CLIENT: Generate TypeScript types with supabase gen types typescript. Always destructure ' ||
    '{ data, error } and check error before using data. Use anon key on client, service_role only in ' ||
    'Edge Functions. Never store tokens in localStorage manually — use Supabase JS client session management.' || E'\n\n' ||
    'EDGE FUNCTIONS: Handle CORS preflight, validate Authorization header, use user-scoped client ' ||
    '(not service_role) unless operation explicitly requires elevated permissions.' || E'\n\n' ||
    'FRONTEND: TypeScript strict mode (no any, no @ts-ignore). TanStack Query for all server state — ' ||
    'no useEffect for data fetching. Zustand for global client state only. ' ||
    'shadcn/ui components first before building custom. Clean up Realtime subscriptions on unmount.' || E'\n\n' ||
    '[REFINE THIS PROMPT IN PRONGHORN UI — add project-specific context here]',
    0
  WHERE NOT EXISTS (SELECT 1 FROM build_books WHERE name = 'Rai-Tech Supabase Full-Stack App');
  SELECT id INTO v_bb_supabase FROM build_books WHERE name = 'Rai-Tech Supabase Full-Stack App';

  -- ================================================================
  -- BUILD BOOK 3: Healthcare Application (most important)
  -- ================================================================
  INSERT INTO build_books (
    id, name, short_description, long_description,
    tags, is_published, created_by, prompt, deploy_count
  )
  SELECT
    gen_random_uuid(),
    'Rai-Tech Healthcare Application',
    'PHIA-compliant .NET 10 + Supabase application for AHS and health sector clients',
    'Rai-Tech template for healthcare and AHS client applications requiring PHIA (Alberta Health ' ||
    'Information Act) compliance. Inherits all .NET Clean Architecture standards plus: mandatory ' ||
    'audit logging on all health record access, soft delete required (no hard deletes of PHI), ' ||
    'data stored in Canada only, no external AI APIs for identifiable health information, ' ||
    'WCAG 2.1 AA accessibility required, Azure AD with MFA enforced via Conditional Access, ' ||
    'and AHS privacy office consultation required before go-live. ' ||
    'Use this for any project handling individually identifiable health information.',
    ARRAY['healthcare', 'phia', 'ahs', 'compliance', 'audit', 'dotnet', 'accessibility'],
    true,
    v_user_id,
    -- PLACEHOLDER PROMPT — refine in Pronghorn UI
    'You are a senior developer at Rai-Tech building a PHIA-compliant healthcare application for an ' ||
    'Alberta Health Services (AHS) client. This application handles individually identifiable health ' ||
    'information and must comply with the Alberta Health Information Act (HIA/PHIA).' || E'\n\n' ||
    'COMPLIANCE RULES (non-negotiable):' || E'\n' ||
    '- Never send PHI to external AI APIs (OpenAI, Anthropic, Google) — use self-hosted Nemotron only' || E'\n' ||
    '- All data storage must be in Canada — no US-region cloud services' || E'\n' ||
    '- Soft delete required on ALL health records (deleted_at, never DROP or hard DELETE)' || E'\n' ||
    '- Audit log every access to identifiable health information (who, what, when, why)' || E'\n' ||
    '- Azure AD MFA enforced via Conditional Access for all users' || E'\n' ||
    '- WCAG 2.1 AA minimum on all UI components' || E'\n\n' ||
    'AUDIT LOGGING: Every table storing health information must have an audit trigger recording ' ||
    'user_id, action, record_id, timestamp (UTC), and source_ip. Audit logs are immutable — ' ||
    'no UPDATE or DELETE on audit tables. Retain for minimum 7 years.' || E'\n\n' ||
    'DATA HANDLING: Classify all data before storing. Never log PHI values — log only that ' ||
    'access occurred to record ID X. Minimum dataset principle — collect only what is necessary.' || E'\n\n' ||
    'ARCHITECTURE: Follow Rai-Tech .NET Clean Architecture standards. Add a Healthcare bounded context ' ||
    'separate from any Patient Demographics, Clinical, and Billing contexts.' || E'\n\n' ||
    '[REFINE THIS PROMPT IN PRONGHORN UI — add client-specific context, AHS project details, ' ||
    'specific health information types handled, and any additional compliance requirements]',
    0
  WHERE NOT EXISTS (SELECT 1 FROM build_books WHERE name = 'Rai-Tech Healthcare Application');
  SELECT id INTO v_bb_healthcare FROM build_books WHERE name = 'Rai-Tech Healthcare Application';

  -- ================================================================
  -- BUILD BOOK 4: AI Agent / RAG Pipeline
  -- ================================================================
  INSERT INTO build_books (
    id, name, short_description, long_description,
    tags, is_published, created_by, prompt, deploy_count
  )
  SELECT
    gen_random_uuid(),
    'Rai-Tech AI Agent / RAG Pipeline',
    'Python 3.13 + LangGraph + vLLM + pgvector — agentic workflows and retrieval-augmented generation',
    'Rai-Tech template for building agentic AI systems and RAG pipelines. Python 3.13 with uv, ' ||
    'ruff, mypy strict, Pydantic v2 for all data validation. LangGraph for stateful multi-agent ' ||
    'orchestration with typed state and PostgreSQL checkpointing. Self-hosted vLLM serving Nemotron ' ||
    'models on the DGX Spark via OpenAI-compatible API. pgvector with HNSW indexes for retrieval. ' ||
    'FastAPI for serving. All AI output validated with Pydantic before use in production data flows.',
    ARRAY['ai', 'python', 'langgraph', 'vllm', 'pgvector', 'rag', 'nemotron'],
    true,
    v_user_id,
    -- PLACEHOLDER PROMPT — refine in Pronghorn UI
    'You are a senior AI/ML engineer at Rai-Tech building an agentic AI system or RAG pipeline.' || E'\n\n' ||
    'LANGGRAPH: Define a TypedDict for all graph state — no untyped dicts. Each node is a pure ' ||
    'function (state: MyState) -> dict — no side effects except intentional tool calls. ' ||
    'Use interrupt_before for any node that takes irreversible actions. ' ||
    'Use PostgreSQL checkpointer in production, InMemory in dev.' || E'\n\n' ||
    'VLLM / NEMOTRON: Use OpenAI-compatible client with base_url pointing to vLLM. ' ||
    'Read model name from VLLM_MODEL_NAME env var — never hardcode. ' ||
    'Set temperature=0.0 for deterministic tasks (classification, extraction, structured output). ' ||
    'Set temperature=0.7 for creative/generative tasks. Always set explicit max_tokens. ' ||
    'Implement exponential backoff with jitter for 429/503 responses.' || E'\n\n' ||
    'PGVECTOR / RAG: Create HNSW index before querying (vector_cosine_ops). ' ||
    'Chunk documents at semantic boundaries (256-512 tokens, 50-token overlap). ' ||
    'Store source metadata (doc_id, section, page, created_at) alongside each chunk. ' ||
    'Retrieve top-10, rerank with cross-encoder to top-3 for context. ' ||
    'Validate all LLM output with Pydantic before use in production data flows.' || E'\n\n' ||
    'PYTHON STANDARDS: Python 3.13, uv for packages, ruff for lint/format, mypy --strict. ' ||
    'Src layout (src/package_name/). Type hints on all public function signatures. ' ||
    'Pydantic v2 models for all structured data. Never use mutable default arguments.' || E'\n\n' ||
    '[REFINE THIS PROMPT IN PRONGHORN UI — add workflow-specific context, model selection, ' ||
    'retrieval strategy details, and any domain-specific requirements]',
    0
  WHERE NOT EXISTS (SELECT 1 FROM build_books WHERE name = 'Rai-Tech AI Agent / RAG Pipeline');
  SELECT id INTO v_bb_ai FROM build_books WHERE name = 'Rai-Tech AI Agent / RAG Pipeline';

  -- ================================================================
  -- BUILD BOOK 5: React Frontend
  -- ================================================================
  INSERT INTO build_books (
    id, name, short_description, long_description,
    tags, is_published, created_by, prompt, deploy_count
  )
  SELECT
    gen_random_uuid(),
    'Rai-Tech React Frontend',
    'TypeScript 5.8 + React 19 + Vite 6 + TanStack Query + Tailwind v4 + shadcn/ui',
    'Rai-Tech template for standalone frontend applications or UI layers where the API already exists. ' ||
    'TypeScript 5.8 strict mode, React 19 with Compiler and Actions API, Vite 6 build tooling, ' ||
    'TanStack Query v5 for all server state, Zustand for global client state, Tailwind CSS v4, ' ||
    'shadcn/ui components, and Playwright for E2E and accessibility testing. ' ||
    'WCAG 2.1 AA accessibility required on all components. ' ||
    'Use this when building a frontend that connects to an existing .NET or Supabase backend.',
    ARRAY['react', 'typescript', 'vite', 'tailwind', 'shadcn', 'frontend', 'accessibility'],
    true,
    v_user_id,
    -- PLACEHOLDER PROMPT — refine in Pronghorn UI
    'You are a senior frontend developer at Rai-Tech building a React 19 web application.' || E'\n\n' ||
    'TYPESCRIPT: Strict mode enforced — no any, no @ts-ignore, noUncheckedIndexedAccess, ' ||
    'exactOptionalPropertyTypes. Use type imports for type-only imports. ' ||
    'Interface over type for object shapes.' || E'\n\n' ||
    'REACT: Functional components only — no class components. One component per file, ' ||
    'filename matches component name. Explicit props interface for every component. ' ||
    'React.memo() only when profiling shows unnecessary re-renders — not by default. ' ||
    'Error boundaries at every route level.' || E'\n\n' ||
    'STATE: TanStack Query for ALL server state — no useEffect for data fetching. ' ||
    'Zustand for global client state that persists across routes. ' ||
    'useState for local UI state. Never use Redux.' || E'\n\n' ||
    'COMPONENTS: shadcn/ui first — check if the component exists before building custom. ' ||
    'Tailwind CSS v4 utility classes only — no custom CSS unless unavoidable. ' ||
    'Every interactive element must be keyboard accessible with visible focus indicator.' || E'\n\n' ||
    'ACCESSIBILITY: WCAG 2.1 AA required. All form inputs have associated labels. ' ||
    'Never use colour alone to convey information. axe-core checks in all Playwright tests. ' ||
    'Test with keyboard navigation before marking any feature complete.' || E'\n\n' ||
    '[REFINE THIS PROMPT IN PRONGHORN UI — add backend API details, auth method, ' ||
    'design system specifics, and any client-specific requirements]',
    0
  WHERE NOT EXISTS (SELECT 1 FROM build_books WHERE name = 'Rai-Tech React Frontend');
  SELECT id INTO v_bb_frontend FROM build_books WHERE name = 'Rai-Tech React Frontend';

  RAISE NOTICE 'Build Books inserted';

  -- ================================================================
  -- LINK TECH STACKS TO BUILD BOOKS
  -- ================================================================

  -- .NET API → .NET stack
  INSERT INTO build_book_tech_stacks (id, build_book_id, tech_stack_id, created_at)
  SELECT gen_random_uuid(), v_bb_dotnet, v_stack_dotnet, now()
  WHERE NOT EXISTS (SELECT 1 FROM build_book_tech_stacks WHERE build_book_id = v_bb_dotnet AND tech_stack_id = v_stack_dotnet);

  -- Supabase App → Supabase + Frontend stacks
  INSERT INTO build_book_tech_stacks (id, build_book_id, tech_stack_id, created_at)
  SELECT gen_random_uuid(), v_bb_supabase, v_stack_supabase, now()
  WHERE NOT EXISTS (SELECT 1 FROM build_book_tech_stacks WHERE build_book_id = v_bb_supabase AND tech_stack_id = v_stack_supabase);
  INSERT INTO build_book_tech_stacks (id, build_book_id, tech_stack_id, created_at)
  SELECT gen_random_uuid(), v_bb_supabase, v_stack_frontend, now()
  WHERE NOT EXISTS (SELECT 1 FROM build_book_tech_stacks WHERE build_book_id = v_bb_supabase AND tech_stack_id = v_stack_frontend);

  -- Healthcare → .NET + Supabase stacks
  INSERT INTO build_book_tech_stacks (id, build_book_id, tech_stack_id, created_at)
  SELECT gen_random_uuid(), v_bb_healthcare, v_stack_dotnet, now()
  WHERE NOT EXISTS (SELECT 1 FROM build_book_tech_stacks WHERE build_book_id = v_bb_healthcare AND tech_stack_id = v_stack_dotnet);
  INSERT INTO build_book_tech_stacks (id, build_book_id, tech_stack_id, created_at)
  SELECT gen_random_uuid(), v_bb_healthcare, v_stack_supabase, now()
  WHERE NOT EXISTS (SELECT 1 FROM build_book_tech_stacks WHERE build_book_id = v_bb_healthcare AND tech_stack_id = v_stack_supabase);

  -- AI Pipeline → AI/ML + Supabase stacks
  INSERT INTO build_book_tech_stacks (id, build_book_id, tech_stack_id, created_at)
  SELECT gen_random_uuid(), v_bb_ai, v_stack_python, now()
  WHERE NOT EXISTS (SELECT 1 FROM build_book_tech_stacks WHERE build_book_id = v_bb_ai AND tech_stack_id = v_stack_python);
  INSERT INTO build_book_tech_stacks (id, build_book_id, tech_stack_id, created_at)
  SELECT gen_random_uuid(), v_bb_ai, v_stack_supabase, now()
  WHERE NOT EXISTS (SELECT 1 FROM build_book_tech_stacks WHERE build_book_id = v_bb_ai AND tech_stack_id = v_stack_supabase);

  -- Frontend → Frontend stack
  INSERT INTO build_book_tech_stacks (id, build_book_id, tech_stack_id, created_at)
  SELECT gen_random_uuid(), v_bb_frontend, v_stack_frontend, now()
  WHERE NOT EXISTS (SELECT 1 FROM build_book_tech_stacks WHERE build_book_id = v_bb_frontend AND tech_stack_id = v_stack_frontend);

  RAISE NOTICE 'Tech stacks linked';

  -- ================================================================
  -- LINK STANDARDS TO BUILD BOOKS
  -- ================================================================

  -- .NET API: APP, TST, DEV, SEC, ARC, OBS, PRV
  INSERT INTO build_book_standards (id, build_book_id, standard_id, created_at)
  SELECT gen_random_uuid(), v_bb_dotnet, s.id, now()
  FROM standards s
  WHERE s.code LIKE ANY(ARRAY['APP-%','TST-%','DEV-%','SEC-%','ARC-%','OBS-%','PRV-%'])
  AND NOT EXISTS (SELECT 1 FROM build_book_standards WHERE build_book_id = v_bb_dotnet AND standard_id = s.id);

  -- Supabase App: DB, SUP, TSR, SEC, API, PER, ACC
  INSERT INTO build_book_standards (id, build_book_id, standard_id, created_at)
  SELECT gen_random_uuid(), v_bb_supabase, s.id, now()
  FROM standards s
  WHERE s.code LIKE ANY(ARRAY['DB-%','SUP-%','TSR-%','SEC-%','API-%','PER-%','ACC-%'])
  AND NOT EXISTS (SELECT 1 FROM build_book_standards WHERE build_book_id = v_bb_supabase AND standard_id = s.id);

  -- Healthcare: ALL standards (most restrictive template)
  INSERT INTO build_book_standards (id, build_book_id, standard_id, created_at)
  SELECT gen_random_uuid(), v_bb_healthcare, s.id, now()
  FROM standards s
  WHERE NOT EXISTS (SELECT 1 FROM build_book_standards WHERE build_book_id = v_bb_healthcare AND standard_id = s.id);

  -- AI Pipeline: AI, PY, DB, ARC, PRV, OBS
  INSERT INTO build_book_standards (id, build_book_id, standard_id, created_at)
  SELECT gen_random_uuid(), v_bb_ai, s.id, now()
  FROM standards s
  WHERE s.code LIKE ANY(ARRAY['AI-%','PY-%','DB-%','ARC-%','PRV-%','OBS-%'])
  AND NOT EXISTS (SELECT 1 FROM build_book_standards WHERE build_book_id = v_bb_ai AND standard_id = s.id);

  -- Frontend: TSR, ACC, PER, TST, SEC, API
  INSERT INTO build_book_standards (id, build_book_id, standard_id, created_at)
  SELECT gen_random_uuid(), v_bb_frontend, s.id, now()
  FROM standards s
  WHERE s.code LIKE ANY(ARRAY['TSR-%','ACC-%','PER-%','TST-%','SEC-%','API-%'])
  AND NOT EXISTS (SELECT 1 FROM build_book_standards WHERE build_book_id = v_bb_frontend AND standard_id = s.id);

  RAISE NOTICE '=== Rai-Tech Build Books Seed Complete ===';
  RAISE NOTICE '5 build books created with tech stacks and standards linked';

END $$;

-- ================================================================
-- VERIFY
-- ================================================================
SELECT
  bb.name AS build_book,
  bb.is_published,
  COUNT(DISTINCT bbs.standard_id) AS standards_linked,
  COUNT(DISTINCT bbts.tech_stack_id) AS stacks_linked,
  ARRAY_AGG(DISTINCT ts.name ORDER BY ts.name) AS tech_stacks
FROM build_books bb
LEFT JOIN build_book_standards bbs ON bbs.build_book_id = bb.id
LEFT JOIN build_book_tech_stacks bbts ON bbts.build_book_id = bb.id
LEFT JOIN tech_stacks ts ON ts.id = bbts.tech_stack_id
GROUP BY bb.id, bb.name, bb.is_published, bb.created_at
ORDER BY bb.created_at;
