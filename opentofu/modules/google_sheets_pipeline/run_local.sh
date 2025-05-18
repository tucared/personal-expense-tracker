#!/bin/bash

# Save current account
PREVIOUS_ACCOUNT=$(gcloud config get-value account)

# Get required values from terragrunt
SERVICE_ACCOUNT=$(terragrunt output -raw data_bucket_writer_service_account_email)
DATA_BUCKET_NAME=$(terragrunt output -raw data_bucket_name)
PRIVATE_KEY=$(terragrunt output -raw google_sheets_pipeline_data_bucket_writer_private_key_value)

# Set impersonation
gcloud config set auth/impersonate_service_account $SERVICE_ACCOUNT

# Run the function
export SOURCES__GOOGLE_SHEETS__CREDENTIALS__CLIENT_EMAIL=$SERVICE_ACCOUNT
export SOURCES__GOOGLE_SHEETS__CREDENTIALS__PROJECT_ID=$(yq -r '.project_id' env_vars.yaml)
export SOURCES__GOOGLE_SHEETS__SPREADSHEET_URL_OR_ID=$(yq -r '.google_sheets_pipeline.spreadsheet_url_or_id' env_vars.yaml)
export DESTINATION__FILESYSTEM__BUCKET_URL=gs://$DATA_BUCKET_NAME
export NORMALIZE__LOADER_FILE_FORMAT="parquet"
export RUNTIME__LOG_LEVEL="DEBUG"
export RUNTIME__DLTHUB_TELEMETRY=false
export SOURCES__GOOGLE_SHEETS__CREDENTIALS__PRIVATE_KEY=$PRIVATE_KEY

uv run --directory="$(dirname "$0")/src/" \
    functions-framework \
    --target=google_sheets_pipeline \
    --debug

# Reset to original account
if [ -z "$PREVIOUS_ACCOUNT" ]; then
    gcloud config unset auth/impersonate_service_account
else
    gcloud config set account $PREVIOUS_ACCOUNT
fi