# Help target
help:
	@echo "Available commands:"
	@echo "  run-<service>-dev         - Run a service locally in dev environment"
	@echo "  run-<service>-prod        - Run a service locally in prod environment"
	@echo "  trigger-<service>-dev     - Trigger a pipeline remotely in dev environment"
	@echo "  trigger-<service>-prod    - Trigger a pipeline remotely in prod environment"
	@echo "  open-dashboard-dev        - Open the data explorer dashboard in dev environment"
	@echo "  open-dashboard-prod       - Open the data explorer dashboard in prod environment"
	@echo "  init-duckdb-dev           - Initialize DuckDB database for dev environment"
	@echo "  init-duckdb-prod          - Initialize DuckDB database for prod environment"
	@echo "  generate-schema-dev       - Generate database schema CSV from dev.duckdb"
	@echo "  generate-schema-prod      - Generate database schema CSV from prod.duckdb"
	@echo "  lint                      - Run linting across all Python modules"
	@echo "  format                    - Run formatting across all Python modules"
	@echo "  install                   - Install dependencies for all Python modules"
	@echo "  lint-<service>            - Run linting for specific service module"
	@echo "  format-<service>          - Run formatting for specific service module"
	@echo "  clean                     - Clean temporary files and databases"
	@echo "  <command>-dev             - Run terragrunt command in dev environment"
	@echo "  <command>-prod            - Run terragrunt command in prod environment"
	@echo "  output-<output>-dev       - Get terragrunt output in dev environment"
	@echo "  output-<output>-prod      - Get terragrunt output in prod environment"
	@echo ""
	@echo "Available services: notion, gsheets, data-explorer, pipeline-runner"
	@echo ""
	@echo "Examples:"
	@echo "  make run-notion-dev"
	@echo "  make run-data-explorer-prod"
	@echo "  make trigger-notion-prod"
	@echo "  make trigger-gsheets-dev"
	@echo "  make open-dashboard-prod"
	@echo "  make init-duckdb-dev && duckdb dev.duckdb"
	@echo "  make plan-dev"
	@echo "  make apply-prod"
	@echo "  make output-data_explorer_build_trigger_region-dev"
	@echo "  make lint"
	@echo "  make format"
	@echo "  make lint-notion"
	@echo "  make lint-pipeline-runner"

# Pattern rule for running local services (must come before general pattern)
run-%-dev:
	@$(MAKE) _run-local SERVICE=$* ENV=dev

run-%-prod:
	@$(MAKE) _run-local SERVICE=$* ENV=prod

# Output raw variable from terragrunt
output-%-dev:
	@cd terragrunt/dev && terragrunt output -raw $*

output-%-prod:
	@cd terragrunt/prod && terragrunt output -raw $*

# Pattern rule for triggering individual pipelines
trigger-%-dev:
	@echo "Triggering $* pipeline for dev environment..."
	@URI=$$($(MAKE) output-$*_pipeline_function_uri-dev) && \
	TOKEN=$$(gcloud auth print-identity-token) && \
	curl -i -X POST $$URI -H "Authorization: bearer $$TOKEN"

trigger-%-prod:
	@echo "Triggering $* pipeline for prod environment..."
	@URI=$$($(MAKE) output-$*_pipeline_function_uri-prod) && \
	TOKEN=$$(gcloud auth print-identity-token) && \
	curl -i -X POST $$URI -H "Authorization: bearer $$TOKEN"

# Open dashboard in browser
open-dashboard-dev:
	@URL=$$($(MAKE) output-data_explorer_service_url-dev) && \
	echo "Opening dashboard at $$URL" && \
	open $$URL

open-dashboard-prod:
	@URL=$$($(MAKE) output-data_explorer_service_url-prod) && \
	echo "Opening dashboard at $$URL" && \
	open $$URL

# Initialize DuckDB with configuration
init-duckdb-dev:
	@echo "Initializing DuckDB database for dev environment..."
	@cd terragrunt/dev && \
	DATA_BUCKET_NAME=$$(terragrunt output -raw data_bucket_name 2>/dev/null) && \
	HMAC_ACCESS_ID=$$(terragrunt output -raw data_explorer_hmac_access_id 2>/dev/null) && \
	HMAC_SECRET=$$(terragrunt output -raw data_explorer_hmac_secret 2>/dev/null) && \
	export GCS_BUCKET_NAME=$$DATA_BUCKET_NAME && \
	export HMAC_ACCESS_ID=$$HMAC_ACCESS_ID && \
	export HMAC_SECRET=$$HMAC_SECRET && \
	export SECRET_TYPE="PERSISTENT SECRET" && \
	rm -f /tmp/duckdb_init_dev.*.sql && \
	INIT_FILE=$$(mktemp /tmp/duckdb_init_dev.XXXXXX.sql) && \
	envsubst < ../../opentofu/modules/data_explorer/src/duckdb_init.sql > $$INIT_FILE && \
	duckdb ../../dev.duckdb -init $$INIT_FILE ".exit" >/dev/null 2>&1 && \
	rm -f $$INIT_FILE && \
	echo "Database initialized as dev.duckdb"

