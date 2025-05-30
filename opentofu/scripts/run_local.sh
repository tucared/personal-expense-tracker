SERVICE_NAME=$1

if [ -z "$SERVICE_NAME" ]; then
  echo "Error: Service name required"
  echo "Usage: ./run_local.sh <service_name>"
  echo "Available services: notion_pipeline, gsheets_pipeline, data_explorer"
  exit 1
fi

# Save current account
PREVIOUS_ACCOUNT=$(gcloud config get-value account)

# Get required values from terragrunt
SERVICE_ACCOUNT=$(terragrunt output -raw data_bucket_writer_service_account_email)
DATA_BUCKET_NAME=$(terragrunt output -raw data_bucket_name)

# Set impersonation for all services
gcloud config set auth/impersonate_service_account $SERVICE_ACCOUNT

# Set common environment variables
export DESTINATION__FILESYSTEM__BUCKET_URL=gs://$DATA_BUCKET_NAME
export NORMALIZE__LOADER_FILE_FORMAT="parquet"
export RUNTIME__LOG_LEVEL="DEBUG"
export RUNTIME__DLTHUB_TELEMETRY=false

# Set service-specific environment variables
case $SERVICE_NAME in
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
  "data_explorer")
    # Set up cloud-connected mode environment variables
    echo "Starting Data Explorer in cloud-connected mode..."
    echo "Access the application at: http://localhost:8501/"
    
    # Get auth credentials from YAML
    AUTH_USERNAME=$(yq -r '.data_explorer.auth_username' env_vars.yaml)
    AUTH_PASSWORD=$(yq -r '.data_explorer.auth_password' env_vars.yaml)
    
    echo "Credentials - Username: $AUTH_USERNAME, Password: $AUTH_PASSWORD"
    
    # Set environment variables for cloud access
    export SERVICE_ACCOUNT=$(terragrunt output -raw data_explorer_service_account_email)
    export GCS_BUCKET_NAME=$DATA_BUCKET_NAME
    export HMAC_ACCESS_ID=$(terragrunt output -raw data_explorer_hmac_access_id)
    export HMAC_SECRET=$(terragrunt output -raw data_explorer_hmac_secret)
    export AUTH_USERNAME=$AUTH_USERNAME
    export AUTH_PASSWORD=$AUTH_PASSWORD
    # For local development, generate a random cookie key
    export COOKIE_KEY=$(openssl rand -base64 32)
    
    echo "Using service account: $SERVICE_ACCOUNT"
    echo "Using bucket: $GCS_BUCKET_NAME"
    
    SRC_DIR="../../opentofu/modules/data_explorer/src/"
    ;;
  *)
    echo "Error: Unknown service $SERVICE_NAME"
    echo "Available services: notion_pipeline, gsheets_pipeline, data_explorer"
    gcloud config set account $PREVIOUS_ACCOUNT
    exit 1
    ;;
esac

# Run the service
if [ "$SERVICE_NAME" = "data_explorer" ]; then
  # Run Streamlit app
  uv run --directory="$SRC_DIR" streamlit run app.py
else
  # Run pipeline function
  uv run --directory=$SRC_DIR \
      functions-framework \
      --target=$TARGET \
      --debug
fi

# Reset to original account
if [ -z "$PREVIOUS_ACCOUNT" ]; then
    gcloud config unset auth/impersonate_service_account
else
    gcloud config set account $PREVIOUS_ACCOUNT
fi