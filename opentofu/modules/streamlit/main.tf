resource "google_service_account" "data_bucket_reader" {
  account_id   = "bucket-reader-sa"
  display_name = "SA to reads data from bucket"
}

resource "google_storage_bucket_iam_member" "data_bucket_reader" {
  bucket = var.bucket_name
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

# Cloud build trigger

resource "google_service_account" "cloudbuild_trigger" {
  account_id   = "cloudbuild-trigger-sa"
  display_name = "Cloud Build Trigger SA"
}

resource "google_storage_bucket_iam_member" "cloudbuild_trigger" {
  bucket = google_storage_bucket.streamlit_source.name
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

resource "random_id" "streamlit_source_bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "streamlit_source" {
  name                        = "${random_id.streamlit_source_bucket_prefix.hex}-streamlit-source"
  force_destroy               = true
  location                    = var.region
  uniform_bucket_level_access = true
}

data "archive_file" "streamlit_source" {
  type        = "zip"
  output_path = "/tmp/streamlit-source.zip"
  source_dir  = "${path.module}/src"
  excludes    = ["docker-compose.yml", "README.md", ".ruff_cache", ".venv"]
}

resource "google_storage_bucket_object" "streamlit_source" {
  name         = "streamlit-source.zip"
  content_type = "application/zip"
  bucket       = google_storage_bucket.streamlit_source.name
  source       = data.archive_file.streamlit_source.output_path
}

resource "google_artifact_registry_repository" "streamlit-app" {
  location      = var.region
  repository_id = "streamlit"
  description   = "Image used to deploy Streamlit app on Cloud Run"
  format        = "DOCKER"
}

resource "random_id" "streamlit_logs_bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "streamlit_logs" {
  name                        = "${random_id.streamlit_logs_bucket_prefix.hex}-streamlit-logs"
  force_destroy               = true
  location                    = var.region
  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "cloudbuild_trigger_logs_admin" {
  bucket = google_storage_bucket.streamlit_logs.name
  role   = "roles/storage.admin"
  member = "serviceAccount:${google_service_account.cloudbuild_trigger.email}"
}

locals {
  streamlit_image = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.streamlit-app.repository_id}/streamlit-app"
}

resource "google_cloudbuild_trigger" "streamlit" {
  name            = "streamlit-build-trigger"
  location        = var.build_region
  service_account = google_service_account.cloudbuild_trigger.id

  build {
    logs_bucket = "${google_storage_bucket.streamlit_logs.url}/build-logs"
    step {
      id   = "fetch-source"
      name = "gcr.io/cloud-builders/gsutil"
      args = ["cp", "gs://${google_storage_bucket.streamlit_source.name}/${google_storage_bucket_object.streamlit_source.name}", "."]
    }

    step {
      id   = "unzip-source"
      name = "ubuntu"
      args = ["bash", "-c", "apt-get update && apt-get install -y unzip && unzip ${google_storage_bucket_object.streamlit_source.name}"]
    }

    step {
      id   = "build-image"
      name = "gcr.io/cloud-builders/docker"
      args = ["build", "-t", "${local.streamlit_image}", "."]
      env  = ["DOCKER_BUILDKIT=1"]
    }

    step {
      id   = "push-image"
      name = "gcr.io/cloud-builders/docker"
      args = ["push", "${local.streamlit_image}"]
    }

    step {
      id   = "deploy-image"
      name = "gcr.io/cloud-builders/gcloud"
      args = [
        "run", "deploy", "streamlit-app",
        "--image", "${local.streamlit_image}",
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

# Streamlit

resource "google_service_account" "streamlit" {
  account_id   = "streamlit-sa"
  display_name = "Streamlit Cloud Run SA"
}

resource "google_storage_bucket_iam_member" "streamlit" {
  bucket = var.bucket_name
  role   = "roles/storage.legacyBucketReader"
  member = "serviceAccount:${google_service_account.streamlit.email}"
}

resource "google_storage_bucket_iam_member" "streamlit_object_viewer" {
  bucket = var.bucket_name
  role   = "roles/storage.objectViewer"
  member = "serviceAccount:${google_service_account.streamlit.email}"
}

resource "google_cloud_run_v2_service" "streamlit" {
  name                = "streamlit-app"
  location            = var.region
  deletion_protection = false

  template {
    service_account = google_service_account.streamlit.email
    containers {
      image = "us-docker.pkg.dev/cloudrun/container/hello"
      env {
        name  = "GCS_BUCKET_NAME"
        value = var.bucket_name
      }
      env {
        name  = "HMAC_ACCESS_ID"
        value = google_storage_hmac_key.data_bucket_reader.access_id
      }
      env {
        name  = "HMAC_SECRET"
        value = google_secret_manager_secret_version.hmac.secret_data
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
  service  = google_cloud_run_v2_service.streamlit.name
  location = google_cloud_run_v2_service.streamlit.location
  role     = "roles/run.invoker"
  member   = "allUsers"
}

resource "null_resource" "trigger_cloudbuild" {
  depends_on = [
    google_cloudbuild_trigger.streamlit,
    google_storage_bucket_object.streamlit_source
  ]

  # Only trigger when source content changes
  triggers = {
    source_zip_md5 = data.archive_file.streamlit_source.output_md5
  }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud builds triggers run ${google_cloudbuild_trigger.streamlit.name} \
        --region=${var.build_region} \
        --project=${var.project_id}
    EOT
  }
}
