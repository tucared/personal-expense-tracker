terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "5.0.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.5.1"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "2.4.0"
    }
  }
}

provider "google" {
  alias = "impersonation"
  scopes = [
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/userinfo.email",
  ]
}

data "google_service_account_access_token" "default" {
  provider               = google.impersonation
  target_service_account = local.tofu_service_account
  scopes                 = ["userinfo-email", "cloud-platform"]
  lifetime               = "1200s"
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone

  access_token    = data.google_service_account_access_token.default.access_token
  request_timeout = "60s"
}
