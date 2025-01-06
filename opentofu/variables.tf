variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "notion_secret_value" {
  description = "Notion integration token with read access to database"
  type        = string
}

variable "cloud_function_parameters" {
  type = object({
    name    = string
    runtime = string
    source  = string
  })
  default = {
    name    = "notion_pipeline"
    runtime = "python312"
    source  = "streamlit"
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

variable "zone" {
  description = "Default zone for creating resources"
  type        = string
  default     = "europe-west9-a"
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
  tofu_service_account = "${var.sa_tofu}@${var.project_id}.iam.gserviceaccount.com"
}
