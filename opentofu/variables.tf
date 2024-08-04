variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "notion_database_id" {
  description = "Notion database ID data is fetched from"
  type        = string
}

variable "notion_secret_value" {
  description = "Notion integration token with read access to database"
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

variable "destination_blob_name_state_file" {
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
    runtime    = "python312"
    source     = "cloud-function/source"
  }
}

variable "cloud_schedulers_parameters" {
  type = object({
    paused = bool
    region = string
    append_scheduler = object({
      name     = string
      schedule = string
    })
    full_refresh_scheduler = object({
      name     = string
      schedule = string
    })
  })
  default = {
    paused = false
    region = "europe-west6"
    append_scheduler = {
      name     = "cloud-function-invoker-append"
      schedule = "0 * * * *" # every hour
    }
    full_refresh_scheduler = {
      name     = "cloud-function-invoker-full-refresh"
      schedule = "30 0 * * *" # every day at 00:30 UTC
    }
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

# https://cloud.google.com/build/docs/locations#restricted_regions_for_some_projects
variable "region_streamlit_build" {
  description = "Region where Streamlit image is built"
  type        = string
  default     = "europe-west1"
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

variable "sa_tofu" {
  description = "Used when running OpenTofu commands"
  type        = string
  default     = "tofu-sa"
}

variable "zone" {
  description = "Default zone for creating resources"
  type        = string
  default     = "europe-west9-a"
}

variable "streamlit_cloudrun_limits" {
  type = object({
    cpu    = string
    memory = string
  })
  default = {
    cpu    = "2"
    memory = "1024Mi"
  }
}

variable "streamlit_artifact_registry" {
  description = "Artifact Registry containing Streamlit image"
  type        = string
  default     = "streamlit"
}

locals {
  bq_table_id          = join(".", [var.project_id, var.bq_dataset_id, var.bq_notion_table_name])
  tofu_service_account = "${var.sa_tofu}@${var.project_id}.iam.gserviceaccount.com"
}
