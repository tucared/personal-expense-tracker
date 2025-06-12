# Help target
help:
	@echo "Available commands:"
	@echo "  run-<service>-dev   - Run a service locally in dev environment"
	@echo "  run-<service>-prod  - Run a service locally in prod environment"
	@echo "  <command>-dev       - Run terragrunt command in dev environment"
	@echo "  <command>-prod      - Run terragrunt command in prod environment"
	@echo ""
	@echo "Available services: notion, gsheets, data-explorer"
	@echo ""
	@echo "Examples:"
	@echo "  make run-notion-dev"
	@echo "  make run-data-explorer-prod"
	@echo "  make plan-dev"
	@echo "  make apply-prod"

# Pattern rule for running local services (must come before general pattern)
run-%-dev:
	@$(MAKE) _run-local SERVICE=$* ENV=dev

run-%-prod:
	@$(MAKE) _run-local SERVICE=$* ENV=prod

# Pattern rule for terragrunt commands
%-dev:
	cd terragrunt/dev && terragrunt $* --non-interactive

%-prod:
	cd terragrunt/prod && terragrunt $* --non-interactive

# Internal target for running local services
_run-local:
	@cd terragrunt/$(ENV) && \
	SERVICE_ACCOUNT=$$(terragrunt output -raw data_bucket_writer_service_account_email) && \
	DATA_BUCKET_NAME=$$(terragrunt output -raw data_bucket_name) && \
	gcloud config set auth/impersonate_service_account $$SERVICE_ACCOUNT && \
	export DESTINATION__FILESYSTEM__BUCKET_URL=gs://$$DATA_BUCKET_NAME && \
	export NORMALIZE__LOADER_FILE_FORMAT="parquet" && \
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
			export SOURCES__GOOGLE_SHEETS__CREDENTIALS__PROJECT_ID=$$(yq -r '.project_id' env_vars.yaml) && \
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
			echo "Using service account: $$SERVICE_ACCOUNT" && \
			echo "Using bucket: $$GCS_BUCKET_NAME" && \
			SRC_DIR="../../opentofu/modules/data_explorer/src/" && \
			uv run --directory=$$SRC_DIR streamlit run app.py; \
			;; \
		*) \
			echo "Error: Unknown service $(SERVICE)" && \
			echo "Available services: notion, gsheets, data-explorer" && \
			exit 1; \
			;; \
	esac; \
	gcloud config unset auth/impersonate_service_account

generate-requirements:
	uvx pre-commit run uv-lock
	uvx pre-commit run uv-export

# Make all -dev and -prod targets phony
.PHONY: %-dev %-prod run-%-dev run-%-prod _run-local
