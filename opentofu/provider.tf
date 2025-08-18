terraform {
  backend "gcs" {}

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "6.48.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "3.7.2"
    }

    archive = {
      source  = "hashicorp/archive"
      version = "2.7.1"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
  zone    = var.zone
}
