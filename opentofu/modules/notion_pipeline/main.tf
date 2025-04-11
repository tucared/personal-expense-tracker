locals {
  labels = {
    module = "notion_pipeline"
  }

  # Used to name resources or prefix them
  module_name = "notion-pipeline" # Avoid underscores in the name
}

# Notion source secret

resource "google_secret_manager_secret" "notion" {
  secret_id = "NOTION_API_KEY"

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
  secret_data = var.notion_api_key
}

resource "google_secret_manager_secret_iam_member" "cloud_function_notion" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.notion.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.data_bucket_writer_service_account_email}"
}

# Deployment of Cloud Function

## Saving source code in a bucket

resource "random_id" "cloud_function_source_bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "cloud_function_source" {
  name                        = "${random_id.cloud_function_source_bucket_prefix.hex}-${local.module_name}-gcf-source"
  force_destroy               = true
  location                    = var.region
  uniform_bucket_level_access = true

  labels = local.labels
}

data "archive_file" "cloud_function_source" {
  type        = "zip"
  output_path = "${path.module}/function-source.zip"
  source_dir  = "${path.module}/src"
  excludes    = ["__pycache__", ".venv", "uv.lock", "pyproject.toml"]
}

resource "google_storage_bucket_object" "cloud_function_source" {
  name         = "${local.module_name}-${data.archive_file.cloud_function_source.output_md5}.zip"
  content_type = "application/zip"
  bucket       = google_storage_bucket.cloud_function_source.name
  source       = data.archive_file.cloud_function_source.output_path
}

## Deployment of the Cloud Function

resource "google_cloudfunctions2_function" "this" {
  name        = local.module_name
  location    = var.region
  description = "Function used to query latest added and edited items"

  build_config {
    runtime = "python312"
    source {
      storage_source {
        bucket = google_storage_bucket.cloud_function_source.name
        object = google_storage_bucket_object.cloud_function_source.name
      }
    }
    entry_point = "notion_pipeline"
  }

  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_function_source
    ]
  }

  labels = local.labels

  service_config {
    max_instance_count    = 1
    available_memory      = "256Mi"
    timeout_seconds       = 600
    service_account_email = var.data_bucket_writer_service_account_email

    environment_variables = {
      DESTINATION__FILESYSTEM__BUCKET_URL              = "gs://${var.data_bucket_name}"
      DESTINATION__FILESYSTEM__CREDENTIALS__PROJECT_ID = var.project_id
      NORMALIZE__LOADER_FILE_FORMAT                    = "parquet"
      RUNTIME__LOG_LEVEL                               = "WARNING"
      RUNTIME__DLTHUB_TELEMETRY                        = false
    }

    secret_environment_variables {
      project_id = var.project_id
      key        = "SOURCES__NOTION__API_KEY"
      secret     = google_secret_manager_secret.notion.secret_id
      version    = "latest"
    }
  }
}

# Cloud Scheduler to invoke the Cloud Function regularly

resource "google_service_account" "cloud_scheduler" {
  account_id   = "${local.module_name}-sa-scheduler"
  display_name = "Cloud Scheduler SA for Notion Pipeline"
}

resource "google_cloudfunctions2_function_iam_member" "invoker" {
  project        = google_cloudfunctions2_function.this.project
  location       = google_cloudfunctions2_function.this.location
  cloud_function = google_cloudfunctions2_function.this.name
  role           = "roles/cloudfunctions.invoker"
  member         = "serviceAccount:${google_service_account.cloud_scheduler.email}"
}

resource "google_cloud_run_service_iam_member" "invoker" {
  project  = google_cloudfunctions2_function.this.project
  location = google_cloudfunctions2_function.this.location
  service  = google_cloudfunctions2_function.this.name
  role     = "roles/run.invoker"
  member   = "serviceAccount:${google_service_account.cloud_scheduler.email}"
}

resource "google_cloud_scheduler_job" "this" {
  paused = var.cloud_scheduler_parameters.paused

  name        = "${local.module_name}-invoker"
  description = "Triggers the Cloud Function to query Notion API"
  schedule    = var.cloud_scheduler_parameters.schedule
  region      = var.cloud_scheduler_parameters.region

  http_target {
    uri         = google_cloudfunctions2_function.this.service_config[0].uri
    http_method = "POST"
    oidc_token {
      service_account_email = google_service_account.cloud_scheduler.email
      audience              = google_cloudfunctions2_function.this.service_config[0].uri
    }
  }

  depends_on = [
    google_cloudfunctions2_function.this,
    google_cloudfunctions2_function_iam_member.invoker,
    google_cloud_run_service_iam_member.invoker
  ]
}
