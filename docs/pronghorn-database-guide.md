file_path: C:\Users\GurpreetRai\.claude\plans\pronghorn-database-guide.md
content: # Pronghorn — Database Schema Reference

**Purpose:** Complete reference for every table in the Pronghorn PostgreSQL database. Covers what each table stores, how it's used in the application, and how tables relate to each other. Written to support customization of standards, tech stacks, and organizational content.

---

## Enums (Custom Types)

These are PostgreSQL custom types used as column values across tables.

| Enum | Values | Used In |
|------|--------|---------|
| `project_status` | `DESIGN`, `AUDIT`, `BUILD` | `projects.status` — tracks which phase a project is in |
| `requirement_type` | `EPIC`, `FEATURE`, `STORY`, `ACCEPTANCE_CRITERIA` | `requirements.type` — the 4-level hierarchy |
| `node_type` | `COMPONENT`, `API`, `DATABASE`, `SERVICE`, `WEBHOOK`, `FIREWALL`, `SECURITY`, `REQUIREMENT`, `STANDARD`, `TECH_STACK` | `canvas_nodes.type` — what kind of block appears on the canvas |
| `audit_severity` | `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` | `audit_findings.severity` |
| `build_status` | `RUNNING`, `COMPLETED`, `FAILED` | `audit_runs.status`, `agent_sessions.status` |
| `app_role` | `admin`, `user` | `user_roles.role` — platform-level admin vs regular user |
| `project_token_role` | `owner`, `editor`, `viewer` | `project_tokens.role` — share link permission level |
| `deployment_environment` | `development`, `staging`, `production` | `project_deployments.environment` |
| `deployment_platform` | `pronghorn_cloud`, `local`, `dedicated_vm` | `project_deployments.platform` |
| `deployment_status` | `pending`, `building`, `deploying`, `running`, `stopped`, `failed`, `deleted` | `project_deployments.status` |
| `database_provider` | `render_postgres`, `supabase` | `project_databases.provider` |
| `resource_type` | `file`, `website`, `youtube`, `image` | `standard_resources`, `tech_stack_resources` — the type of reference material |

---

## Table Groups

---

## Group 1: Identity & Access

### `organizations`
**What it is:** Top-level tenant container. Every user belongs to an org.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| name | TEXT NOT NULL | Org display name |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**How it's used:** All projects, standards, tech stacks, and build books are scoped to an `org_id`. For a personal deployment you'll have one organization — yours.

**Customization:** Insert your organization name here when first setting up. The app creates one automatically on first signup.

---

### `profiles`
**What it is:** Extended user data attached to Supabase Auth users.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK auth.users UNIQUE | Links to Supabase Auth |
| org_id | UUID FK organizations | Which org this user belongs to |
| display_name | TEXT | User's name shown in UI |
| avatar_url | TEXT | Profile photo URL |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**How it's used:** Created automatically when a user signs up via a Supabase trigger. The `org_id` here determines what standards, tech stacks, and build books the user can see.

---

### `user_roles`
**What it is:** Platform-level role assignments (admin vs regular user).

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| user_id | UUID FK auth.users NOT NULL | |
| role | app_role NOT NULL DEFAULT 'user' | `admin` or `user` |
| created_by | UUID FK auth.users | Who granted the role |
| created_at | TIMESTAMPTZ | |

**How it's used:** Controls access to the admin panel (`VITE_ADMIN_KEY` is the frontend gate; this table is the database-level gate). Admins can manage build books, user accounts, and org-wide settings.

**Customization:** After first signup, insert your user_id into this table with role `admin` via the Supabase SQL editor:
```sql
INSERT INTO user_roles (user_id, role) 
VALUES ('your-user-id-here', 'admin');
```

---

### `project_tokens`
**What it is:** Share tokens that grant external/anonymous access to a project with a specific permission level.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| token | UUID UNIQUE NOT NULL | The actual token value in share URLs |
| role | project_token_role DEFAULT 'viewer' | `owner`, `editor`, or `viewer` |
| created_by | UUID FK auth.users | |
| created_at | TIMESTAMPTZ | |