# Initialize DuckDB with configuration
init-duckdb-prod:
	@echo "Initializing DuckDB database for prod environment..."
	@cd terragrunt/prod && \
	DATA_BUCKET_NAME=$$(terragrunt output -raw data_bucket_name 2>/dev/null) && \
	HMAC_ACCESS_ID=$$(terragrunt output -raw data_explorer_hmac_access_id 2>/dev/null) && \
	HMAC_SECRET=$$(terragrunt output -raw data_explorer_hmac_secret 2>/dev/null) && \
	export GCS_BUCKET_NAME=$$DATA_BUCKET_NAME && \
	export HMAC_ACCESS_ID=$$HMAC_ACCESS_ID && \
	export HMAC_SECRET=$$HMAC_SECRET && \
	export SECRET_TYPE="PERSISTENT SECRET" && \
	rm -f /tmp/duckdb_init_prod.*.sql && \
	INIT_FILE=$$(mktemp /tmp/duckdb_init_prod.XXXXXX.sql) && \
	envsubst < ../../opentofu/modules/data_explorer/src/duckdb_init.sql > $$INIT_FILE && \
	duckdb ../../prod.duckdb -init $$INIT_FILE ".exit" >/dev/null 2>&1 && \
	rm -f $$INIT_FILE && \
	echo "Database initialized as prod.duckdb"

# Pattern rule for terragrunt commands
%-dev:
	cd terragrunt/dev && terragrunt $* --non-interactive

%-prod:
	cd terragrunt/prod && terragrunt $* --non-interactive

# Internal target for running local services
_run-local:
	@cd terragrunt/$(ENV) && \
	gcloud config unset auth/impersonate_service_account; \
	gcloud config unset project; \
	SERVICE_ACCOUNT=$$(terragrunt output -raw data_bucket_writer_service_account_email) && \
	DATA_BUCKET_NAME=$$(terragrunt output -raw data_bucket_name) && \
	PROJECT_ID=$$(yq -r '.project_id' env_vars.yaml) && \
	LAYOUT=$$(echo "{table_name}/data.{ext}") && \
	gcloud config set project $$PROJECT_ID && \
	gcloud config set auth/impersonate_service_account $$SERVICE_ACCOUNT && \
	export DESTINATION__FILESYSTEM__BUCKET_URL=gs://$$DATA_BUCKET_NAME && \
	export DESTINATION__FILESYSTEM__LAYOUT=$$LAYOUT && \
	export RUNTIME__LOG_LEVEL="DEBUG" && \
	export RUNTIME__DLTHUB_TELEMETRY=false && \
	case $(SERVICE) in \
		"notion") \
			export SOURCES__NOTION__API_KEY=$$(yq -r '.notion_pipeline.notion_api_key' env_vars.yaml) && \
			export SOURCES__NOTION__DATABASE_ID=$$(yq -r '.notion_pipeline.notion_database_id' env_vars.yaml) && \
			TARGET="notion_pipeline" && \
			SRC_DIR="../../opentofu/modules/notion_pipeline/src/" && \
			uv run --directory=$$SRC_DIR functions-framework --target=$$TARGET --debug; \
			;; \
		"gsheets") \
			export SOURCES__GOOGLE_SHEETS__CREDENTIALS__CLIENT_EMAIL=$$SERVICE_ACCOUNT && \
			export SOURCES__GOOGLE_SHEETS__CREDENTIALS__PROJECT_ID=$$PROJECT_ID && \
			export SOURCES__GOOGLE_SHEETS__SPREADSHEET_URL_OR_ID=$$(yq -r '.gsheets_pipeline.spreadsheet_url_or_id' env_vars.yaml) && \
			export SOURCES__GOOGLE_SHEETS__CREDENTIALS__PRIVATE_KEY=$$(terragrunt output -raw data_bucket_writer_private_key) && \
			TARGET="gsheets_pipeline" && \
			SRC_DIR="../../opentofu/modules/gsheets_pipeline/src/" && \
			uv run --directory=$$SRC_DIR functions-framework --target=$$TARGET --debug; \
			;; \
		"data-explorer") \
			echo "Starting Data Explorer in cloud-connected mode..." && \
			AUTH_USERNAME=$$(yq -r '.data_explorer.auth_username' env_vars.yaml) && \
			AUTH_PASSWORD=$$(yq -r '.data_explorer.auth_password' env_vars.yaml) && \
			echo "Credentials - Username: $$AUTH_USERNAME, Password: $$AUTH_PASSWORD" && \
			export SERVICE_ACCOUNT=$$(terragrunt output -raw data_explorer_service_account_email) && \
			export GCS_BUCKET_NAME=$$DATA_BUCKET_NAME && \
			export HMAC_ACCESS_ID=$$(terragrunt output -raw data_explorer_hmac_access_id) && \
			export HMAC_SECRET=$$(terragrunt output -raw data_explorer_hmac_secret) && \
			export AUTH_USERNAME=$$AUTH_USERNAME && \
			export AUTH_PASSWORD=$$AUTH_PASSWORD && \
			export COOKIE_KEY=$$(openssl rand -base64 32) && \
			export STREAMLIT_THEME_BASE="light" && \
			echo "Using service account: $$SERVICE_ACCOUNT" && \
			echo "Using bucket: $$GCS_BUCKET_NAME" && \
			SRC_DIR="../../opentofu/modules/data_explorer/src/" && \
			uv run --directory=$$SRC_DIR streamlit run app.py  --server.runOnSave true; \
			;; \
		*) \
			echo "Error: Unknown service $(SERVICE)" && \
			echo "Available services: notion, gsheets, data-explorer" && \
			exit 1; \
			;; \
	esac; \
	gcloud config unset auth/impersonate_service_account; \
	gcloud config unset project

