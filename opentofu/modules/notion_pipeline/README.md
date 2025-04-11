# Notion Data Pipeline

This service extracts data from Notion and loads it into Google Cloud Storage using the Data Load Tool (DLT) framework. The pipeline runs as a Cloud Function triggered by a Cloud Scheduler.

## Prerequisites

- **Development tools**:
  - [`uv`](https://github.com/astral-sh/uv?tab=readme-ov-file#installation) Python package manager
  - [`gcloud`](https://cloud.google.com/sdk/docs/install) CLI tool with configured authentication
  - [`yq`](https://github.com/mikefarah/yq#install) for YAML processing (only needed for local testing)

- **Cloud infrastructure**:
  - Infrastructure deployed with `terragrunt apply`
  - Notion API key configured in `env_vars.yaml`
  - Appropriate IAM permissions configured

## Verification Steps

Verify your setup before proceeding:

```shell
# Check uv installation
uv --version

# Verify gcloud configuration
gcloud config list account

# Verify terragrunt deployment
cd terragrunt/dev
terragrunt output data_bucket_writer_service_account_email
# Should return a valid service account email
```

## Running Locally

### Step 1: Pause Cloud Schedulers (Recommended)

To avoid conflicts between local and cloud execution, pause the scheduler:

```yaml
# Update terragrunt/dev/env_vars.yaml
notion_pipeline:
    cloud_scheduler_parameters:
        paused: true
```

Then apply the changes:

```shell
cd terragrunt/dev
terragrunt apply -target=module.notion_pipeline.google_cloud_scheduler_job.this
```

### Step 2: Start Local Server

1. Navigate to your environment directory:

   ```shell
   cd terragrunt/dev
   ```

2. Extract configuration values:

   ```shell
   # Get service account email and verify it exists
   export SERVICE_ACCOUNT=$(terragrunt output -raw data_bucket_writer_service_account_email)
   echo "Using service account: $SERVICE_ACCOUNT"

   # Verify Notion API key exists
   if ! yq -e '.notion_pipeline.notion_api_key' env_vars.yaml > /dev/null; then
     echo "ERROR: Notion API key not found in env_vars.yaml"
     exit 1
   fi

   # Get bucket name
   export DATA_BUCKET_NAME=$(terragrunt output -raw data_bucket_name)
   echo "Using bucket: $DATA_BUCKET_NAME"
   ```

3. Start server with service account impersonation:

   ```shell
   # Impersonate service account (temporary credentials)
   gcloud config set auth/impersonate_service_account $SERVICE_ACCOUNT

   # Start local functions framework server
   SOURCES__NOTION__API_KEY=$(yq -r '.notion_pipeline.notion_api_key' env_vars.yaml) \
   DESTINATION__FILESYSTEM__BUCKET_URL=gs://$DATA_BUCKET_NAME \
   NORMALIZE__LOADER_FILE_FORMAT="parquet" \
   RUNTIME__LOG_LEVEL="DEBUG" \
   RUNTIME__DLTHUB_TELEMETRY=false \
   uv run --directory="../../opentofu/modules/notion_pipeline/src/" \
       functions-framework \
       --target=notion_pipeline \
       --debug
   ```

### Step 3: Trigger the Function

In a separate terminal:

```shell
# Basic invocation
curl localhost:8080
```

### Step 4: Reset Credentials

When finished testing:

```shell
gcloud config unset auth/impersonate_service_account
```

## Deployment

### Updating Requirements

When making code changes that require new dependencies:

1. Generate updated requirements:

   ```shell
   cd opentofu/modules/notion_pipeline/src
   uv export --format requirements-txt > requirements.txt
   ```

2. Deploy the updated function:

   ```shell
   cd terragrunt/dev
   terragrunt apply -target=module.notion_pipeline
   ```

### Re-enabling Cloud Scheduler

After local testing, re-enable the scheduler if needed:

```yaml
# Update terragrunt/dev/env_vars.yaml
notion_pipeline:
    cloud_scheduler_parameters:
        paused: false
```

Then apply the changes:

```shell
terragrunt apply -target=module.notion_pipeline.google_cloud_scheduler_job.this
```

## Troubleshooting

- **Permission errors**: Ensure your account has permission to impersonate the service account
- **Missing API key**: Verify the Notion API key is correctly set in `env_vars.yaml`
- **Data not appearing in bucket**: Check function logs for extraction or loading errors
- **Function timeouts**: For large data extractions, consider increasing function timeout in your terraform configuration

## Related Services

This pipeline populates data for the [Data Explorer](./opentofu/modules/data_explorer/README.md) service, which visualizes the data loaded into Cloud Storage.
