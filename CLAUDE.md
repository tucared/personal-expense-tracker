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

## Development Commands

Use `make help` to see all available commands. Key workflows:

- **Local development**: `make run-<service>-<env>` (connects to cloud infrastructure)
- **Infrastructure**: `make apply-<env>`, `make plan-<env>`, `make destroy-<env>`
- **Data access**: `make init-duckdb-<env>` then `duckdb <env>.duckdb` (interactive SQL queries)
- **Pipeline triggers**: `make trigger-<service>-<env>`
- **Dashboard**: `make open-dashboard-<env>`

Available services: `notion`, `gsheets`, `data-explorer`
Available environments: `dev`, `prod`

### DuckDB Data Analysis

The `make init-duckdb-<env>` commands automatically configure GCS access and create views for your parquet data (`raw.expenses`, `raw.monthly_category_amounts`, `raw.rate`). Example queries:

```sql
-- View all tables
SHOW ALL TABLES;

-- View recent expenses
SELECT * FROM raw.expenses ORDER BY created_time DESC LIMIT 10;

-- Analyze spending by category
SELECT properties__category__select__name, SUM(properties__amount__number) as total
FROM raw.expenses GROUP BY properties__category__select__name;
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

### Data Analysis Workflow

For ad-hoc data analysis and debugging:

1. Initialize database: `make init-duckdb-dev` or `make init-duckdb-prod`
2. Access data lake: Use DuckDB MCP tool for SQL queries (preferred) or `duckdb dev.duckdb`/`duckdb prod.duckdb` CLI
3. Query parquet files using standard SQL without needing to run the dashboard
4. Ideal for data exploration, debugging pipeline outputs, and creating new analytics queries
5. When using CLI, exit DuckDB with `.exit` or Ctrl+D

#### MCP Data Analysis

When working with local dev data, use the MCP DuckDB dev tool to query CSV files directly using `read_csv()`:

- `SELECT * FROM read_csv('docs/dev_data/expenses.csv')` - expense transactions with currency conversion
- `SELECT * FROM read_csv('docs/dev_data/monthly_category_amounts.csv')` - budget allocations by category  
- `SELECT * FROM read_csv('docs/dev_data/rate.csv')` - exchange rate data
- Take inspiration from `opentofu/modules/data_explorer/src/reports/expense_analysis.py` for data transformation patterns

### Data Flow

1. Cloud Scheduler triggers Cloud Functions hourly (configurable)
2. Functions extract data from Notion/Google Sheets using DLT
3. Data is stored as Parquet files in Cloud Storage
4. Streamlit dashboard queries data using DuckDB for analytics
5. Direct data access available via DuckDB CLI for analysis and debugging

### Authentication & Security

- Dashboard uses streamlit-authenticator with credentials stored in Secret Manager
- Service account authentication for all GCP services
- Local development uses service account impersonation
- API keys and secrets managed through Google Secret Manager
- DuckDB commands automatically configure GCS access using HMAC credentials from infrastructure