generate-requirements:
	uvx pre-commit run uv-lock --all-files
	uvx pre-commit run uv-export --all-files

# Generate database schema CSV from DuckDB
generate-schema-dev: dev.duckdb
	@echo "Generating database schema from dev.duckdb..."
	@duckdb dev.duckdb -csv -c "SHOW ALL TABLES" > docs/database_schema.csv
	@echo "Schema generated: docs/database_schema.csv"

generate-schema-prod: prod.duckdb
	@echo "Generating database schema from prod.duckdb..."
	@duckdb prod.duckdb -csv -c "SHOW ALL TABLES" > docs/database_schema.csv
	@echo "Schema generated: docs/database_schema.csv"

# Python development commands
PYTHON_MODULES := opentofu/modules/notion_pipeline/src \
                  opentofu/modules/gsheets_pipeline/src \
                  opentofu/modules/data_explorer/src \
                  mcp-servers/pipeline-runner

lint:
	@for dir in $(PYTHON_MODULES); do \
		echo "Linting $$dir..."; \
		uv run --directory=$$dir ruff check . || exit 1; \
		uv run --directory=$$dir ty check . || exit 1; \
	done

format:
	@for dir in $(PYTHON_MODULES); do \
		echo "Formatting $$dir..."; \
		uv run --directory=$$dir ruff format .; \
	done

install:
	@for dir in $(PYTHON_MODULES); do \
		echo "Installing dependencies for $$dir..."; \
		uv sync --directory=$$dir; \
	done

# Per-module linting
lint-notion:
	@echo "Linting notion pipeline..."
	@uv run --directory=opentofu/modules/notion_pipeline/src ruff check .
	@uv run --directory=opentofu/modules/notion_pipeline/src ty check .

lint-gsheets:
	@echo "Linting gsheets pipeline..."
	@uv run --directory=opentofu/modules/gsheets_pipeline/src ruff check .
	@uv run --directory=opentofu/modules/gsheets_pipeline/src ty check .

lint-data-explorer:
	@echo "Linting data explorer..."
	@uv run --directory=opentofu/modules/data_explorer/src ruff check .
	@uv run --directory=opentofu/modules/data_explorer/src ty check .

lint-pipeline-runner:
	@echo "Linting pipeline runner..."
	@uv run --directory=mcp-servers/pipeline-runner ruff check .
	@uv run --directory=mcp-servers/pipeline-runner mypy .

# Per-module formatting
format-notion:
	@echo "Formatting notion pipeline..."
	@uv run --directory=opentofu/modules/notion_pipeline/src ruff format .

format-gsheets:
	@echo "Formatting gsheets pipeline..."
	@uv run --directory=opentofu/modules/gsheets_pipeline/src ruff format .

format-data-explorer:
	@echo "Formatting data explorer..."
	@uv run --directory=opentofu/modules/data_explorer/src ruff format .

format-pipeline-runner:
	@echo "Formatting pipeline runner..."
	@uv run --directory=mcp-servers/pipeline-runner ruff format .

# Clean temporary files
clean:
	@echo "Cleaning temporary files..."
	@rm -f *.duckdb /tmp/duckdb_init_*.sql
	@find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.pyc" -delete 2>/dev/null || true

# Make all -dev and -prod targets phony
.PHONY: %-dev %-prod run-%-dev run-%-prod _run-local init-duckdb-dev init-duckdb-prod lint format install clean lint-notion lint-gsheets lint-data-explorer lint-pipeline-runner format-notion format-gsheets format-data-explorer format-pipeline-runner
