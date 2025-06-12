# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Personal Expense Tracker that creates a data lakehouse for tracking expenses logged in Notion against budgets managed in Google Sheets. The system uses a modular cloud-native architecture on GCP with three main components:

1. **Data Pipelines**: Automated ingestion from Notion and Google Sheets using Cloud Functions
2. **Data Storage**: Parquet files stored in Cloud Storage forming a data lake
3. **Analytics Dashboard**: Streamlit app deployed on Cloud Run for expense visualization

## Architecture

The system follows a modular pipeline pattern:

- **Base Pipeline Module** (`opentofu/modules/base_pipeline/`): Reusable infrastructure for any data pipeline including Cloud Functions, schedulers, and secret management
- **Pipeline Implementations**: Specific modules for Notion (`notion_pipeline`) and Google Sheets (`gsheets_pipeline`) that extend the base pipeline
- **Data Explorer** (`data_explorer`): Streamlit dashboard with authentication and DuckDB analytics

All pipelines extract data from sources, transform using the DLT framework, and load into the shared data bucket as Parquet files.

## Common Development Commands

### Infrastructure Management

```bash
# Deploy to production environment
make apply-prod

# Deploy to development environment
make apply-dev

# Plan infrastructure changes
make plan-prod
make plan-dev

# Destroy infrastructure
make destroy-prod
make destroy-dev

# Get infrastructure outputs
make output-prod
make output-dev

# Get specific infrastructure outputs
make output-data_explorer_build_trigger_region-prod
make output-data_explorer_build_trigger_region-dev
```

### Local Development

```bash
# Run services locally (connects to cloud infrastructure)
make run-notion-dev          # Run Notion pipeline locally
make run-gsheets-dev         # Run Google Sheets pipeline locally
make run-data-explorer-dev   # Run Streamlit dashboard locally

# For production environment
make run-notion-prod
make run-gsheets-prod
make run-data-explorer-prod

# Trigger local functions (in separate terminal)
curl localhost:8080
```

### Manual Data Refresh

```bash
# Refresh Notion expense data
export FUNCTION_URI=$(make output-prod | grep notion_pipeline_function_uri | awk '{print $3}')
curl -i -X POST $FUNCTION_URI -H "Authorization: bearer $(gcloud auth print-identity-token)"

# Refresh Google Sheets budget data
export FUNCTION_URI=$(make output-prod | grep gsheets_pipeline_function_uri | awk '{print $3}')
curl -i -X POST $FUNCTION_URI -H "Authorization: bearer $(gcloud auth print-identity-token)"
```

## Configuration

### Environment Setup

1. Copy environment template: `cp terragrunt/{env}/env_vars.example.yaml terragrunt/{env}/env_vars.yaml`
2. Configure required variables in `env_vars.yaml`:
   - `project_id`: Unique GCP project identifier
   - `notion_pipeline.notion_api_key`: Notion integration secret
   - `notion_pipeline.notion_database_id`: Notion expense database ID
   - `gsheets_pipeline.spreadsheet_url_or_id`: Google Sheets budget template ID
   - `data_explorer.auth_username/auth_password`: Dashboard credentials

### Project Structure

- `opentofu/`: Infrastructure as code using OpenTofu/Terraform
- `terragrunt/`: Environment-specific configurations (dev/prod)
- `docs/`: Documentation and database schema definitions
- Pipeline source code is in `opentofu/modules/{pipeline_name}/src/`

## Development Notes

### Local Development Pattern

The Makefile handles service account impersonation for local development. Local services connect to cloud infrastructure (buckets, secrets) while running code locally for faster iteration.

### Pipeline Development

- All pipelines use Python with `uv` for dependency management
- Base pipeline provides common Cloud Function deployment, scheduling, and secret management
- Pipeline-specific implementations only need to define their source configuration and secrets
- DLT framework handles data extraction, transformation, and loading to Parquet format

### Data Flow

1. Cloud Scheduler triggers Cloud Functions hourly (configurable)
2. Functions extract data from Notion/Google Sheets using DLT
3. Data is stored as Parquet files in Cloud Storage
4. Streamlit dashboard queries data using DuckDB for analytics

### Authentication & Security

- Dashboard uses streamlit-authenticator with credentials stored in Secret Manager
- Service account authentication for all GCP services
- Local development uses service account impersonation
- API keys and secrets managed through Google Secret Manager
