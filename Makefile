# psql runs inside the container, so nothing else needs to be installed.
PSQL = docker compose exec -T db psql -X -q -v ON_ERROR_STOP=1 -U k2 -d k2

.PHONY: up down reset migrate psql check

# Start the database and wait until it accepts connections.
up:
	docker compose up -d --wait

# Stop the database. Data is kept in the named volume.
down:
	docker compose down

# Remove the database and its data, then start an empty one.
reset:
	docker compose down -v
	docker compose up -d --wait

# Apply each migration file once, in order, each in one transaction.
migrate:
	@$(PSQL) -c "set client_min_messages = warning; create table if not exists public.schema_migrations (file_name varchar primary key, applied_at timestamptz not null default now())"
	@for f in migrations/*.sql; do \
		name=$$(basename $$f); \
		applied=$$($(PSQL) -tA -c "select 1 from public.schema_migrations where file_name = '$$name'"); \
		if [ "$$applied" = "1" ]; then \
			echo "skip   $$name"; \
		else \
			echo "apply  $$name"; \
			{ cat $$f; echo; echo "insert into public.schema_migrations (file_name) values ('$$name');"; } \
				| $(PSQL) --single-transaction || exit 1; \
		fi; \
	done

# Open a psql prompt.
psql:
	docker compose exec db psql -U k2 -d k2

# Run the checks. Each one is rolled back.
check:
	@$(PSQL) < checks/checks.sql
