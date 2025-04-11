variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Default region for creating resources"
  type        = string
  default     = "europe-west9"
}

variable "data_bucket_name" {
  description = "Name of the bucket where the data is stored"
  type        = string
}

variable "data_bucket_writer_service_account_email" {
  description = "Service account used to write to the data bucket"
  type        = string
}

variable "cloud_scheduler_parameters" {
  type = object({
    paused   = bool
    schedule = string
    region   = string
  })
  default = {
    paused   = false
    schedule = "0 * * * *" # every hour
    region   = "europe-west6"
  }
}

variable "notion_api_key" {
  description = "Notion integration token with read access to database"
  type        = string
}
