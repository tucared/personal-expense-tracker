variable "notion_database_id" {
  description = "Notion database ID data is fetched from"
  type        = string
}

variable "notion_secret_value" {
  description = "Notion integration token with read access to database"
  type        = string
}

variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "bq_dataset_id" {
  description = "ID of BigQuery dataset containing Notion raw data loaded from Cloud Function"
  type        = string
  default     = "budget"
}

variable "bq_location" {
  description = "Location of all BigQuery ressources"
  type        = string
  default     = "EU"
}

variable "bq_notion_table_name" {
  description = "Name of native table containing Notion raw data loaded from Cloud Function"
  type        = string
  default     = "raw_transactions__duplicated"
}

variable "destination_state_file" {
  description = "Path to file containing timestamp of last Cloud Function run"
  type        = string
  default     = "last_update_time.txt"
}

variable "cloud_function_parameters" {
  type = object({
    entrypoint = string
    name       = string
    runtime    = string
    source     = string
  })
  default = {
    entrypoint = "insert_notion_pages_to_bigquery"
    name       = "notion-to-bigquery"
    runtime    = "python311"
    source     = "cloud-functions/notion-to-bigquery"
  }
}

variable "cloud_scheduler_parameters" {
  type = object({
    count    = number
    name     = string
    schedule = string
    region   = string
  })
  default = {
    count    = 1
    name     = "cloud-function-invoker"
    schedule = "0 * * * *"
    region   = "europe-west6"
  }
}

variable "gsm_notion_secret_name" {
  description = "Name of Google Secret bearing Notion integration token"
  type        = string
  default     = "NOTION_INTEGRATION_SECRET"
}

variable "region" {
  description = "Default region for creating resources"
  type        = string
  default     = "europe-west9"
}

variable "sa_account_id_cloud_function" {
  description = "ID of service account used for running Cloud Function"
  type        = string
  default     = "sa-cloud-function"
}

variable "sa_account_id_cloud_scheduler" {
  description = "ID of service account used by Cloud Scheduler when invoking Cloud Function"
  type        = string
  default     = "sa-cloud-scheduler"
}

variable "zone" {
  description = "Default zone for creating resources"
  type        = string
  default     = "europe-west9-a"
}

locals {
  bq_table_id = join(".", [var.project_id, var.bq_dataset_id, var.bq_notion_table_name])
}