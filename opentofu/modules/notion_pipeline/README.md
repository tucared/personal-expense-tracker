# Notion pipeline (using DLT)

Running Cloud Function locally with `uv` and [`functions-framework`](https://github.com/GoogleCloudPlatform/functions-framework-python)

## Pre-requisites

- Have [`uv`](https://github.com/astral-sh/uv?tab=readme-ov-file#installation) installed

- Having deployed your infrastructure with 'terragrunt apply', preferably with paused Cloud Schedulers to avoid interference

    ```yaml
    # terragrunt/dev/env_vars.yaml
    notion_pipeline:
        cloud_scheduler_parameters:
            paused: true
    ```

## Running locally

1. Navigate to `terragrunt/` subfolder corresponding to your project.

    ```shell
    cd terragrunt/dev
    ```

2. Start local server.

    ```shell
    # Get the service account email
    SERVICE_ACCOUNT=$(terragrunt output notion_pipeline_function_service_account_email | sed 's/"//g')

    # Impersonate the service account
    gcloud config set auth/impersonate_service_account $SERVICE_ACCOUNT

    # Run with minimal environment variables
    SOURCE=../../opentofu/modules/notion_pipeline/src/
    SOURCES__NOTION__API_KEY=$(yq -r '.notion_pipeline.notion_api_key' env_vars.yaml) \
    DESTINATION__FILESYSTEM__BUCKET_URL=gs://$(terragrunt output bucket_name | sed 's/"//g') \
    NORMALIZE__LOADER_FILE_FORMAT="parquet" \
    RUNTIME__LOG_LEVEL="DEBUG" \
    RUNTIME__DLTHUB_TELEMETRY=false \
    uv run --directory="../../opentofu/modules/notion_pipeline/src/" \
        functions-framework \
        --target=notion_pipeline \
        --debug

    # Reset impersonation to use your default credentials for Terraform
    gcloud config unset auth/impersonate_service_account
    ```

    > Source changes are automatically loaded to local server, meaning you can code the function and invoking its latest version without restarting the local server.

3. Open another shell, and invoke function locally.

    ```shell
    curl localhost:8080
    ```

## Export to requirements.txt for Cloud Function deployment

```shell
cd opentofu/modules/notion_pipeline/src
uv export --format requirements-txt > requirements.txt
# or run pre commits
```
