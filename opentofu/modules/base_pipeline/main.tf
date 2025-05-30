locals {
  # Standardized labels for all resources
  labels = {
    module = var.pipeline_name
  }

  # Used to name resources or prefix them - avoid underscores
  module_name = replace(var.pipeline_name, "_", "-")

  # For service account IDs that need to be shorter
  # This creates a shortened name using the first part of the pipeline name
  # plus a hash of the full name to ensure uniqueness
  short_name = "${substr(replace(var.pipeline_name, "_", "-"), 0,
  min(10, length(replace(var.pipeline_name, "_", "-"))))}-${substr(md5(var.pipeline_name), 0, 8)}"
}

# Source API keys and credentials management

resource "google_secret_manager_secret" "secrets" {
  count = length(var.secrets)

  secret_id = "${upper(var.pipeline_name)}_${upper(replace(var.secrets[count.index].name, "__", "_"))}"

  labels = {
    application = var.pipeline_name
  }

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "secrets" {
  count = length(var.secrets)

  secret      = google_secret_manager_secret.secrets[count.index].id
  secret_data = var.secrets[count.index].value
}

resource "google_secret_manager_secret_iam_member" "secrets" {
  count = length(var.secrets)

  project   = var.project_id
  secret_id = google_secret_manager_secret.secrets[count.index].secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.service_account_email}"
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
  output_path = "${path.module}/../${var.pipeline_name}/function-source.zip"
  source_dir  = "${path.module}/../${var.pipeline_name}/src"
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
  description = "Function used to query ${var.pipeline_name} source"

  build_config {
    runtime = "python312"
    source {
      storage_source {
        bucket = google_storage_bucket.cloud_function_source.name
        object = google_storage_bucket_object.cloud_function_source.name
      }
    }
    entry_point = var.entry_point
  }

  lifecycle {
    replace_triggered_by = [
      google_storage_bucket_object.cloud_function_source
    ]
  }

  labels = local.labels

  service_config {
    max_instance_count    = var.function_config.max_instance_count
    available_memory      = var.function_config.available_memory
    timeout_seconds       = var.function_config.timeout_seconds
    service_account_email = var.service_account_email

    environment_variables = merge({
      DESTINATION__FILESYSTEM__BUCKET_URL              = "gs://${var.data_bucket_name}"
      DESTINATION__FILESYSTEM__CREDENTIALS__PROJECT_ID = var.project_id
      NORMALIZE__LOADER_FILE_FORMAT                    = var.loader_file_format
      RUNTIME__LOG_LEVEL                               = var.log_level
      RUNTIME__DLTHUB_TELEMETRY                        = false
    }, var.environment_variables)

    dynamic "secret_environment_variables" {
      for_each = range(length(var.secrets))
      content {
        project_id = var.project_id
        key        = var.secrets[secret_environment_variables.value].name
        secret     = google_secret_manager_secret.secrets[secret_environment_variables.value].secret_id
        version    = "latest"
      }
    }
  }
}

# Cloud Scheduler to invoke the Cloud Function regularly

resource "google_service_account" "cloud_scheduler" {
  account_id   = "${local.short_name}-scheduler"
  display_name = "Cloud Scheduler SA for ${var.pipeline_name}"
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
  description = "Triggers the Cloud Function to query ${var.pipeline_name}"
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
