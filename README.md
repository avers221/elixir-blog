# Blog

Phoenix blog with PostgreSQL, Markdown posts, comments, and account roles.

## Operations

`Makefile` contains the production operations interface. The application runs as
an Elixir release managed by a per-user `systemd` service; Docker Compose runs
PostgreSQL only. A reverse proxy is not included and must terminate HTTPS and
forward requests to `127.0.0.1:4000`.

### First-time setup on a Linux host

Requirements: Docker Engine with the Compose plugin, Elixir/Mix and the
project's supported Erlang/Elixir versions, `systemd --user`, `curl`, `make`,
and PostgreSQL client tools in the PostgreSQL container (included in its image).
Build the release on the same OS/architecture as the target host.

1. Copy `.env.example` to `.env` and set the production values. Generate secrets,
   for example:

   ```sh
   openssl rand -hex 32  # DB_PASSWORD
   mix phx.gen.secret    # SECRET_KEY_BASE
   ```

   Set `PHX_HOST` to the public hostname. Keep `PHX_LISTEN_IP=127.0.0.1` when
   the reverse proxy runs on the same host. Use a long, URL-safe database
   password, such as the hex output above.

2. Enable the user service to survive logout (one-time host setup; may require
   administrator privileges):

   ```sh
   sudo loginctl enable-linger "$USER"
   ```

3. From the project directory run:

   ```sh
   make check
   make install
   ```

`make install` starts PostgreSQL, builds the production assets and release,
runs migrations, installs `blog.service` under `systemd --user`, and verifies
`/health`. It does not seed demo accounts or change user roles.

Production email delivery is not configured in this repository yet. Before
relying on registration, sign-in links, or email changes on a public server,
configure a real Swoosh mail adapter and its credentials in `config/runtime.exs`.

### Common operations

```sh
make start
make stop
make restart
make status
make health
make logs                  # app logs
make logs SERVICE=postgres # database logs
make update
make migrate
```

`make update` builds into a staging directory, takes a database backup, runs
migrations, activates the release and checks health. Previous release files are
retained under `_build/prod/rel/`; database migrations are not automatically
rolled back. Review migration compatibility before deploying schema changes.

Grant/revoke administrator access for an existing account:

```sh
make admin-grant EMAIL=owner@example.com
make admin-revoke EMAIL=owner@example.com
```

### Backups and restore

```sh
make backup
make backups
make backup-check FILE=backups/blog-YYYYMMDDTHHMMSSZ.dump
make restore CONFIRM=restore FILE=backups/blog-YYYYMMDDTHHMMSSZ.dump
make backup-prune CONFIRM=prune KEEP_DAYS=30
```

Backups are compressed PostgreSQL logical dumps in `backups/`, ignored by Git,
with restrictive file permissions. Restore overwrites the configured database
and makes a safety backup first. Keep copies off-host as well: local backups do
not protect against loss of the server or its disk. Schedule `make backup` with
a host timer/cron and arrange off-site copying separately.

## Development

For local development, configure `.env` with local database settings and run
`make dev`. It starts the PostgreSQL Compose service, waits for the database,
runs pending development migrations, then starts Phoenix with `mix phx.server`
in the foreground. Press `Ctrl+C` in that terminal to stop Phoenix, then run
`make dev-stop` to stop PostgreSQL. Use `make start`/`make stop` only for the
installed production release managed by `systemd --user`.

On a fresh checkout, create `priv/repo/seeds.credentials.json` before running
`mix setup` (which runs the seed script). The file is intentionally gitignored.
It must contain a non-empty JSON array of objects with `email`, `password`, and
`role` fields. Passwords must be 12–72 bytes; valid roles are `user` and
`admin`. Include at least one admin and one regular user because the seed script
uses them for demo comments and posts. Each time the seeds run, configured
passwords and roles are applied to these accounts. For example, use your own
local-only test values:

```json
[
  {"email": "admin@example.com", "password": "<local-test-password>", "role": "admin"},
  {"email": "demo@example.com", "password": "<another-local-test-password>", "role": "user"}
]
```

Do not put production credentials in the seed file. The seed script fails with
a clear error if the file is missing or invalid. For local database commands
and other Mix tasks, see `mix help`.