**How it's used:** When you share a project via "Token Management" in project settings, a row is inserted here. The share URL contains the token UUID. All RLS policies check this table to grant access to anonymous visitors.

---

### `profile_linked_projects`
**What it is:** Tracks which projects a user has accessed via share token.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| profile_id | UUID FK profiles NOT NULL | |
| project_id | UUID FK projects NOT NULL | |
| created_at | TIMESTAMPTZ | |

**How it's used:** When a logged-in user accesses a project via share token, it's recorded here so the project appears in their dashboard as a "linked" project.

---

## Group 2: Projects

### `projects`
**What it is:** The core entity. Every feature in the app hangs off a project.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| name | TEXT NOT NULL | |
| description | TEXT | |
| status | project_status DEFAULT 'DESIGN' | Current phase: DESIGN / AUDIT / BUILD |
| org_id | UUID FK organizations NOT NULL | |
| github_repo | TEXT | Connected GitHub repo name |
| github_branch | TEXT DEFAULT 'main' | Active branch |
| created_by | UUID FK auth.users | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |
| share_token | UUID | Legacy single-token sharing (superseded by project_tokens) |

**How it's used:** Created from the dashboard. Every other table (requirements, canvas, chat, artifacts, etc.) has a `project_id` FK pointing here. The `status` field determines which sidebar tabs are highlighted in the UI.

---

### `published_projects`
**What it is:** Controls which projects appear in the public Gallery.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| share_token | UUID | Public access token |
| is_visible | BOOLEAN DEFAULT true | Show/hide in gallery |
| view_count | INTEGER DEFAULT 0 | How many times it's been viewed |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**How it's used:** When a project owner publishes to the gallery, a row is inserted here. The Gallery page queries this table with `is_visible = true`.

---

## Group 3: Requirements

### `requirements`
**What it is:** The hierarchical requirements tree — the core of the Design phase.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| parent_id | UUID FK requirements | Self-join — null for EPICs |
| type | requirement_type NOT NULL | EPIC / FEATURE / STORY / ACCEPTANCE_CRITERIA |
| title | TEXT NOT NULL | The requirement text |
| content | TEXT | Extended description |
| order_index | INTEGER DEFAULT 0 | Sort order among siblings |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**How it's used:** The Requirements tab renders this as a collapsible tree. AI decomposition (via `decompose-requirements` and `expand-requirement` edge functions) inserts rows here. The hierarchy is: EPIC → FEATURE → STORY → ACCEPTANCE_CRITERIA.

**Relationships:** Requirements can be linked to standards via `requirement_standard_links` (junction table).

---

## Group 4: Standards (Key for Customization)

Standards are the compliance/best-practice library. This is one of the primary areas you want to customize for your own org.

### `standard_categories`
**What it is:** Top-level groupings for standards (e.g., "Security", "Accessibility", "Data Privacy").

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| name | TEXT NOT NULL | Category name |
| description | TEXT | |
| short_description | TEXT | Used in cards/previews |
| long_description | TEXT | Full markdown description |
| org_id | UUID FK organizations | null = system-wide |
| created_by | UUID FK auth.users | |
| is_system | BOOLEAN DEFAULT false | System standards vs org-created |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**Customization:** Insert your own categories here to organize your standards. Example categories you might create: `RHEL 9 Hardening`, `Docker Security`, `.NET Coding Standards`, `API Design`.

---

### `standards`
**What it is:** Individual standards within a category.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| name | TEXT NOT NULL | Standard name |
| description | TEXT | |
| short_description | TEXT | Card preview text |
| long_description | TEXT | Full markdown content |
| category_id | UUID FK standard_categories | Which category it belongs to |
| org_id | UUID FK organizations | null = system-wide |
| created_by | UUID FK auth.users | |
| is_system | BOOLEAN DEFAULT false | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**How it's used:** Standards appear in the global Standards library. They can be linked to projects via `project_standards` and to requirements via `requirement_standard_links`. When an AI agent generates specifications or audits, it uses linked standards as context.

