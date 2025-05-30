variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "region" {
  description = "Default region for creating resources"
  type        = string
  default     = "europe-west9"
}

variable "zone" {
  description = "Default zone for creating resources"
  type        = string
  default     = "europe-west9-a"
}

# Notion pipeline module

variable "notion_pipeline" {
  type = object({
    notion_api_key     = string
    notion_database_id = string
    cloud_scheduler_parameters = object({
      paused   = bool
      schedule = string
      region   = string
    })
  })
}

# Google Sheets pipeline module

variable "gsheets_pipeline" {
  type = object({
    spreadsheet_url_or_id = string
    cloud_scheduler_parameters = object({
      paused   = bool
      schedule = string
      region   = string
    })
  })
}

# Data explorer module

variable "data_explorer" {
  type = object({
    # https://cloud.google.com/build/docs/locations#restricted_regions_for_some_projects
    build_region = string
    cloudrun_limits = object({
      memory = string
      cpu    = string
    })
    auth_username = string
    auth_password = string
  })
  default = {
    build_region = "europe-west1"
    cloudrun_limits = {
      memory = "1024Mi"
      cpu    = "2"
    }
    auth_username = "admin"
    auth_password = "change-me"
  }
}
