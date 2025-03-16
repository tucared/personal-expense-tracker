# Streamlit App

Running app locally with `uv` or `docker`.

## Pre-requisites

- Have [`uv`](https://github.com/astral-sh/uv?tab=readme-ov-file#installation) or [a docker engine](https://docs.orbstack.dev/install) installed

- Having deployed your infrastructure with 'terragrunt apply' if running with Cloud Storage access, and [load dataset](README.md#Triggering-Data-Ingestion) if not done already

## Running locally

### Without impersonation or access to Cloud Storage data bucket

1. Navigate to folder

    ```shell
    cd ../../opentofu/modules/streamlit/src/
    ```

2. Start server
   - In python environment: `uv run streamlit run app.py`
   - In dockerised environment: `docker-compose up --build`

3. Go to <http://localhost:8501/>
   - Username: `rbriggs`
   - Password: `abc` (hashed in `config.yaml`)

### With access to Cloud Storage bucket and Cloud Run impersonation

1. Navigate to `terragrunt/` subfolder corresponding to your project.

    ```shell
    cd terragrunt/dev
    ```

2. Start local server by passing deployed cloud run service account credentials (docker env not supported yet)

    ```shell
    # Get the service account email
    SERVICE_ACCOUNT=$(terragrunt output streamlit_service_account_email | sed 's/"//g')

    # Impersonate the service account
    gcloud config set auth/impersonate_service_account $SERVICE_ACCOUNT

    # Run with minimal environment variables
    GCS_BUCKET_NAME=$(terragrunt output bucket_name | sed 's/"//g') \
    HMAC_ACCESS_ID=$(terragrunt output streamlit_hmac_access_id | sed 's/"//g') \
    HMAC_SECRET=$(terragrunt output streamlit_hmac_secret | sed 's/"//g') \
    uv run --directory="../../opentofu/modules/streamlit/src/" \
        streamlit run app.py

    # Reset impersonation to use your default credentials for Terraform
    gcloud config unset auth/impersonate_service_account
    ```
