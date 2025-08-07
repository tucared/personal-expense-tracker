# Base Pipeline Module

This module serves as a foundation for creating data pipelines in the Personal Expense Tracker project. It implements common infrastructure patterns for deploying cloud functions that extract data from various sources and store it in a Google Cloud Storage bucket.

## Features

- **Standardized Infrastructure**: Common setup for all data pipelines
- **Secret Management**: Secure handling of API keys and credentials
- **Cloud Function Deployment**: Consistent deployment with configurable settings
- **Cloud Scheduler**: Automatic scheduling of pipeline execution
- **IAM Permissions**: Appropriate security setup for all resources

## Module Usage

This module is designed to be used as a base for specific data source pipelines. It's not intended to be used directly, but rather imported by specific pipeline modules like `notion_pipeline` or `gsheets_pipeline`.

**Important Notes:**

- The base pipeline module references the `src/` directory from the specific pipeline module that imports it
- Each pipeline module must maintain its own source code in its `src/` directory
- For service account names that might exceed GCP's 30-character limit, the module creates shortened unique names

### Example Implementation

```hcl
module "base_pipeline" {
  source = "../base_pipeline"

  project_id               = var.project_id
  region                   = var.region
  data_bucket_name         = var.data_bucket_name
  service_account_email    = var.service_account_email
  pipeline_name            = "my_custom_pipeline"
  entry_point              = "my_custom_pipeline"
  cloud_scheduler_parameters = var.cloud_scheduler_parameters

  # Regular environment variables
  environment_variables = {
    MY_CONFIG_OPTION = "value"
  }

  # Secret values that should be stored in Secret Manager
  secrets = [
    {
      name  = "MY_API_KEY"  # Will be available as this env var name
      value = var.api_key   # Sensitive value to store
    }
  ]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| project_id | The GCP project ID | `string` | n/a | yes |
| region | The region to deploy resources to | `string` | n/a | yes |
| data_bucket_name | Name of the GCS bucket where data will be stored | `string` | n/a | yes |
| service_account_email | Service account email for the Cloud Function | `string` | n/a | yes |
| pipeline_name | Name of the pipeline (e.g., 'notion_pipeline') | `string` | n/a | yes |
| entry_point | Entry point for the cloud function | `string` | n/a | yes |
| environment_variables | Environment variables for the cloud function | `map(string)` | `{}` | no |
| secrets | List of secret values to store in Secret Manager | `list(object)` | `[]` | no |
| cloud_scheduler_parameters | Configuration for cloud scheduler | `object` | n/a | yes |
| function_config | Configuration for cloud function | `object` | Default config | no |
| log_level | Log level for the runtime | `string` | `"WARNING"` | no |

### Secret Management

The module creates Secret Manager secrets for each item in the `secrets` list. These are then made available to the Cloud Function as environment variables with the specified names.

For example, if you specify:

```hcl
secrets = [
  {
    name  = "API_KEY"
    value = "my-secret-key"
  }
]
```

The module will:

1. Create a secret in Secret Manager named `PIPELINE_NAME_API_KEY`
2. Store the value `my-secret-key` in the secret
3. Make it available to the Cloud Function as an environment variable named `API_KEY`

## Outputs

| Name | Description |
|------|-------------|
| function_uri | URI of the deployed cloud function |
| function_name | Name of the deployed cloud function |
| scheduler_job_name | Name of the cloud scheduler job |
| scheduler_service_account_email | Service account email used by the cloud scheduler |

## Resource Naming

The module uses standardized resource naming conventions:

- Cloud Function: `pipeline-name` (hyphens instead of underscores)
- Service Accounts: Shortened version of pipeline name to stay within 30-character limit
- Secret Manager Secrets: `PIPELINE_NAME_SECRET_NAME` (uppercase with underscores)

## Local Development

The project includes Makefile targets for running pipelines locally. The Makefile:

1. Sets up service account impersonation
2. Configures the required environment variables for the specified pipeline
3. Runs the function locally using the functions-framework
4. Resets credentials after execution

```bash
# From project root directory
make run-<service>-dev     # Run in development environment
make run-<service>-prod    # Run in production environment

# Examples:
make run-notion-dev        # Run Notion pipeline locally (dev)
make run-gsheets-prod      # Run Google Sheets pipeline locally (prod)
make run-data-explorer-dev # Run data explorer locally (dev)
```

**Note:** When adding a new pipeline, update the Makefile's case statement to include your pipeline's specific environment variables.
