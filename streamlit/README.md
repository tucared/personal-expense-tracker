# Streamlit App

> **Warning**: This app does not support querying struct data from BigQuery tables. There are no plans to implement this feature as the storage medium will be migrated from BigQuery to flat files (Parquet) in Cloud Storage.

## Setup

1. Install [`uv`](https://github.com/astral-sh/uv?tab=readme-ov-file#installation) if not done already

2. Setup virtual env

    ```shell
    uv sync
    ```

## Running locally without dependencies

1. Start server
   - In python environment: `uv run streamlit run app.py`
   - In dockerised environment: `docker-compose up --build`

2. Go to <http://localhost:8501/>
   - Username: `rbriggs`
   - Password: `abc` (hashed in `config.yaml`)

## Running with BigQuery connection

1. Deploy your infrastructure on the cloud (and refresh dataset)

    ```shell
    cd terragrunt/dev
    tg apply              # More detail in root README.md
    curl -i -X POST $(terragrunt output function_uri | sed 's/"//g')\?full_refresh=true \
        -H "Authorization: bearer $(gcloud auth print-identity-token)"
    ```

2. Download service account key file used for Cloud Function.

    ```shell
    export GOOGLE_APPLICATION_CREDENTIALS_PATH=../../streamlit/secret/$(echo "${PWD##*/}")_sa-key.json
    gcloud iam service-accounts keys create $GOOGLE_APPLICATION_CREDENTIALS_PATH \
        --iam-account=$(terragrunt output sa_email_streamlit_cloud_run | sed 's/"//g')
    ```

3. Start local server by passing deployed cloud run service account credentials

    ```shell
    export GOOGLE_APPLICATION_CREDENTIALS_PATH=/secret/$(echo "${PWD##*/}")_sa-key.json
    export BQ_PROJECT_ID=$(grep "project_id" env_vars.yaml | awk '{print $2}' | tr -d '"')
    export BQ_DATASET_ID=$(grep "bq_dataset_id" env_vars.yaml | awk '{print $2}' | tr -d '"')

    uv run --directory="../../streamlit" streamlit run app.py
    # docker env not supported yet
    ```

## Editing

- Check linting and type errors

    ```shell
    uv run ruff check
    uv run mypy app.py
    ```

- Run formatter and fix linting errors

    ```shell
    uv run ruff format
    uv run ruff check --fix
    ```

- Add/remove dependency
  
    ```shell
    uv add pandas
    uv remove pandas

    uv add ruff --dev
    uv remove ruff --dev
    ```
