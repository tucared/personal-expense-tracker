PIPELINE_NAME=$1

if [ -z "$PIPELINE_NAME" ]; then
  echo "Error: Pipeline name required"
  echo "Usage: ./run_local.sh <pipeline_name>"
  echo "Available pipelines: notion_pipeline, gsheets_pipeline"
  exit 1
fi

# Save current account
PREVIOUS_ACCOUNT=$(gcloud config get-value account)

# Get required values from terragrunt
SERVICE_ACCOUNT=$(terragrunt output -raw data_bucket_writer_service_account_email)
DATA_BUCKET_NAME=$(terragrunt output -raw data_bucket_name)

# Set impersonation
gcloud config set auth/impersonate_service_account $SERVICE_ACCOUNT

# Set common environment variables
export DESTINATION__FILESYSTEM__BUCKET_URL=gs://$DATA_BUCKET_NAME
export NORMALIZE__LOADER_FILE_FORMAT="parquet"
export RUNTIME__LOG_LEVEL="DEBUG"
export RUNTIME__DLTHUB_TELEMETRY=false

# Set pipeline-specific environment variables
case $PIPELINE_NAME in
  "notion_pipeline")
    export SOURCES__NOTION__API_KEY=$(yq -r '.notion_pipeline.notion_api_key' env_vars.yaml)
    export SOURCES__NOTION__DATABASE_ID=$(yq -r '.notion_pipeline.notion_database_id' env_vars.yaml)
    TARGET="notion_pipeline"
    SRC_DIR="../../opentofu/modules/notion_pipeline/src/"
    ;;
  "gsheets_pipeline")
    export SOURCES__GOOGLE_SHEETS__CREDENTIALS__CLIENT_EMAIL=$SERVICE_ACCOUNT
    export SOURCES__GOOGLE_SHEETS__CREDENTIALS__PROJECT_ID=$(yq -r '.project_id' env_vars.yaml)
    export SOURCES__GOOGLE_SHEETS__SPREADSHEET_URL_OR_ID=$(yq -r '.gsheets_pipeline.spreadsheet_url_or_id' env_vars.yaml)
    
    # Get the private key from terragrunt output
    export SOURCES__GOOGLE_SHEETS__CREDENTIALS__PRIVATE_KEY=$(terragrunt output -raw data_bucket_writer_private_key)
    
    TARGET="gsheets_pipeline"
    SRC_DIR="../../opentofu/modules/gsheets_pipeline/src/"
    ;;
  *)
    echo "Error: Unknown pipeline $PIPELINE_NAME"
    echo "Available pipelines: notion_pipeline, gsheets_pipeline"
    gcloud config set account $PREVIOUS_ACCOUNT
    exit 1
    ;;
esac

# Run the function
uv run --directory=$SRC_DIR \
    functions-framework \
    --target=$TARGET \
    --debug

# Reset to original account
if [ -z "$PREVIOUS_ACCOUNT" ]; then
    gcloud config unset auth/impersonate_service_account
else
    gcloud config set account $PREVIOUS_ACCOUNT
fi