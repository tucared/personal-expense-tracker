locals {
  gcs_path_prefix = "gs://${var.data_bucket_name}/raw"
}

# Enable BigQuery API
resource "google_project_service" "bigquery" {
  service = "bigquery.googleapis.com"
}

# Create BigQuery dataset
resource "google_bigquery_dataset" "raw" {
  dataset_id                 = "raw"
  friendly_name              = "Raw Data External Tables"
  description                = "External tables pointing to parquet files in GCS"
  location                   = var.region
  delete_contents_on_destroy = false

  depends_on = [google_project_service.bigquery]
}

# External table for expenses
resource "google_bigquery_table" "expenses" {
  dataset_id          = google_bigquery_dataset.raw.dataset_id
  table_id            = "expenses"
  deletion_protection = false

  external_data_configuration {
    autodetect    = false
    source_format = "PARQUET"
    source_uris   = ["${local.gcs_path_prefix}/expenses/data.parquet"]

    schema = jsonencode([
      { name = "object", type = "STRING", mode = "NULLABLE" },
      { name = "id", type = "STRING", mode = "NULLABLE" },
      { name = "created_time", type = "TIMESTAMP", mode = "NULLABLE" },
      { name = "last_edited_time", type = "TIMESTAMP", mode = "NULLABLE" },
      { name = "created_by__object", type = "STRING", mode = "NULLABLE" },
      { name = "created_by__id", type = "STRING", mode = "NULLABLE" },
      { name = "last_edited_by__object", type = "STRING", mode = "NULLABLE" },
      { name = "last_edited_by__id", type = "STRING", mode = "NULLABLE" },
      { name = "parent__type", type = "STRING", mode = "NULLABLE" },
      { name = "parent__database_id", type = "STRING", mode = "NULLABLE" },
      { name = "archived", type = "BOOL", mode = "NULLABLE" },
      { name = "in_trash", type = "BOOL", mode = "NULLABLE" },
      { name = "properties__amount_brl__id", type = "STRING", mode = "NULLABLE" },
      { name = "properties__amount_brl__type", type = "STRING", mode = "NULLABLE" },
      { name = "properties__amount__id", type = "STRING", mode = "NULLABLE" },
      { name = "properties__amount__type", type = "STRING", mode = "NULLABLE" },
      { name = "properties__amount__number", type = "FLOAT64", mode = "NULLABLE" },
      { name = "properties__mean__id", type = "STRING", mode = "NULLABLE" },
      { name = "properties__mean__type", type = "STRING", mode = "NULLABLE" },
      { name = "properties__credit__id", type = "STRING", mode = "NULLABLE" },
      { name = "properties__credit__type", type = "STRING", mode = "NULLABLE" },
      { name = "properties__credit__checkbox", type = "BOOL", mode = "NULLABLE" },
      { name = "properties__category__id", type = "STRING", mode = "NULLABLE" },
      { name = "properties__category__type", type = "STRING", mode = "NULLABLE" },
      { name = "properties__category__select__id", type = "STRING", mode = "NULLABLE" },
      { name = "properties__category__select__name", type = "STRING", mode = "NULLABLE" },
      { name = "properties__category__select__color", type = "STRING", mode = "NULLABLE" },
      { name = "properties__debit_credit__id", type = "STRING", mode = "NULLABLE" },
      { name = "properties__debit_credit__type", type = "STRING", mode = "NULLABLE" },
      { name = "properties__debit_credit__formula__type", type = "STRING", mode = "NULLABLE" },
      { name = "properties__debit_credit__formula__number", type = "FLOAT64", mode = "NULLABLE" },
      { name = "properties__date__id", type = "STRING", mode = "NULLABLE" },
      { name = "properties__date__type", type = "STRING", mode = "NULLABLE" },
      { name = "properties__date__date__start", type = "DATE", mode = "NULLABLE" },
      { name = "properties__name__id", type = "STRING", mode = "NULLABLE" },
      { name = "properties__name__type", type = "STRING", mode = "NULLABLE" },
      { name = "url", type = "STRING", mode = "NULLABLE" },
      { name = "public_url", type = "STRING", mode = "NULLABLE" },
      { name = "_dlt_load_id", type = "STRING", mode = "NULLABLE" },
      { name = "_dlt_id", type = "STRING", mode = "NULLABLE" },
      { name = "properties__amount_brl__number", type = "FLOAT64", mode = "NULLABLE" },
      { name = "properties__mean__select__id", type = "STRING", mode = "NULLABLE" },
      { name = "properties__mean__select__name", type = "STRING", mode = "NULLABLE" },
      { name = "properties__mean__select__color", type = "STRING", mode = "NULLABLE" },
      { name = "properties__amount_brl__number__v_double", type = "FLOAT64", mode = "NULLABLE" }
    ])
  }
}

# External table for monthly_category_amounts
resource "google_bigquery_table" "monthly_category_amounts" {
  dataset_id          = google_bigquery_dataset.raw.dataset_id
  table_id            = "monthly_category_amounts"
  deletion_protection = false

  external_data_configuration {
    autodetect    = false
    source_format = "PARQUET"
    source_uris   = ["${local.gcs_path_prefix}/monthly_category_amounts/data.parquet"]

    schema = jsonencode([
      { name = "month", type = "DATE", mode = "NULLABLE" },
      { name = "category", type = "STRING", mode = "NULLABLE" },
      { name = "budget_eur", type = "FLOAT64", mode = "NULLABLE" },
      { name = "_dlt_load_id", type = "STRING", mode = "NULLABLE" },
      { name = "_dlt_id", type = "STRING", mode = "NULLABLE" }
    ])
  }
}

# External table for rate
resource "google_bigquery_table" "rate" {
  dataset_id          = google_bigquery_dataset.raw.dataset_id
  table_id            = "rate"
  deletion_protection = false

  external_data_configuration {
    autodetect    = false
    source_format = "PARQUET"
    source_uris   = ["${local.gcs_path_prefix}/rate/data.parquet"]

    schema = jsonencode([
      { name = "date", type = "DATE", mode = "NULLABLE" },
      { name = "eur_brl", type = "FLOAT64", mode = "NULLABLE" },
      { name = "date_month", type = "DATE", mode = "NULLABLE" },
      { name = "_dlt_load_id", type = "STRING", mode = "NULLABLE" },
      { name = "_dlt_id", type = "STRING", mode = "NULLABLE" }
    ])
  }
}