resource "google_service_account" "data_bucket_reader" {
  account_id   = "bucket-reader-sa"
  display_name = "SA to reads data from bucket"
}

resource "google_storage_bucket_iam_member" "data_bucket_reader" {
  bucket = var.data_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.data_bucket_reader.email}"
}

resource "google_storage_hmac_key" "data_bucket_reader" {
  service_account_email = google_service_account.data_bucket_reader.email
}

resource "google_secret_manager_secret" "hmac" {
  secret_id = "bucket-reader-hmac"

  labels = {
    application = "bucket-reader"
  }

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "hmac" {
  secret      = google_secret_manager_secret.hmac.id
  secret_data = google_storage_hmac_key.data_bucket_reader.secret
}

resource "google_secret_manager_secret" "auth_password" {
  secret_id = "data-explorer-auth-password"

  labels = {
    application = "data-explorer"
  }

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "auth_password" {
  secret      = google_secret_manager_secret.auth_password.id
  secret_data = var.auth_password
}

resource "random_password" "cookie_key" {
  length  = 32
  special = true
}

resource "google_secret_manager_secret" "cookie_key" {
  secret_id = "data-explorer-cookie-key"

  labels = {
    application = "data-explorer"
  }

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "cookie_key" {
  secret      = google_secret_manager_secret.cookie_key.id
  secret_data = random_password.cookie_key.result
}

# Cloud build trigger

resource "google_service_account" "cloudbuild_trigger" {
  account_id   = "cloudbuild-trigger-sa"
  display_name = "Cloud Build Trigger SA"
}

resource "google_storage_bucket_iam_member" "cloudbuild_trigger" {
  bucket = google_storage_bucket.data_explorer_source.name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.cloudbuild_trigger.email}"
}

resource "google_project_iam_member" "cloudbuild_trigger_run_admin" {
  project = var.project_id
  role    = "roles/run.admin"
  member  = "serviceAccount:${google_service_account.cloudbuild_trigger.email}"
}

resource "google_project_iam_member" "cloudbuild_trigger_artifact_registry" {
  project = var.project_id
  role    = "roles/artifactregistry.writer"
  member  = "serviceAccount:${google_service_account.cloudbuild_trigger.email}"
}

resource "google_project_iam_member" "cloudbuild_trigger_sa_user" {
  project = var.project_id
  role    = "roles/iam.serviceAccountUser"
  member  = "serviceAccount:${google_service_account.cloudbuild_trigger.email}"
}

resource "google_project_iam_member" "cloudbuild_trigger_log_writer" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.cloudbuild_trigger.email}"
}

resource "random_id" "data_explorer_source_bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "data_explorer_source" {
  name                        = "${random_id.data_explorer_source_bucket_prefix.hex}-data-explorer-source"
  force_destroy               = true
  location                    = var.region
  uniform_bucket_level_access = true
}

data "archive_file" "data_explorer_source" {
  type        = "zip"
  output_path = "/tmp/data-explorer-source.zip"
  source_dir  = "${path.module}/src"
  excludes    = ["docker-compose.yml", "README.md", ".ruff_cache", ".venv"]
}

resource "google_storage_bucket_object" "data_explorer_source" {
  name         = "data-explorer-source.zip"
  content_type = "application/zip"
  bucket       = google_storage_bucket.data_explorer_source.name
  source       = data.archive_file.data_explorer_source.output_path
}

resource "google_artifact_registry_repository" "data-explorer-app" {
  location      = var.region
  repository_id = "data-explorer"
  description   = "Image used to deploy Data Explorer Streamlit app on Cloud Run"
  format        = "DOCKER"
}

resource "random_id" "data_explorer_logs_bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "data_explorer_logs" {
  name                        = "${random_id.data_explorer_logs_bucket_prefix.hex}-data-explorer-logs"
  force_destroy               = true
  location                    = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "cloudbuild_trigger_logs_admin" {
  bucket = google_storage_bucket.data_explorer_logs.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.cloudbuild_trigger.email}"
}

locals {
  data_explorer_image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.data-explorer-app.repository_id}/app"
}

