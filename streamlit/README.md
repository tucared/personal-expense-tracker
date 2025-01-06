# Streamlit App

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

## Running with access to cloud storage bucket

1. Deploy your infrastructure on the cloud (and refresh dataset)

    ```shell
    cd terragrunt/dev
    tg apply              # More detail in root README.md
    curl -i -X POST $(terragrunt output function_uri | sed 's/"//g')\?full_refresh=true \
        -H "Authorization: bearer $(gcloud auth print-identity-token)"
    ```

2. Start local server by passing deployed cloud run service account credentials (docker env not supported yet)

    ```shell
    GCS_BUCKET_NAME=$(terragrunt output bucket_name_cloud_function | sed 's/"//g') \
    HMAC_ACCESS_ID=$(terragrunt output hmac_access_id | sed 's/"//g') \
    HMAC_SECRET=$(terragrunt output hmac_secret | sed 's/"//g') \
    uv run --directory="../../streamlit" streamlit run app.py
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