**Customization:** This is where you add your own org standards. Examples:
- "RHEL 9 Baseline Hardening" under a "Infrastructure Security" category
- ".NET C# Coding Conventions" under a "Code Quality" category
- "Postgres Index Strategy" under a "Database Design" category

---

### `standard_resources`
**What it is:** Reference materials attached to a standard or category (links, files, videos).

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| standard_id | UUID FK standards | Attach to specific standard |
| standard_category_id | UUID FK standard_categories | OR attach to category |
| resource_type | resource_type NOT NULL | `file`, `website`, `youtube`, `image` |
| name | TEXT NOT NULL | Display name |
| url | TEXT NOT NULL | Link to the resource |
| description | TEXT | |
| thumbnail_url | TEXT | Preview image |
| order_index | INTEGER DEFAULT 0 | Sort order |
| created_by | UUID FK auth.users | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**How it's used:** Displayed in the Standards library as reference cards under each standard. Supports YouTube embeds, website links, downloadable files, and images.

**Customization:** Add your internal wiki links, documentation URLs, recorded training sessions, etc.

---

### `project_standards`
**What it is:** Junction table linking standards to projects.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| standard_id | UUID FK standards NOT NULL | |
| created_at | TIMESTAMPTZ | |
| UNIQUE | (project_id, standard_id) | No duplicates |

**How it's used:** When you add a standard to a project from the project's Standards tab, a row is inserted here. The AI agents use these linked standards as context when generating specs and audits.

---

## Group 5: Tech Stacks (Key for Customization)

Tech stacks are reusable collections of technologies that can be applied to projects and build books.

### `tech_stacks`
**What it is:** A named technology stack with description and branding.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| org_id | UUID FK organizations NOT NULL | |
| name | TEXT NOT NULL | e.g., ".NET + React + PostgreSQL" |
| description | TEXT | |
| short_description | TEXT | Card preview |
| long_description | TEXT | Full markdown |
| icon | TEXT | Icon identifier or URL |
| color | TEXT | Hex color for UI theming |
| created_by | UUID FK auth.users | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**Customization:** This is the second key area to populate for your own use. Create tech stacks that match your actual development environment:
- `.NET 9 + Next.js + PostgreSQL` (your primary stack)
- `Python FastAPI + React + pgvector` (your AI/ML stack)
- `RHEL 9 + Docker + Nginx` (your infra stack)

---

### `tech_stack_standards`
**What it is:** Junction table linking standards to tech stacks.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| tech_stack_id | UUID FK tech_stacks NOT NULL | |
| standard_id | UUID FK standards NOT NULL | |
| created_at | TIMESTAMPTZ | |
| UNIQUE | (tech_stack_id, standard_id) | |

**How it's used:** Associates relevant standards with a tech stack. Example: linking ".NET Coding Conventions" standard to your ".NET + React" stack so they're automatically suggested when that stack is used.

---

### `tech_stack_resources`
**What it is:** Reference materials attached to a tech stack.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| tech_stack_id | UUID FK tech_stacks NOT NULL | |
| resource_type | resource_type NOT NULL | |
| name | TEXT NOT NULL | |
| url | TEXT NOT NULL | |
| description | TEXT | |
| thumbnail_url | TEXT | |
| order_index | INTEGER DEFAULT 0 | |
| created_by | UUID FK auth.users | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**Customization:** Link official docs, internal wikis, and learning resources to your tech stacks.

---

### `project_tech_stacks`
**What it is:** Junction table linking tech stacks to projects.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| tech_stack_id | UUID FK tech_stacks NOT NULL | |
| created_at | TIMESTAMPTZ | |
| UNIQUE | (project_id, tech_stack_id) | |

**How it's used:** When a project selects a tech stack, it's recorded here. The AI agents reference the tech stack when generating code, architecture diagrams, and specifications.

---

## Group 6: Canvas (Visual Architecture)

