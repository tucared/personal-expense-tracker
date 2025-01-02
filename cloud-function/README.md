
# Cloud Function

Running Cloud Function locally with [`functions-framework`]

## Pre-requisites

- Having deployed your infrastructure with 'terragrunt apply' with paused Cloud Schedulers

    ```yaml
    # terragrunt/dev/env_vars.yaml
    cloud_schedulers:
        paused: true
    ```

## Setup

1. Navigate to `terragrunt/` subfolder corresponding to test infrastructure.

    ```shell
    cd terragrunt/dev
    ```

2. Download service account key file used for Cloud Function.

    ```shell
    export GOOGLE_APPLICATION_CREDENTIALS_PATH=../../cloud-function/secret/$(echo "${PWD##*/}")_sa-key.json
    gcloud iam service-accounts keys create $GOOGLE_APPLICATION_CREDENTIALS_PATH \
        --iam-account=$(terragrunt output sa_email_cloud_function | sed 's/"//g')
    ```

3. [Create a virtual environment and] install dependencies.

    ```shell
    export SOURCE=../../cloud-function/source
    pip install -r $SOURCE/requirements.txt
    pip install -r $SOURCE/requirements.local.txt
    ```

## Running

1. Navigate to `terragrunt/` subfolder corresponding to run cloud function.

    ```shell
    cd terragrunt/dev
    ```

2. Start local server.

    ```shell
    export GOOGLE_APPLICATION_CREDENTIALS_PATH=../../cloud-function/secret/$(echo "${PWD##*/}")_sa-key.json
    export PROJECT_ID=$(grep "project_id" env_vars.yaml | awk '{print $2}' | tr -d '"')
    export ENTRYPOINT=$(grep "entrypoint" ../common_vars.yaml | awk '{print $2}' | tr -d '"')
    export SOURCE=../../cloud-function/source

    export TG_OUTPUT=$(tg output -json function_env_vars)
    eval "$(echo "$TG_OUTPUT" | jq -r 'to_entries | .[] | "export \(.key)=\"\(.value)\""')"

    GOOGLE_APPLICATION_CREDENTIALS=$(echo $GOOGLE_APPLICATION_CREDENTIALS_PATH) \
    GOOGLE_CLOUD_PROJECT=$(echo $PROJECT_ID) \
    DATA_FILE_PATH=../../cloud-function/data/$(echo "${PWD##*/}")_notion.json \
    functions-framework \
        --target=$ENTRYPOINT \
        --source=$SOURCE/main.py \
        --debug
    ```

    > Source changes are automatically loaded to local server, meaning you can code the function and invoking its latest version without restarting the local server.

3. Open another shell, and invoke function locally.

    ```shell
    # Append strategy
    curl localhost:8080

    # Full refresh strategy
    curl "localhost:8080?full_refresh=true"
    ```

[`functions-framework`]: https://github.com/GoogleCloudPlatform/functions-framework-python
