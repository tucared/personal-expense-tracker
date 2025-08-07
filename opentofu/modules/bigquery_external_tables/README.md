# BigQuery External Tables Module

Creates BigQuery external tables that provide SQL access to parquet files stored in Google Cloud Storage, enabling direct querying of expense data without data duplication.

## Overview

This module creates:
- BigQuery dataset (`raw`) for external tables
- External tables pointing to parquet files in GCS:
  - `expenses` - Notion expense data
  - `monthly_category_amounts` - Google Sheets budget data  
  - `rate` - Currency exchange rates

## Usage

```hcl
module "bigquery_external_tables" {
  source = "./modules/bigquery_external_tables"
  
  project_id       = var.project_id
  region          = var.region
  data_bucket_name = module.data_bucket.name
}
```

## Inputs

| Name | Description | Type | Required |
|------|-------------|------|----------|
| project_id | GCP project ID | string | yes |
| region | GCP region | string | yes |
| data_bucket_name | GCS bucket containing parquet files | string | yes |

## Outputs

| Name | Description |
|------|-------------|
| dataset_id | BigQuery dataset ID |
| dataset_project | BigQuery dataset project |
| expenses_table_id | Expenses table ID |
| monthly_category_amounts_table_id | Budget table ID |
| rate_table_id | Exchange rate table ID |

## Data Schema

Tables automatically map to parquet file schemas with predefined column definitions for consistent querying.

## Prerequisites

- BigQuery API enabled
- Parquet files present in specified GCS bucket paths
- Appropriate IAM permissions for BigQuery access