### `canvas_nodes`
**What it is:** Individual blocks on the React Flow architecture diagram.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| canvas_id | UUID nullable | Future multi-canvas support |
| type | node_type NOT NULL | What kind of block (API, DATABASE, SERVICE, etc.) |
| position | JSONB DEFAULT '{"x":0,"y":0}' | X/Y coordinates on canvas |
| data | JSONB DEFAULT '{}' | Label, color, metadata, connections |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**How it's used:** Every block you place on the Canvas tab creates a row here. The `data` JSON contains the node's label, description, color, and any custom properties. AI architect generates nodes automatically from project context.

---

### `canvas_edges`
**What it is:** Connections between canvas nodes.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| source_id | UUID FK canvas_nodes NOT NULL | The starting node |
| target_id | UUID FK canvas_nodes NOT NULL | The ending node |
| canvas_id | UUID nullable | |
| label | TEXT | Edge label (e.g., "REST API", "reads from") |
| created_at | TIMESTAMPTZ | |

**How it's used:** Drawing a connection between two nodes on the canvas creates a row here. Edges represent data flows, API calls, dependencies.

---

### `canvas_layers`
**What it is:** Named groupings of nodes on the canvas for organization.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| canvas_id | UUID nullable | |
| name | TEXT NOT NULL | Layer name (e.g., "Frontend", "Backend", "Infrastructure") |
| node_ids | TEXT[] DEFAULT '{}' | Array of node IDs in this layer |
| visible | BOOLEAN DEFAULT true | Toggle layer visibility |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

---

## Group 7: Repositories & Files

### `project_repos`
**What it is:** GitHub repository connections for a project.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| organization | TEXT NOT NULL | GitHub org or username |
| repo | TEXT NOT NULL | Repository name |
| branch | TEXT DEFAULT 'main' | Active branch |
| is_default | BOOLEAN DEFAULT false | |
| is_prime | BOOLEAN DEFAULT false | Primary repo for the project |
| auto_commit | BOOLEAN DEFAULT false | Auto-commit agent changes |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**How it's used:** Connecting a GitHub repo via the Repository tab creates a row here. The `sync-repo-push` and `sync-repo-pull` edge functions use this to know where to push/pull.

---

### `repo_files`
**What it is:** Local cache of files pulled from GitHub.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| repo_id | UUID FK project_repos NOT NULL | |
| path | TEXT NOT NULL | File path relative to repo root |
| content | TEXT NOT NULL | Full file content |
| last_commit_sha | TEXT | SHA of the commit this was pulled from |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |
| UNIQUE | (repo_id, path) | |

**How it's used:** When you pull a repo, files are stored here. The Repository tab reads from this table. The coding agent reads and writes files through this table before staging/committing.

---

### `repo_staging`
**What it is:** Uncommitted changes — the staging area before a commit.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| repo_id | UUID FK project_repos NOT NULL | |
| project_id | UUID FK projects NOT NULL | |
| operation_type | TEXT CHECK ('add','edit','delete','rename') | What kind of change |
| file_path | TEXT NOT NULL | File being changed |
| old_content | TEXT | Previous content (for edits) |
| new_content | TEXT | New content |
| old_path | TEXT | For renames — original path |
| created_at | TIMESTAMPTZ | |
| created_by | UUID | |
| UNIQUE | (repo_id, file_path) | Only one staged change per file |

**How it's used:** When the coding agent edits a file, the change goes here first. The "Stage" and "Commit" UI in the Build tab reads from this table.

---

### `repo_commits`
**What it is:** Commit history for all pushes made through Pronghorn.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| repo_id | UUID FK project_repos NOT NULL | |
| project_id | UUID FK projects NOT NULL | |
| branch | TEXT NOT NULL | |
| commit_sha | TEXT NOT NULL | GitHub commit SHA |
| commit_message | TEXT NOT NULL | |
| files_changed | INTEGER DEFAULT 0 | |
| files_metadata | JSONB DEFAULT '[]' | Array of changed file details |
| parent_commit_id | UUID FK repo_commits | Self-join for commit chain |
| committed_by | UUID FK auth.users | |
| committed_at | TIMESTAMPTZ | |
| created_at | TIMESTAMPTZ | |

---

## Group 8: AI Agent System

