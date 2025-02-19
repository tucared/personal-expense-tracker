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

variable "sa_tofu" {
  description = "Used when running OpenTofu commands"
  type        = string
  default     = "tofu-sa"
}

locals {
  tofu_service_account = "${var.sa_tofu}@${var.project_id}.iam.gserviceaccount.com"
}

# Notion pipeline module

variable "notion_pipeline" {
  type = object({
    notion_secret_value = string
    cloud_scheduler_parameters = object({
      paused   = bool
      schedule = string
      region   = string
    })
  })
}

# Streamlit module

# https://cloud.google.com/build/docs/locations#restricted_regions_for_some_projects
variable "region_streamlit_build" {
  description = "Region where Streamlit image is built"
  type        = string
  default     = "europe-west1"
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
