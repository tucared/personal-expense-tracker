# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal Expense Tracker: A data lakehouse for tracking expenses logged in Notion against budgets managed in Google Sheets. Cloud-native GCP architecture with automated data pipelines and Streamlit analytics dashboard.

**Initial Setup**: See README.md for one-time environment configuration and deployment.

## Daily Development Workflows

### Pipeline Development

Iterate on data pipeline code locally while connecting to cloud infrastructure:

```bash
# Local development servers (connects to cloud secrets/storage)
make run-notion-dev    # Starts local server to curl/test Notion pipeline
make run-gsheets-dev   # Starts local server to curl/test Google Sheets pipeline

# Test changes
make trigger-notion-dev   # Trigger pipeline in cloud
make trigger-gsheets-dev  # Trigger pipeline in cloud
```

### Data Explorer Development

Develop the Streamlit dashboard locally:

```bash
make run-data-explorer-dev    # Starts local Streamlit GUI server
make open-dashboard-dev       # Access deployed dashboard
```

### Data Analysis

Use MCP DuckDB tool for all data queries and analysis:

**Cloud Data (duckdb-gcs-prod/duckdb-gcs-dev):**

```sql
-- Production/dev data from GCS
SELECT * FROM raw.expenses ORDER BY created_time DESC LIMIT 10;
SELECT properties__category__select__name, SUM(properties__amount__number) as total
FROM raw.expenses GROUP BY properties__category__select__name;
```

**Development Seed Data (duckdb-gcs-dev):**

```sql
-- CSV files seeded to dev GCS deployment
SELECT * FROM read_csv('docs/dev_data/expenses.csv');
SELECT * FROM read_csv('docs/dev_data/monthly_category_amounts.csv');
SELECT * FROM read_csv('docs/dev_data/rate.csv');
```

Reference `opentofu/modules/data_explorer/src/reports/expense_tracker.py` for data transformation patterns.

## Infrastructure Management

**Make Commands (Recommended):**

```bash
make apply-dev     # Deploy dev environment
make plan-dev      # Preview dev changes
make destroy-dev   # Destroy dev environment

make apply-prod    # Deploy production
make destroy-prod  # Destroy production
```

**Code Quality Commands:**

```bash
make lint          # Run linting across all Python modules
make format        # Format code across all Python modules
make install       # Install dependencies for all modules
make clean         # Clean temporary files and databases

# Per-module commands
make lint-notion           # Lint specific module
make format-data-explorer  # Format specific module
```

**Direct Terragrunt (More Flexibility):**

```bash
cd terragrunt/dev && terragrunt apply
cd terragrunt/prod && terragrunt plan
```

## Architecture

**Modular Pipeline Pattern:**

- **Base Pipeline Module** (`opentofu/modules/base_pipeline/`): Reusable Cloud Functions, schedulers, secrets
- **Pipeline Implementations**: `notion_pipeline`, `gsheets_pipeline` extend base module
- **Data Explorer**: Streamlit dashboard with authentication and DuckDB analytics

**Data Flow:**

1. Cloud Scheduler triggers Cloud Functions hourly
2. DLT framework extracts from Notion/Google Sheets
3. Parquet files stored in Cloud Storage data lake
4. Streamlit dashboard queries via DuckDB

## Development Patterns

**Local Development:**

- Makefile handles service account impersonation
- Local code connects to cloud infrastructure (secrets, storage)
- Use `uv` for all Python commands: `uv run mypy`, `uv run ruff format`
- **Never edit pyproject.toml dependencies directly**: Use `uv add <package>` or `uv add --dev <package>` instead

**Pipeline Development:**

- All pipelines use Python with `uv` dependency management
- Base pipeline handles common deployment, scheduling, secrets
- Pipeline-specific modules only define source configuration

**Project Structure:**

```text
opentofu/                    # Infrastructure as code
├── modules/base_pipeline/   # Reusable pipeline infrastructure
├── modules/notion_pipeline/ # Notion-specific implementation
├── modules/gsheets_pipeline/# Google Sheets implementation
└── modules/data_explorer/   # Streamlit dashboard
terragrunt/{env}/           # Environment configurations
docs/                       # Database schemas and dev data
```

**Available Services:** `notion`, `gsheets`, `data-explorer`
**Available Environments:** `dev`, `prod`