### `agent_sessions`
**What it is:** A single autonomous coding agent run.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| status | TEXT DEFAULT 'running' | `running`, `paused`, `completed`, `error` |
| mode | TEXT | `task`, `iterative_loop`, `continuous_improvement` |
| task_description | TEXT | What the agent was asked to do |
| abort_requested | BOOLEAN DEFAULT false | Set to true to stop the agent |
| started_at | TIMESTAMPTZ | |
| completed_at | TIMESTAMPTZ | |
| created_by | UUID FK auth.users | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**How it's used:** Each time you run the coding agent in the Build tab, a session row is created. The monitoring UI polls this table for status updates.

---

### `agent_messages`
**What it is:** The conversation history of an agent session — what the agent said and did.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| session_id | UUID FK agent_sessions NOT NULL | |
| role | TEXT CHECK ('user','agent','system') | |
| content | TEXT NOT NULL | Message content |
| metadata | JSONB DEFAULT '{}' | Tool calls, file operations, etc. |
| created_at | TIMESTAMPTZ | |

---

### `agent_blackboard`
**What it is:** The agent's working memory and reasoning log during a session.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| session_id | UUID FK agent_sessions NOT NULL | |
| entry_type | TEXT | `planning`, `progress`, `decision`, `reasoning`, `next_steps`, `reflection` |
| content | TEXT NOT NULL | The agent's thought/observation |
| metadata | JSONB DEFAULT '{}' | |
| created_at | TIMESTAMPTZ | |

**How it's used:** The agent writes its reasoning, plans, and reflections here as it works. Displayed in the Build tab's agent timeline. Provides transparency into what the agent is thinking.

---

### `agent_file_operations`
**What it is:** Log of every file read/write/delete the agent performed.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| session_id | UUID FK agent_sessions NOT NULL | |
| operation_type | TEXT NOT NULL | `read`, `write`, `delete`, `rename` |
| file_path | TEXT | |
| status | TEXT DEFAULT 'pending' | |
| details | JSONB DEFAULT '{}' | |
| error_message | TEXT | |
| created_at | TIMESTAMPTZ | |
| completed_at | TIMESTAMPTZ | |

---

### `agent_llm_logs`
**What it is:** Token usage and model metadata for each LLM call made by the agent.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| session_id | UUID FK agent_sessions NOT NULL | |
| message_index | INTEGER | Order in the conversation |
| tokens_used | INTEGER | Token consumption for billing awareness |
| model | TEXT | Which LLM model was called |
| metadata | JSONB | Raw response metadata |
| parse_status | TEXT | Whether the response parsed successfully |
| created_at | TIMESTAMPTZ | |

---

## Group 9: Chat

### `chat_sessions`
**What it is:** A named conversation thread with the AI.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| title | TEXT DEFAULT 'New Chat' | |
| ai_title | TEXT | AI-generated summary title |
| ai_summary | TEXT | AI-generated session summary |
| created_by | UUID FK auth.users | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

---

### `chat_messages`
**What it is:** Individual messages in a chat session.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| chat_session_id | UUID FK chat_sessions NOT NULL | |
| project_id | UUID FK projects | Denormalized for query performance |
| role | TEXT CHECK ('user','assistant','system') | |
| content | TEXT NOT NULL | |
| metadata | JSONB DEFAULT '{}' | Model info, tokens, citations |
| created_at | TIMESTAMPTZ | |

---

## Group 10: Artifacts

### `artifacts`
**What it is:** Stored documents, code snippets, generated outputs, and uploaded files.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| content | TEXT NOT NULL | The artifact content (text, code, markdown) |
| ai_title | TEXT | AI-generated title |
| ai_summary | TEXT | AI-generated summary |
| image_url | TEXT | For image artifacts stored in Supabase Storage |
| source_type | TEXT | `pdf`, `docx`, `xlsx`, `image`, `generated`, etc. |
| source_id | UUID | Reference to originating entity if auto-generated |
| is_published | BOOLEAN DEFAULT false | Whether it's publicly accessible |
| created_by | UUID FK auth.users | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**How it's used:** Anything you upload (PDF, DOCX, Excel) or the AI generates (specifications, summaries) creates an artifact. Published artifacts are served by the `serve-artifact` edge function.

