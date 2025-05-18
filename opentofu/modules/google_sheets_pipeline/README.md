# Google Sheets Pipeline

This service extracts data from Google Sheets and loads it into Google Cloud Storage using the Data Load Tool (DLT) framework. The pipeline runs as a Cloud Function triggered by a Cloud Scheduler.

## Prerequisites

- **Development tools**:
  - [`uv`](https://github.com/astral-sh/uv?tab=readme-ov-file#installation) Python package manager
  - [`gcloud`](https://cloud.google.com/sdk/docs/install) CLI tool with configured authentication
  - [`yq`](https://github.com/mikefarah/yq#install) for YAML processing (only needed for local testing)

- **Cloud infrastructure**:
  - Infrastructure deployed with `terragrunt apply`
  - Google Sheets API configured with appropriate credentials
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
google_sheets_pipeline:
    cloud_scheduler_parameters:
        paused: true
```

Then apply the changes:

```shell
cd terragrunt/dev
terragrunt apply -target=module.google_sheets_pipeline.google_cloud_scheduler_job.this
```

### Step 2: Run Local Server with Automated Script

The provided script handles service account impersonation and automatically resets your credentials after testing.

1. Navigate to your environment directory:

   ```shell
   cd terragrunt/dev
   ```

2. Run the script:

   ```shell
   # Make the script executable
   chmod +x ../../opentofu/modules/google_sheets_pipeline/run_local.sh

   # Run the script
   ../../opentofu/modules/google_sheets_pipeline/run_local.sh
   ```

   The script will impersonate the service account, start the functions framework server, and automatically reset your credentials when done.

### Step 3: Trigger the Function

In a separate terminal:

```shell
# Basic invocation
curl localhost:8080
```

## Deployment

### Updating Requirements

When making code changes that require new dependencies:

1. Generate updated requirements:

   ```shell
   cd opentofu/modules/google_sheets_pipeline/src
   uv export --format requirements-txt > requirements.txt
   ```

2. Deploy the updated function:

   ```shell
   cd terragrunt/dev
   terragrunt apply -target=module.google_sheets_pipeline
   ```

### Re-enabling Cloud Scheduler

After local testing, re-enable the scheduler if needed:

```yaml
# Update terragrunt/dev/env_vars.yaml
google_sheets_pipeline:
    cloud_scheduler_parameters:
        paused: false
```

Then apply the changes:

```shell
terragrunt apply -target=module.google_sheets_pipeline.google_cloud_scheduler_job.this
```

## Troubleshooting

- **Permission errors**: Ensure your account has permission to impersonate the service account
- **Data not appearing in bucket**: Check function logs for extraction or loading errors
- **Function timeouts**: For large data extractions, consider increasing function timeout in your terraform configuration
- **Authentication issues**: If you see credential errors, verify that service account impersonation is working correctly

## Related Services

This pipeline populates data for the [Data Explorer](./opentofu/modules/data_explorer/README.md) service, which visualizes the data loaded into Cloud Storage.
