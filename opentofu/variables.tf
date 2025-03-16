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
    notion_api_key = string
    cloud_scheduler_parameters = object({
      paused   = bool
      schedule = string
      region   = string
    })
  })
}

# Streamlit module

variable "streamlit" {
  type = object({
    # https://cloud.google.com/build/docs/locations#restricted_regions_for_some_projects
    build_region = string
    cloudrun_limits = object({
      memory = string
      cpu    = string
    })
  })
  default = {
    build_region = "europe-west1"
    cloudrun_limits = {
      memory = "1024Mi"
      cpu    = "2"
    }
  }
}