---

## Group 11: Collaboration

### `artifact_collaborations`
**What it is:** A real-time co-editing session on an artifact.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| artifact_id | UUID FK artifacts NOT NULL | Which artifact is being edited |
| title | TEXT | Session title |
| status | TEXT DEFAULT 'active' | `active`, `completed`, `merged` |
| current_content | TEXT NOT NULL | Live version of the document |
| base_content | TEXT NOT NULL | Starting version before edits |
| created_by | UUID FK auth.users | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |
| merged_at | TIMESTAMPTZ | When finalized |
| merged_to_artifact | BOOLEAN DEFAULT false | Whether it's been saved back |

---

### `artifact_collaboration_history`
**What it is:** Full version history of every edit made during a collaboration session.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| collaboration_id | UUID FK artifact_collaborations NOT NULL | |
| version_number | INTEGER NOT NULL | Sequential, unique per collaboration |
| actor_type | TEXT CHECK ('human','agent') | Who made the edit |
| actor_identifier | TEXT | Username or agent name |
| operation_type | TEXT CHECK ('edit','insert','delete','replace') | |
| start_line | INTEGER | Line range affected |
| end_line | INTEGER | |
| old_content | TEXT | What was there before |
| new_content | TEXT | What replaced it |
| full_content_snapshot | TEXT | Full document at this version |
| narrative | TEXT | Human-readable description of the change |
| created_at | TIMESTAMPTZ | |

---

## Group 12: Audit System

### `audit_sessions`
**What it is:** A multi-agent audit run on a project.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| status | TEXT | Overall audit status |
| phase | TEXT | Which audit phase is active |
| consensus_state | TEXT | Whether agents have reached consensus |
| created_by | UUID FK auth.users | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

---

### `audit_tesseract_cells`
**What it is:** The 3D evidence grid output of an audit.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| session_id | UUID FK audit_sessions | |
| cell_position | TEXT | 3D grid coordinate |
| cell_type | TEXT | Type of evidence |
| content | TEXT | The evidence content |
| created_at | TIMESTAMPTZ | |

---

### `audit_graph_nodes` / `audit_graph_edges`
**What it is:** Knowledge graph output — nodes and connections found during audit.

Used to render the knowledge graph visualization in the Audit tab.

---

### `audit_blackboard`
**What it is:** Agent reasoning log during the audit — same pattern as `agent_blackboard`.

---

## Group 13: Databases & Deployments

### `project_databases`
**What it is:** Managed database instances provisioned for a project (via Render.com or Supabase).

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| database_name | TEXT NOT NULL | |
| provider | database_provider | `render_postgres` or `supabase` |
| plan | database_plan | Size/tier |
| status | database_status | Current state |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

---

### `project_database_connections`
**What it is:** Encrypted connection credentials for a project database.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| database_id | UUID FK project_databases | |
| connection_string | TEXT | Full connection URL |
| host | TEXT | |
| port | INTEGER | |
| username | TEXT | |
| password | TEXT | Stored encrypted |
| status | TEXT | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

---

### `project_deployments`
**What it is:** Deployment targets for a project's services.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL | |
| environment | deployment_environment | `development`, `staging`, `production` |
| platform | deployment_platform | `pronghorn_cloud`, `local`, `dedicated_vm` |
| status | deployment_status | Current state |
| url | TEXT | Live URL once deployed |
| disk_enabled | BOOLEAN DEFAULT false | Persistent disk |
| disk_mount_path | TEXT DEFAULT '/data' | |
| disk_name | TEXT | |
| disk_size_gb | INTEGER DEFAULT 1 | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

---

## Group 14: Build Books (Key for Customization)

Build Books are curated project templates that bundle together a tech stack, standards, and guidance.

