SHELL := /bin/bash
.SHELLFLAGS := -eu -o pipefail -c
.DEFAULT_GOAL := help
.PHONY: help check install start stop restart status health logs update migrate backup backups backup-check restore backup-prune admin-grant admin-revoke _require-env _build-release _activate-release _wait-db _install-service _ensure-backup-dir _admin-action

COMPOSE ?= docker compose
COMPOSE_FILE ?= docker-compose.yaml
ENV_FILE ?= .env
RELEASE_DIR ?= _build/prod/rel/blog
STAGING_DIR ?= _build/prod/rel/blog.staging
SERVICE_NAME ?= blog.service
BACKUP_DIR ?= backups
BACKUP_KEEP_DAYS ?= 30
APP_URL ?= http://127.0.0.1:4000

help: ## Show available operational commands
	@awk 'BEGIN {FS = ":.*##"; print "Blog operations\n"} /^[a-zA-Z0-9_-]+:.*##/ {printf "  make %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check: ## Check required tools and deployment configuration
	@command -v docker >/dev/null || { echo "Missing required command: docker" >&2; exit 1; }
	@command -v mix >/dev/null || { echo "Missing required command: mix (needed to build/update releases)" >&2; exit 1; }
	@command -v curl >/dev/null || { echo "Missing required command: curl" >&2; exit 1; }
	@command -v systemctl >/dev/null || { echo "Missing required command: systemctl" >&2; exit 1; }
	@test -f "$(COMPOSE_FILE)" || { echo "Missing $(COMPOSE_FILE)" >&2; exit 1; }
	@test -f "$(ENV_FILE)" || { echo "Missing $(ENV_FILE); copy .env.example and set production values" >&2; exit 1; }
	@for name in DB_DATABASE DB_USERNAME DB_PASSWORD DB_HOSTNAME DB_PORT SECRET_KEY_BASE PHX_HOST; do \
	  if ! grep -Eq "^$$name=.+$$" "$(ENV_FILE)"; then echo "Missing required variable $$name in $(ENV_FILE)" >&2; exit 1; fi; \
	done
	@if grep -q '^SECRET_KEY_BASE=replace-with-output-from-mix-phx-gen-secret$$' "$(ENV_FILE)"; then \
	  echo "SECRET_KEY_BASE is still the example placeholder; generate one with mix phx.gen.secret" >&2; exit 1; \
	fi
	@if grep -q '^DB_PASSWORD=replace-with-a-long-random-password$$' "$(ENV_FILE)"; then \
	  echo "DB_PASSWORD is still the example placeholder; set a long random password" >&2; exit 1; \
	fi
	@if grep -q '^PHX_HOST=example.com$$' "$(ENV_FILE)"; then \
	  echo "Set PHX_HOST to the public hostname before installing" >&2; exit 1; \
	fi
	@secret="$$(sed -n 's/^SECRET_KEY_BASE=//p' "$(ENV_FILE)" | tail -n 1)"; \
	  if [[ "$${secret}" != "replace-with-output-from-mix-phx-gen-secret" && $${#secret} -lt 64 ]]; then echo "SECRET_KEY_BASE must be at least 64 characters" >&2; exit 1; fi
	@$(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" config --quiet
	@echo "Configuration and required commands look good."

install: check ## First-time setup: start PostgreSQL, build release, migrate, install and start systemd user service
	@mkdir -p "$(BACKUP_DIR)"
	@$(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" up -d postgres
	@$(MAKE) --no-print-directory _wait-db
	@$(MAKE) --no-print-directory _build-release
	@$(MAKE) --no-print-directory migrate RELEASE_PATH="$(STAGING_DIR)"
	@systemctl --user stop "$(SERVICE_NAME)" >/dev/null 2>&1 || true
	@$(MAKE) --no-print-directory _activate-release
	@$(MAKE) --no-print-directory _install-service
	@systemctl --user enable --now "$(SERVICE_NAME)"
	@$(MAKE) --no-print-directory health

start: ## Start database and application service
	@$(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" up -d postgres
	@$(MAKE) --no-print-directory _wait-db
	@systemctl --user start "$(SERVICE_NAME)"

stop: ## Stop application and database without deleting data
	@systemctl --user stop "$(SERVICE_NAME)" >/dev/null 2>&1 || true
	@$(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" stop postgres

restart: ## Restart the application service
	@systemctl --user restart "$(SERVICE_NAME)"

status: ## Show application and database service status
	@systemctl --user --no-pager --full status "$(SERVICE_NAME)" || true
	@$(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" ps

health: ## Check HTTP app and database readiness via /health
	@curl --fail --silent --show-error --max-time 8 "$(APP_URL)/health" || { echo "Health check failed at $(APP_URL)/health" >&2; exit 1; }

logs: ## Follow service logs (SERVICE=blog.service or SERVICE=postgres)
	@if [[ "$(SERVICE)" == "postgres" ]]; then \
	  $(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" logs --tail=100 --follow postgres; \
	else \
	  journalctl --user -u "$(SERVICE_NAME)" --since "$(or $(SINCE),1 hour ago)" --no-pager -f; \
	fi

update: check ## Build update, back up database, migrate, restart and verify health
	@$(MAKE) --no-print-directory _wait-db
	@$(MAKE) --no-print-directory _build-release
	@$(MAKE) --no-print-directory backup
	@systemctl --user stop "$(SERVICE_NAME)"
	@$(MAKE) --no-print-directory migrate RELEASE_PATH="$(STAGING_DIR)" || { \
	  echo "Migration failed; restarting the existing application." >&2; \
	  systemctl --user start "$(SERVICE_NAME)"; exit 1; \
	}
	@$(MAKE) --no-print-directory _activate-release
	@systemctl --user restart "$(SERVICE_NAME)"
	@$(MAKE) --no-print-directory health

migrate: ## Apply pending migrations from the current release
	@test -x "$(or $(RELEASE_PATH),$(RELEASE_DIR))/bin/blog" || { echo "Release missing; run make install or make update first" >&2; exit 1; }
	@$(MAKE) --no-print-directory _wait-db
	@mkdir -p tmp/release
	@RELEASE_TMP="$$(pwd)/tmp/release" "$(or $(RELEASE_PATH),$(RELEASE_DIR))/bin/blog" eval 'Blog.ReleaseTasks.migrate()'

backup: _require-env _ensure-backup-dir ## Create a compressed PostgreSQL logical backup
	@$(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" up -d postgres
	@$(MAKE) --no-print-directory _wait-db
	@umask 077; \
	  stamp="$$(date -u +%Y%m%dT%H%M%SZ)-$$$$"; \
	  file="$(BACKUP_DIR)/blog-$${stamp}.dump"; \
	  tmp="$${file}.partial"; \
	  trap 'rm -f "$$tmp"' EXIT; \
	  $(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" exec -T postgres \
	    sh -c 'pg_dump -Fc -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"' > "$$tmp"; \
	  $(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" exec -T postgres pg_restore --list - < "$$tmp" >/dev/null; \
	  mv "$$tmp" "$$file"; \
	  chmod 600 "$$file"; \
	  echo "Backup created: $$file"

backups: ## List logical database backups
	@mkdir -p "$(BACKUP_DIR)"
	@find "$(BACKUP_DIR)" -maxdepth 1 -type f -name 'blog-*.dump' -printf '%TY-%Tm-%Td %TH:%TM  %p (%s bytes)\n' | sort -r

backup-check: ## Validate a backup archive (FILE=backups/blog-....dump)
	@test -n "$(FILE)" || { echo "Usage: make backup-check FILE=path/to/archive.dump" >&2; exit 1; }
	@test -f "$(FILE)" || { echo "Backup not found: $(FILE)" >&2; exit 1; }
	@$(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" up -d postgres
	@$(MAKE) --no-print-directory _wait-db
	@$(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" exec -T postgres pg_restore --list - < "$(FILE)" >/dev/null
	@echo "Archive is readable: $(FILE)"

restore: _require-env ## Destructively restore an archive (requires CONFIRM=restore and FILE=...)
	@test "$(CONFIRM)" = restore || { echo "Refusing restore. Re-run with CONFIRM=restore FILE=..." >&2; exit 1; }
	@test -n "$(FILE)" -a -f "$(FILE)" || { echo "Usage: make restore CONFIRM=restore FILE=path/to/archive.dump" >&2; exit 1; }
	@systemctl --user cat "$(SERVICE_NAME)" >/dev/null || { echo "Application service is not installed; refusing database restore" >&2; exit 1; }
	@$(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" up -d postgres
	@$(MAKE) --no-print-directory _wait-db
	@$(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" exec -T postgres pg_restore --list - < "$(FILE)" >/dev/null
	@systemctl --user stop "$(SERVICE_NAME)"; \
	  restart_service() { systemctl --user start "$(SERVICE_NAME)" >/dev/null 2>&1 || true; }; \
	  trap restart_service EXIT; \
	  $(MAKE) --no-print-directory backup; \
	  $(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" exec -T postgres \
	    sh -c 'pg_restore --clean --if-exists --no-owner --no-privileges -U "$$POSTGRES_USER" -d "$$POSTGRES_DB"' < "$(FILE)"; \
	  systemctl --user start "$(SERVICE_NAME)"; \
	  trap - EXIT
	@$(MAKE) --no-print-directory health

backup-prune: _require-env ## Delete old backups (requires CONFIRM=prune; KEEP_DAYS defaults to 30)
	@test "$(CONFIRM)" = prune || { echo "Refusing deletion. Re-run with CONFIRM=prune" >&2; exit 1; }
	@[[ "$(or $(KEEP_DAYS),$(BACKUP_KEEP_DAYS))" =~ ^[0-9]+$$ ]] || { echo "KEEP_DAYS must be a non-negative integer" >&2; exit 1; }
	@find "$(BACKUP_DIR)" -maxdepth 1 -type f -name 'blog-*.dump' -mtime +"$(or $(KEEP_DAYS),$(BACKUP_KEEP_DAYS))" -print -delete

admin-grant: ## Grant admin role to existing account (EMAIL=...)
	@test -n "$(EMAIL)" || { echo "Usage: make admin-grant EMAIL=owner@example.com" >&2; exit 1; }
	@[[ "$(EMAIL)" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$$ ]] || { echo "Invalid email address" >&2; exit 1; }
	@$(MAKE) --no-print-directory _admin-action ACTION=grant EMAIL="$(EMAIL)"

admin-revoke: ## Revoke admin role from existing account (EMAIL=...)
	@test -n "$(EMAIL)" || { echo "Usage: make admin-revoke EMAIL=owner@example.com" >&2; exit 1; }
	@[[ "$(EMAIL)" =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$$ ]] || { echo "Invalid email address" >&2; exit 1; }
	@$(MAKE) --no-print-directory _admin-action ACTION=revoke EMAIL="$(EMAIL)"

_admin-action: _require-env
	@test -x "$(RELEASE_DIR)/bin/blog" || { echo "Release missing; run make install or make update first" >&2; exit 1; }
	@mkdir -p tmp/release
	@$(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" up -d postgres
	@$(MAKE) --no-print-directory _wait-db
	@BLOG_ADMIN_EMAIL="$(EMAIL)" RELEASE_TMP="$$(pwd)/tmp/release" \
	  "$(RELEASE_DIR)/bin/blog" eval 'Blog.ReleaseTasks.admin_$(ACTION)(System.fetch_env!("BLOG_ADMIN_EMAIL"))'

_wait-db: _require-env
	@$(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" up -d postgres
	@for attempt in $$(seq 1 30); do \
	  if $(COMPOSE) --env-file "$(ENV_FILE)" -f "$(COMPOSE_FILE)" exec -T postgres sh -c 'pg_isready -U "$${POSTGRES_USER}" -d "$${POSTGRES_DB}"' >/dev/null 2>&1; then \
	    echo "PostgreSQL is ready."; exit 0; \
	  fi; \
	  sleep 2; \
	done; \
	echo "PostgreSQL did not become ready in 60 seconds." >&2; exit 1

_build-release: _require-env
	@export MIX_ENV=prod PHX_SERVER=true; \
	  mix deps.get --only prod; \
	  mix assets.setup; \
	  mix assets.deploy; \
	  mix release --overwrite --path "$(STAGING_DIR)"

_activate-release:
	@test -x "$(STAGING_DIR)/bin/blog" || { echo "Staging release is missing" >&2; exit 1; }
	@if [[ -d "$(RELEASE_DIR)" ]]; then \
	  previous="$(RELEASE_DIR).previous-$$(date -u +%Y%m%dT%H%M%SZ)"; \
	  mv "$(RELEASE_DIR)" "$$previous"; \
	  echo "Previous release retained at $$previous"; \
	fi
	@mv "$(STAGING_DIR)" "$(RELEASE_DIR)"

_install-service:
	@mkdir -p "$(HOME)/.config/systemd/user" tmp/release
	@umask 077; \
	  { \
	    echo '[Unit]'; \
	    echo 'Description=Phoenix blog application'; \
	    echo 'After=network-online.target'; \
	    echo ''; \
	    echo '[Service]'; \
	    echo 'Type=simple'; \
	    echo 'WorkingDirectory=$(CURDIR)'; \
	    echo 'EnvironmentFile=$(CURDIR)/$(ENV_FILE)'; \
	    echo 'Environment=RELEASE_TMP=$(CURDIR)/tmp/release'; \
	    echo 'Environment=PHX_SERVER=true'; \
	    echo 'ExecStart=$(CURDIR)/$(RELEASE_DIR)/bin/blog start'; \
	    echo 'Restart=on-failure'; \
	    echo 'RestartSec=5'; \
	    echo 'UMask=0077'; \
	    echo ''; \
	    echo '[Install]'; \
	    echo 'WantedBy=default.target'; \
	  } > "$(HOME)/.config/systemd/user/$(SERVICE_NAME)"; \
	  chmod 600 "$(HOME)/.config/systemd/user/$(SERVICE_NAME)"; \
	  systemctl --user daemon-reload

_require-env:
	@test -f "$(ENV_FILE)" || { echo "Missing $(ENV_FILE)" >&2; exit 1; }
	@for name in DB_DATABASE DB_USERNAME DB_PASSWORD DB_HOSTNAME DB_PORT; do \
	  if ! grep -Eq "^$$name=.+$$" "$(ENV_FILE)"; then echo "Missing required variable $$name in $(ENV_FILE)" >&2; exit 1; fi; \
	done

_ensure-backup-dir:
	@mkdir -p "$(BACKUP_DIR)"
	@chmod 700 "$(BACKUP_DIR)"
