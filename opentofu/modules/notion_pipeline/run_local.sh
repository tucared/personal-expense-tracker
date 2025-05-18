#!/bin/bash

# Save current account
PREVIOUS_ACCOUNT=$(gcloud config get-value account)

# Get required values from terragrunt
SERVICE_ACCOUNT=$(terragrunt output -raw data_bucket_writer_service_account_email)
DATA_BUCKET_NAME=$(terragrunt output -raw data_bucket_name)

# Set impersonation
gcloud config set auth/impersonate_service_account $SERVICE_ACCOUNT

# Run the function
export SOURCES__NOTION__API_KEY=$(yq -r '.notion_pipeline.notion_api_key' env_vars.yaml)
export SOURCES__NOTION__DATABASE_ID=$(yq -r '.notion_pipeline.notion_database_id' env_vars.yaml)
export DESTINATION__FILESYSTEM__BUCKET_URL=gs://$DATA_BUCKET_NAME
export NORMALIZE__LOADER_FILE_FORMAT="parquet"
export RUNTIME__LOG_LEVEL="DEBUG"
export RUNTIME__DLTHUB_TELEMETRY=false

uv run --directory="$(dirname "$0")/src/" \
    functions-framework \
    --target=notion_pipeline \
    --debug

# Reset to original account
if [ -z "$PREVIOUS_ACCOUNT" ]; then
    gcloud config unset auth/impersonate_service_account
else
    gcloud config set account $PREVIOUS_ACCOUNT
fi