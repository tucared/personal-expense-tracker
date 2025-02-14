# Mandatory variables for the module

variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "bucket_name" {
  description = "Name of the bucket where the data is stored"
  type        = string
}

variable "notion_secret_value" {
  description = "Notion integration token with read access to database"
  type        = string
}

# Optional variables for the module

variable "region" {
  description = "Default region for creating resources"
  type        = string
  default     = "europe-west9"
}

variable "cloud_function_parameters" {
  type = object({
    name       = string
    runtime    = string
    source     = string
    entrypoint = string
  })
  default = {
    # Does not support underscores in the name
    name       = "notion-pipeline"
    runtime    = "python312"
    source     = "./modules/notion_pipeline/src"
    entrypoint = "notion_pipeline"
  }
}

variable "cloud_scheduler_parameters" {
  type = object({
    paused   = bool
    region   = string
    name     = string
    schedule = string
  })
  default = {
    paused   = false
    region   = "europe-west6"
    name     = "cloud-function-invoker"
    schedule = "0 * * * *" # every hour
  }
}

variable "gsm_notion_secret_name" {
  description = "Name of Google Secret bearing Notion integration token"
  type        = string
  default     = "NOTION_INTEGRATION_SECRET"
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
