# Blog Roadmap

Simple blog built with Phoenix 1.8 (HTML + Ecto, no LiveView for pages), PostgreSQL in Docker, Markdown rendering.

## Current state

- **Phoenix 1.8.16 skeleton** at this directory (Elixir 1.19.7, Erlang/OTP 26)
- **PostgreSQL 16 in Docker** (`docker-compose.yaml`, port `15432`, pgAdmin on `:5050`); healthcheck fixed
- **DB config is env-driven**: `dotenvy` reads `.env` in `config/runtime.exs`; `.env` is shared between Phoenix and docker-compose (dev + test verified)
- **git**: initialized, identity configured, initial commit `05577a4` (skeleton + docker-compose); `.env`, `pgsql/`, `pgadmin-data/` are gitignored
- Stack details: daisyUI 5 (light + dark themes) + heroicons via Tailwind v4 plugins; `mix precommit` alias available (compile warnings-as-errors, format, test)
- **Site identity**: configurable `BLOG_NAME` environment variable (default `Blog`); reading-time estimate helper

## Phase 1 — MVP: posts with Markdown

Goal: a working blog — create, read, update, delete posts.

1. ✅ ~~**Dependency**: `mdex` (Comrak-based GitHub-Flavored Markdown; raw HTML in user content is filtered by default → XSS-safe). Fallback if NIF fails to load: `earmark` + `html_sanitize_ex`~~
2. ✅ ~~**Generate**: `mix phx.gen.html Blog Post posts title:string body:text`~~
   - ✅ ~~Adjust generated templates to our style (daisyUI classes)~~
3. ✅ ~~**Schema validations**: `title` required (1–200 chars), `body` required (1–50 000 chars)~~
4. ✅ ~~**Markdown rendering**: helper `markdown_to_html/1` in `BlogWeb` + custom typography styles (`.markdown-content`: headings, lists, quotes, code blocks) in `assets/css/app.css`~~
5. ✅ ~~**Routing**: root `/` → posts index (replace Phoenix welcome page)~~
6. ✅ ~~**Seeds**: 2–3 demo posts exercising Markdown (headings, lists, code block)~~
7. ✅ ~~**Tests + `mix precommit`** → commit 📌~~

## Phase 2 — Polish

- ✅ ~~Index: newest first, body preview (~200 chars), human-readable dates, empty state («no posts yet»)~~
- ✅ ~~Show: rendered Markdown, Back / Edit / Delete actions~~
- ✅ ~~UI polish with Tailwind/daisyUI: cards, hover effects, transitions; check both light and dark themes~~ (theme colors via CSS variables work in both themes)
- ✅ ~~Commit 📌~~

## Phase 3 — Comments

- ✅ ~~`Comment` schema: `belongs_to :post`, `author` (optional string), `body`~~
- ✅ ~~Nested routes `/posts/:post_id/comments`; comment form on post show page~~
- ✅ ~~Validations, seeds, tests → commit 📌~~

## Phase 4 — Authentication

- ✅ ~~`mix phx.gen.auth` (email + password, HTML, `--no-live`, bcrypt)~~
- ✅ ~~`Post belongs_to :user`; only the author can edit/delete their posts (scope-based authorization)~~
- ✅ ~~Comments tied to users: login required to comment; comment may be deleted by its author, the post author or an admin~~
- ✅ ~~`User.role` (`user`/`admin`); admin can edit/delete any post and delete any comment~~
- ✅ ~~Seeds: admin + demo users; legacy posts backfilled to the demo user~~
- ✅ ~~Tests + `mix precommit` → commit 📌~~

## Phase 5 — Release & deployment (later)

- `mix phx.gen.release`, `mix assets.deploy`
- Secrets via environment variables (already env-driven in `runtime.exs`)
- Deploy target: TBD (Fly.io / VPS + Docker)

## Phase 6 — Editorial redesign

- ✅ ~~Warm paper-and-ink light theme and matching charcoal dark theme~~
- ✅ ~~Editorial header, responsive navigation, theme control, and footer~~
- ✅ ~~Single-column story feed with author, date, reading time, excerpt, and article link~~
- ✅ ~~Article typography, Markdown styling, discussion, and comment form~~
- ✅ ~~Publishing, editing, login, and registration pages redesigned; authorization and roles retained~~
- ✅ ~~Refresh UI expectations and pass `mix precommit` (156 tests) → commit 📌~~

## Decisions

| Question | Decision |
| --- | --- |
| Body format | Markdown (rendered with mdex) |
| Comments | Separate phase (after posts polish) |
| Post URLs | Numeric IDs (`/posts/42`) — slugs can be added later |
| Database | PostgreSQL in Docker (user-provided `docker-compose.yaml`) |
| Frontend | Server-rendered HTML (controllers + HEEx), no LiveView for pages |
| Posts context | `Blog.Posts` (context name `Blog` conflicts with the app module) |
| Auth stack | `mix phx.gen.auth Accounts User users --no-live --hashing-lib bcrypt` (scope-based, `@current_scope`) |
| Roles | `User.role` string (`user`/`admin`), assigned only in seeds/console; admins manage all posts & comments |
| Comments & auth | Login required to comment; delete allowed for comment author, post author, admin |
| Site name | `BLOG_NAME` environment variable, default `Blog`; restart required after changing it |
