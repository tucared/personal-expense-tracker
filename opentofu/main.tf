resource "google_secret_manager_secret" "notion" {
  secret_id = var.gsm_notion_secret_name

  labels = {
    application = "notion"
  }

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "notion" {
  secret      = google_secret_manager_secret.notion.id
  secret_data = var.notion_secret_value
}

resource "google_bigquery_dataset" "this" {
  dataset_id                 = var.bq_dataset_id
  location                   = var.bq_location
  friendly_name              = "Notion dataset"
  delete_contents_on_destroy = true
  description                = "Dataset only containing data loaded from Cloud Function"
}

resource "google_service_account" "cloud_function" {
  account_id   = var.sa_account_id_cloud_function
  display_name = "Cloud Function SA"
}

resource "random_id" "cloud_function_bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "cloud_function" {
  name          = "${random_id.cloud_function_bucket_prefix.hex}-cloud-function"
  force_destroy = true
  location      = var.region

  uniform_bucket_level_access = true
}

resource "google_storage_bucket_iam_member" "cloud_function" {
  bucket = google_storage_bucket.cloud_function.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.cloud_function.email}"
}

resource "google_project_iam_member" "cloud_function" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.cloud_function.email}"
}

resource "google_secret_manager_secret_iam_member" "cloud_function" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.notion.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_function.email}"
}

resource "google_bigquery_dataset_iam_member" "cloud_function_editor" {
  dataset_id = google_bigquery_dataset.this.dataset_id
  role       = "roles/bigquery.dataEditor"
  member     = "serviceAccount:${google_service_account.cloud_function.email}"
}

resource "google_bigquery_dataset_iam_member" "cloud_function_viewer" {
  dataset_id = google_bigquery_dataset.this.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.cloud_function.email}"
}

resource "random_id" "cloud_function_source_bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "cloud_function_source" {
  name                        = "${random_id.cloud_function_source_bucket_prefix.hex}-gcf-source"
  force_destroy               = true
  location                    = var.region
  uniform_bucket_level_access = true
}

data "archive_file" "cloud_function_source" {
  type        = "zip"
  output_path = "/tmp/function-source.zip"
  source_dir  = var.cloud_function_parameters.source
  excludes    = ["__pycache__", "requirements.local.txt", ".gcloudignore"]
}

resource "google_storage_bucket_object" "cloud_function_source" {
  name         = var.cloud_function_parameters.name
  content_type = "application/zip"
  bucket       = google_storage_bucket.cloud_function_source.name
  source       = data.archive_file.cloud_function_source.output_path
}

resource "google_cloudfunctions2_function" "this" {
  name        = var.cloud_function_parameters.name
  location    = var.region
  description = "Function used to query latest added and edited items"

  build_config {
    runtime     = var.cloud_function_parameters.runtime
    entry_point = var.cloud_function_parameters.entrypoint
    source {
      storage_source {
        bucket = google_storage_bucket.cloud_function_source.name
        object = google_storage_bucket_object.cloud_function_source.name
      }
    }
  }

  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_function_source
    ]
  }

  service_config {
    max_instance_count    = 1
    available_memory      = "256Mi"
    timeout_seconds       = 600
    service_account_email = google_service_account.cloud_function.email
    environment_variables = {
      PROJECT_ID                       = var.project_id
      BQ_TABLE_ID                      = local.bq_table_id
      NOTION_DATABASE_ID               = var.notion_database_id
      GSM_NOTION_SECRET_NAME           = var.gsm_notion_secret_name
      BUCKET_NAME                      = google_storage_bucket.cloud_function.name
      DESTINATION_BLOB_NAME_STATE_FILE = var.destination_blob_name_state_file
    }
  }
}

resource "google_service_account" "cloud_scheduler" {
  account_id   = var.sa_account_id_cloud_scheduler
  display_name = "Cloud Scheduler SA"
}

# https://github.com/hashicorp/terraform-provider-google/issues/15264
resource "google_cloud_run_service_iam_binding" "binding" {
  location = google_cloudfunctions2_function.this.location
  project  = google_cloudfunctions2_function.this.project
  service  = google_cloudfunctions2_function.this.name
  role     = "roles/run.invoker"
  members = [
    "serviceAccount:${google_service_account.cloud_scheduler.email}"
  ]
}

resource "google_cloud_scheduler_job" "append" {
  paused = var.cloud_schedulers_parameters.paused

  name        = var.cloud_schedulers_parameters.append_scheduler.name
  description = "Cloud Function invoker, appending new items to BigQuery"
  schedule    = var.cloud_schedulers_parameters.append_scheduler.schedule
  region      = var.cloud_schedulers_parameters.region

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.this.service_config[0].uri

    oidc_token {
      service_account_email = google_service_account.cloud_scheduler.email
    }
  }
}

resource "google_cloud_scheduler_job" "full_refresh" {
  paused = var.cloud_schedulers_parameters.paused

  name             = var.cloud_schedulers_parameters.full_refresh_scheduler.name
  description      = "Cloud Function invoker, refreshing all items in BigQuery"
  schedule         = var.cloud_schedulers_parameters.full_refresh_scheduler.schedule
  region           = var.cloud_schedulers_parameters.region
  attempt_deadline = "640s"


  http_target {
    http_method = "POST"
    # Query param to trigger full refresh
    uri = "${google_cloudfunctions2_function.this.service_config[0].uri}/?full_refresh=true"

    oidc_token {
      service_account_email = google_service_account.cloud_scheduler.email
      audience              = google_cloudfunctions2_function.this.service_config[0].uri
    }
  }
}

####################
# Streamlit
####################

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

resource "google_service_account" "streamlit" {
  account_id   = "streamlit-sa"
  display_name = "Streamlit Cloud Run SA"
}

resource "google_bigquery_dataset_iam_member" "streamlit_viewer" {
  dataset_id = google_bigquery_dataset.this.dataset_id
  role       = "roles/bigquery.dataViewer"
  member     = "serviceAccount:${google_service_account.streamlit.email}"
}

resource "google_project_iam_member" "streamlit_job_user" {
  project = var.project_id
  role    = "roles/bigquery.jobUser"
  member  = "serviceAccount:${google_service_account.streamlit.email}"
}

resource "google_project_iam_member" "streamlit_read_session" {
  project = var.project_id
  role    = "roles/bigquery.readSessionUser"
  member  = "serviceAccount:${google_service_account.streamlit.email}"
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
        name  = "BQ_PROJECT_ID"
        value = var.project_id
      }
      env {
        name  = "BQ_DATASET_ID"
        value = google_bigquery_dataset.this.dataset_id
      }
      resources {
        limits = {
          cpu    = var.streamlit_cloudrun_limits.cpu
          memory = var.streamlit_cloudrun_limits.memory
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
  source_dir  = "../streamlit"
  excludes    = ["docker-compose.yml", "README.md", ".ruff_cache", ".venv", "secret"]
}

resource "google_storage_bucket_object" "streamlit_source" {
  name         = "streamlit-source.zip"
  content_type = "application/zip"
  bucket       = google_storage_bucket.streamlit_source.name
  source       = data.archive_file.streamlit_source.output_path
}

resource "google_artifact_registry_repository" "streamlit-app" {
  location      = var.region
  repository_id = var.streamlit_artifact_registry
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
  location        = var.region_streamlit_build
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