### `build_books`
**What it is:** A named template that combines a tech stack with relevant standards and documentation.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| name | TEXT NOT NULL | e.g., ".NET + React Fullstack Starter" |
| short_description | TEXT | Card preview |
| long_description | TEXT | Full markdown description |
| cover_image_url | TEXT | Card thumbnail |
| tags | TEXT[] DEFAULT '{}' | Searchable tags |
| org_id | UUID FK organizations | Which org owns it |
| is_published | BOOLEAN DEFAULT false | Visible in gallery |
| deploy_count | INTEGER DEFAULT 0 | How many times cloned |
| created_by | UUID FK auth.users | |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

**Customization:** Create build books for your common project types. Examples:
- `.NET API + Next.js Frontend` — your standard fullstack template
- `Python FastAPI + pgvector RAG Service` — your AI/ML service template
- `RHEL 9 + Docker Infrastructure Project` — your infra template

Each build book links to tech stacks and standard categories, so when someone creates a project from it, they get pre-loaded standards and stack context for the AI agents.

---

### `build_book_standards` / `build_book_tech_stacks`
**What they are:** Junction tables linking build books to standard categories and tech stacks.

| Column | Type | Notes |
|--------|------|-------|
| build_book_id | UUID FK build_books | |
| standard_category_id | UUID FK standard_categories | OR tech_stack_id |
| created_at | TIMESTAMPTZ | |

---

## Group 15: Specifications

### `project_specifications`
**What it is:** AI-generated specification document for a project.

| Column | Type | Notes |
|--------|------|-------|
| id | UUID PK | |
| project_id | UUID FK projects NOT NULL UNIQUE | One spec per project |
| generated_spec | TEXT NOT NULL | Full specification markdown |
| raw_data | JSONB | Structured data used to generate the spec |
| agent_id | TEXT | Which spec agent generated it |
| agent_title | TEXT | |
| generated_by_token | UUID | If generated via share token |
| created_at | TIMESTAMPTZ | |
| updated_at | TIMESTAMPTZ | |

---

## Relationship Map

```
organizations
    └── profiles (users)
    └── projects
            ├── requirements (tree: EPIC→FEATURE→STORY→AC)
            ├── project_standards ──→ standards ──→ standard_categories
            ├── project_tech_stacks ──→ tech_stacks
            ├── canvas_nodes + canvas_edges (architecture diagram)
            ├── project_repos
            │       ├── repo_files
            │       ├── repo_staging
            │       └── repo_commits
            ├── agent_sessions
            │       ├── agent_messages
            │       ├── agent_blackboard
            │       └── agent_file_operations
            ├── chat_sessions
            │       └── chat_messages
            ├── artifacts
            │       └── artifact_collaborations
            │               └── artifact_collaboration_history
            ├── audit_sessions
            │       ├── audit_tesseract_cells
            │       ├── audit_graph_nodes/edges
            │       └── audit_blackboard
            ├── project_databases
            │       └── project_database_connections
            ├── project_deployments
            │       └── deployment_logs
            └── project_specifications

build_books ──→ build_book_tech_stacks ──→ tech_stacks
            └── build_book_standards ──→ standard_categories
```

---

## Customization Priority Order

For your homelab deployment, populate these tables first:

1. **`organizations`** — Your org (auto-created on first signup)
2. **`user_roles`** — Make yourself admin
3. **`standard_categories`** — Your compliance/standards groupings
4. **`standards`** — Your actual standards under each category
5. **`standard_resources`** — Links to your docs, wikis, references
6. **`tech_stacks`** — Your named tech stacks (.NET, Python, etc.)
7. **`tech_stack_standards`** — Link relevant standards to each stack
8. **`build_books`** — Your project templates
9. **`build_book_tech_stacks`** + **`build_book_standards`** — Link stacks and standards to templates

Once these are populated, every new project you create will have access to your org's standards and tech stacks, and the AI agents will use them as context when generating architecture diagrams, code, and specifications.


The user doesn't want to proceed with this tool use. The tool use was rejected (eg. if it was a file edit, the new_string was NOT written to the file). STOP what you are doing and wait for the user to tell you how to proceed.

Note: The user's next message may contain a correction or preference. Pay close attention — if they explain what went wrong or how they'd prefer you to work, consider saving that to memory for future sessions.