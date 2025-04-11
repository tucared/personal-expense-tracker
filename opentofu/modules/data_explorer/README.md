# Streamlit Data Explorer Service

This service provides a web dashboard for visualizing and analyzing data stored in Google Cloud Storage. This guide explains how to run the application locally for development and testing.

## Prerequisites

- **Development tools**: Install one of the following:
  - [`uv`](https://github.com/astral-sh/uv?tab=readme-ov-file#installation) Python package manager
  - [Docker engine](https://docs.orbstack.dev/install) for containerized deployment

- **Cloud infrastructure**:
  - Ensure infrastructure is deployed with `terragrunt apply`
  - Verify dataset is loaded by checking [Data Ingestion Status](README.md#Triggering-Data-Ingestion)
  - Confirm appropriate IAM permissions for your user or service account

## Verification Steps

Before proceeding, verify these prerequisites:

```shell
# Check uv installation
uv --version

# Verify terragrunt deployment status
cd terragrunt/dev
terragrunt output data_bucket_name
# Should return a valid bucket name
```

## Running Locally

### Option 1: Standalone Mode (No Cloud Storage Access)

This option uses mock data and doesn't require Cloud credentials.

1. Navigate to the application source:

   ```shell
   cd ../../opentofu/modules/streamlit/src/
   ```

2. Start the server:
   - **Using Python**:

     ```shell
     uv run streamlit run app.py
     ```

   - **Using Docker**:

     ```shell
     docker-compose up --build
     ```

3. Access the application:
   - URL: <http://localhost:8501/>
   - Default credentials:
     - Username: `rbriggs`
     - Password: `abc` (hashed in `config.yaml`)

### Option 2: Cloud-Connected Mode (With GCS Access)

This option connects to actual Cloud Storage data using service account impersonation.

1. Navigate to your environment directory:

   ```shell
   cd terragrunt/dev
   ```

2. Export required environment variables:

   ```shell
   # Extract required values from terragrunt outputs
   export SERVICE_ACCOUNT=$(terragrunt output -raw streamlit_service_account_email)
   export GCS_BUCKET_NAME=$(terragrunt output -raw data_bucket_name)
   export HMAC_ACCESS_ID=$(terragrunt output -raw streamlit_hmac_access_id)
   export HMAC_SECRET=$(terragrunt output -raw streamlit_hmac_secret)

   # Verify exports were successful
   echo "Using service account: $SERVICE_ACCOUNT"
   echo "Using bucket: $GCS_BUCKET_NAME"
   ```

3. Impersonate the service account (temporary credentials):

   ```shell
   gcloud config set auth/impersonate_service_account $SERVICE_ACCOUNT
   ```

4. Start the application:

   ```shell
   uv run --directory="../../opentofu/modules/streamlit/src/" streamlit run app.py
   ```

5. When finished, reset credentials:

   ```shell
   gcloud config unset auth/impersonate_service_account
   ```

## Troubleshooting

- **Permission errors**: Ensure your account has permission to impersonate the service account
- **Missing bucket**: Verify the bucket exists and your terragrunt deployment was successful
- **Data not appearing**: Check if data ingestion has completed by running the Notion pipeline

## Security Notes

- Service account impersonation credentials are temporary but powerful
- Never commit or share HMAC credentials
- For production usage, consider using Workload Identity Federation instead of impersonation

## Related Services

This Streamlit app visualizes data loaded by the [Notion Pipeline](./opentofu/modules/notion_pipeline/README.md), which populates the GCS bucket used by this service.
