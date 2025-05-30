# Data Explorer Service

This service provides a Streamlit web dashboard for visualizing and analyzing data stored in Google Cloud Storage. The dashboard connects to processed data from the Personal Expense Tracker pipelines and provides interactive charts and analysis tools.

## Prerequisites

- **Development tools**:
  - [`uv`](https://github.com/astral-sh/uv?tab=readme-ov-file#installation) Python package manager
  - [`gcloud`](https://cloud.google.com/sdk/docs/install) CLI tool with configured authentication
  - [Docker engine](https://docs.orbstack.dev/install) for containerized deployment (optional)

- **Cloud infrastructure**:
  - Infrastructure deployed with `terragrunt apply`
  - Dataset loaded by running the Notion or Google Sheets pipelines
  - Appropriate IAM permissions for your user or service account

## Verification Steps

Verify your setup before proceeding:

```shell
# Check uv installation
uv --version

# Verify gcloud configuration
gcloud config list account

# Verify terragrunt deployment status
cd terragrunt/dev
terragrunt output data_bucket_name
# Should return a valid bucket name

terragrunt output data_explorer_service_account_email
# Should return a valid service account email
```

## Running Locally

### Using the Common Run Script

The recommended way to run the data explorer locally is using the common run script:

1. Navigate to your environment directory:

   ```shell
   cd terragrunt/dev
   ```

2. Run the script:

   ```shell
   # Make the script executable (if not already)
   chmod +x ../../opentofu/scripts/run_local.sh

   # Run the data explorer locally
   ../../opentofu/scripts/run_local.sh data_explorer
   ```

3. Access the application:

   - URL: <http://localhost:8501/>
   - Default credentials:
     - Username: `rbriggs`
     - Password: `abc` (hashed in `config.yaml`)

### Using Docker (Alternative)

For containerized deployment:

```shell
cd opentofu/modules/data_explorer/src/
docker-compose up --build
```

## Deployment

### Updating Dependencies

When making code changes that require new dependencies:

1. Generate updated requirements:

   ```shell
   cd opentofu/modules/data_explorer/src
   uv export --format requirements-txt > requirements.txt
   ```

2. Deploy the updated service:

   ```shell
   cd terragrunt/dev
   terragrunt apply -target=module.data_explorer
   ```

## Troubleshooting

- **Permission errors**: Ensure your account has permission to impersonate the service account
- **Missing bucket**: Verify the bucket exists and your terragrunt deployment was successful
- **Data not appearing**: Check if data ingestion has completed by running the Notion or Google Sheets pipelines
- **Connection timeouts**: Verify your network connection and GCS bucket accessibility
- **Authentication issues**: Ensure HMAC credentials are properly configured and not expired

## Security Notes

- Service account impersonation credentials are temporary but powerful
- Never commit or share HMAC credentials
- For production usage, consider using Workload Identity Federation instead of impersonation

## Related Services

This Streamlit app visualizes data loaded by the following pipelines:

- [Notion Pipeline](../notion_pipeline/README.md) - Extracts expense data from Notion databases
- [Google Sheets Pipeline](../gsheets_pipeline/README.md) - Extracts budget data from Google Sheets

Both pipelines populate the GCS bucket used by this service.
