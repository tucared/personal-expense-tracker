variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The region to deploy resources to"
  type        = string
}

variable "data_bucket_name" {
  description = "Name of the GCS bucket where data will be stored"
  type        = string
}

variable "data_bucket_writer_service_account_email" {
  description = "Service account email for the Cloud Function"
  type        = string
}

variable "pipeline_name" {
  description = "Name of the pipeline (e.g., 'notion_pipeline')"
  type        = string
}

variable "entry_point" {
  description = "Entry point for the cloud function"
  type        = string
}



variable "environment_variables" {
  description = "Environment variables to set for the cloud function"
  type        = map(string)
  default     = {}
}

variable "secrets" {
  description = "Mapping of environment variable names to their secret values"
  type = list(object({
    name  = string # Environment variable name
    value = string # Secret value
  }))
  default   = []
  sensitive = true
}

variable "cloud_scheduler_parameters" {
  description = "Configuration for cloud scheduler"
  type = object({
    schedule = string
    region   = string
    paused   = bool
  })
}

variable "function_config" {
  description = "Configuration for cloud function"
  type = object({
    max_instance_count = number
    available_memory   = string
    timeout_seconds    = number
  })
  default = {
    max_instance_count = 1
    available_memory   = "256Mi"
    timeout_seconds    = 600
  }
}

variable "loader_file_format" {
  description = "File format for the loader (e.g., 'parquet')"
  type        = string
  default     = "parquet"
}

variable "log_level" {
  description = "Log level for the runtime"
  type        = string
  default     = "WARNING"
}