resource "google_cloudbuild_trigger" "data_explorer" {
  name            = "data-explorer-build-trigger"
  location        = var.build_region
  service_account = google_service_account.cloudbuild_trigger.id

  build {
    logs_bucket = "${google_storage_bucket.data_explorer_logs.url}/build-logs"
    step {
      id   = "fetch-source"
      name = "gcr.io/cloud-builders/gsutil"
      args = ["cp", "gs://${google_storage_bucket.data_explorer_source.name}/${google_storage_bucket_object.data_explorer_source.name}", "."]
    }

    step {
      id   = "unzip-source"
      name = "ubuntu"
      args = ["bash", "-c", "apt-get update && apt-get install -y unzip && unzip ${google_storage_bucket_object.data_explorer_source.name}"]
    }

    step {
      id   = "build-image"
      name = "gcr.io/cloud-builders/docker"
      args = ["build", "-t", "${local.data_explorer_image}", "."]
      env  = ["DOCKER_BUILDKIT=1"]
    }

    step {
      id   = "push-image"
      name = "gcr.io/cloud-builders/docker"
      args = ["push", "${local.data_explorer_image}"]
    }

    step {
      id   = "deploy-image"
      name = "gcr.io/cloud-builders/gcloud"
      args = [
        "run", "deploy", "data-explorer-app",
        "--image", "${local.data_explorer_image}",
        "--platform", "managed",
        "--region", var.region,
        "--port", "8501",
        "--allow-unauthenticated"
      ]
    }
  }

  repository_event_config {}
  lifecycle {
    ignore_changes = [
      repository_event_config
    ]
  }
}

# App

resource "google_service_account" "data_explorer" {
  account_id   = "data-explorer-sa"
  display_name = "Data Explorer Cloud Run SA"
}

resource "google_storage_bucket_iam_member" "data_explorer" {
  bucket = var.data_bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.data_explorer.email}"
}

resource "google_storage_bucket_iam_member" "data_explorer_object_viewer" {
  bucket = var.data_bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.data_explorer.email}"
}

resource "google_secret_manager_secret_iam_member" "data_explorer_auth_password" {
  secret_id = google_secret_manager_secret.auth_password.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.data_explorer.email}"
}

resource "google_secret_manager_secret_iam_member" "data_explorer_cookie_key" {
  secret_id = google_secret_manager_secret.cookie_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.data_explorer.email}"
}

resource "google_cloud_run_v2_service" "data_explorer" {
  name                = "data-explorer-app"
  location            = var.region
  deletion_protection = false

  template {
    service_account = google_service_account.data_explorer.email
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      env {
        name  = "GCS_BUCKET_NAME"
        value = var.data_bucket_name
      }
      env {
        name  = "HMAC_ACCESS_ID"
        value = google_storage_hmac_key.data_bucket_reader.access_id
      }
      env {
        name  = "HMAC_SECRET"
        value = google_secret_manager_secret_version.hmac.secret_data
      }
      env {
        name  = "AUTH_USERNAME"
        value = var.auth_username
      }
      env {
        name  = "AUTH_PASSWORD"
        value = google_secret_manager_secret_version.auth_password.secret_data
      }
      env {
        name  = "COOKIE_KEY"
        value = google_secret_manager_secret_version.cookie_key.secret_data
      }
      env {
        name  = "STREAMLIT_THEME_BASE"
        value = var.streamlit_theme_base
      }
      resources {
        limits = {
          cpu    = var.cloudrun_limits.cpu
          memory = var.cloudrun_limits.memory
        }
      }
    }
  }

  # Ignore changes due to Cloud Build trigger
  lifecycle {
    ignore_changes = [
      template[0].containers[0].image,
      client,
      client_version
    ]
  }
}

resource "google_cloud_run_service_iam_member" "public" {
  service  = google_cloud_run_v2_service.data_explorer.name
  location = google_cloud_run_v2_service.data_explorer.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "null_resource" "trigger_cloudbuild" {
  depends_on = [
    google_cloudbuild_trigger.data_explorer,
    google_storage_bucket_object.data_explorer_source
  ]

  # Only trigger when source content changes
  triggers = {
    source_zip_md5 = data.archive_file.data_explorer_source.output_md5
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud builds triggers run ${google_cloudbuild_trigger.data_explorer.name} \
        --region=${var.build_region} \
        --project=${var.project_id}
    EOT
  }
}
