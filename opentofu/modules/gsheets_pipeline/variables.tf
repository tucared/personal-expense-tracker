# Shared variables - these are passed through to the base_pipeline module
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

variable "cloud_scheduler_parameters" {
  description = "Configuration for cloud scheduler"
  type = object({
    schedule = string
    region   = string
    paused   = bool
  })
}

# Pipeline-specific variables
variable "data_bucket_writer_private_key" {
  description = "Private key for the service account (for Google Sheets authentication)"
  type        = string
  sensitive   = true
}

variable "spreadsheet_url_or_id" {
  description = "Google Sheets spreadsheet URL or ID"
  type        = string
}
