variable "project_id" {
  description = "Google Cloud project ID"
  type        = string
}

variable "data_bucket_name" {
  description = "Name of the bucket where the data is stored"
  type        = string
}

variable "region" {
  description = "Default region for creating resources"
  type        = string
  default     = "europe-west9"
}

variable "build_region" {
  description = "Cloud build configuration settings"
  type        = string
  default     = "europe-west1"
}

variable "cloudrun_limits" {
  description = "Cloud Run configuration settings"
  type = object({
    memory = string
    cpu    = string
  })
  default = {
    memory = "1024Mi"
    cpu    = "2"
  }
}

variable "auth_username" {
  description = "Username for data explorer authentication"
  type        = string
}

variable "auth_password" {
  description = "Password for data explorer authentication"
  type        = string
  sensitive   = true
}

variable "streamlit_theme_base" {
  description = "Streamlit theme base (light or dark)"
  type        = string
  default     = "light"
}
