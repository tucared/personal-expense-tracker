# DLT pipeline

Running Cloud Function locally with [`functions-framework`]

## Pre-requisites

- Having deployed your infrastructure with 'terragrunt apply' with paused Cloud Schedulers

    ```yaml
    # terragrunt/dev/env_vars.yaml
    notion_pipeline:
        cloud_scheduler_parameters:
            paused: true
    ```

## Setup

1. Navigate to `terragrunt/` subfolder corresponding to test infrastructure.

    ```shell
    cd terragrunt/dev
    ```

2. Download service account key file used for Cloud Function.

    ```shell
    export GOOGLE_APPLICATION_CREDENTIALS_PATH=../../notion_pipeline/secret/$(echo "${PWD##*/}")_sa-key.json
    gcloud iam service-accounts keys create $GOOGLE_APPLICATION_CREDENTIALS_PATH \
        --iam-account=$(terragrunt output sa_email_cloud_function | sed 's/"//g')
    ```

3. Install dependencies.

    ```shell
    uv sync
    ```

## Running

1. Navigate to `terragrunt/` subfolder corresponding to run cloud function.

    ```shell
    cd terragrunt/dev
    ```

2. Start local server.

    ```shell
    export SOURCE=../../notion_pipeline/src/
    export GOOGLE_APPLICATION_CREDENTIALS_PATH=$SOURCE/secret/$(echo "${PWD##*/}")_sa-key.json

    SOURCES__NOTION__API_KEY=$(yq -r '.notion_pipeline.notion_secret_value' env_vars.yaml) \
    DESTINATION__FILESYSTEM__BUCKET_URL=gs://$(terragrunt output bucket_name | sed 's/"//g') \
    DESTINATION__FILESYSTEM__CREDENTIALS__CLIENT_EMAIL=$(cat $GOOGLE_APPLICATION_CREDENTIALS_PATH | jq -r '.client_email') \
    DESTINATION__FILESYSTEM__CREDENTIALS__PRIVATE_KEY=$(cat $GOOGLE_APPLICATION_CREDENTIALS_PATH | jq -r '.private_key') \
    DESTINATION__FILESYSTEM__CREDENTIALS__PROJECT_ID=$(cat $GOOGLE_APPLICATION_CREDENTIALS_PATH | jq -r '.project_id') \
    NORMALIZE__LOADER_FILE_FORMAT="parquet" \
    RUNTIME__LOG_LEVEL="WARNING" \
    RUNTIME__DLTHUB_TELEMETRY=false \
    uv run --directory=$SOURCE functions-framework \
        --target=notion_pipeline \
        --debug
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

[`functions-framework`]: https://github.com/GoogleCloudPlatform/functions-framework-python
