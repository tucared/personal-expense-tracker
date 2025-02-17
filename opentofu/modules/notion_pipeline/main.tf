# Cloud function service account

resource "google_service_account" "cloud_function" {
  account_id   = var.sa_account_id_cloud_function
  display_name = "Cloud Function SA"
}

resource "google_storage_bucket_iam_member" "cloud_function" {
  bucket = var.bucket_name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.cloud_function.email}"
}

## Saving the service account private key in Secret Manager

resource "google_service_account_key" "cloud_function" {
  service_account_id = google_service_account.cloud_function.name
}

resource "google_secret_manager_secret" "cloud_function_service_account_key" {
  secret_id = "CLOUD_FUNCTION_SERVICE_ACCOUNT_KEY"

  replication {
    user_managed {
      replicas {
        location = var.region
      }
    }
  }
}

resource "google_secret_manager_secret_version" "cloud_function_service_account_key" {
  secret      = google_secret_manager_secret.cloud_function_service_account_key.id
  secret_data = jsondecode(base64decode(google_service_account_key.cloud_function.private_key))["private_key"]
}

resource "google_secret_manager_secret_iam_member" "cloud_function_service_account_key" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.cloud_function_service_account_key.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_function.email}"
}

# Notion source secret

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

resource "google_secret_manager_secret_iam_member" "cloud_function_notion" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.notion.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.cloud_function.email}"
}

# Deployment of Cloud Function

## Saving source code in a bucket

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
  excludes    = ["__pycache__", "requirements.local.txt", ".gcloudignore", ".venv", "secret", "uv.lock", "pyproject.toml", "README.md"]
}

resource "google_storage_bucket_object" "cloud_function_source" {
  name         = var.cloud_function_parameters.name
  content_type = "application/zip"
  bucket       = google_storage_bucket.cloud_function_source.name
  source       = data.archive_file.cloud_function_source.output_path
}

## Deployment of the Cloud Function

resource "google_cloudfunctions2_function" "this" {
  name        = var.cloud_function_parameters.name
  location    = var.region
  description = "Function used to query latest added and edited items"

  build_config {
    runtime = var.cloud_function_parameters.runtime
    source {
      storage_source {
        bucket = google_storage_bucket.cloud_function_source.name
        object = google_storage_bucket_object.cloud_function_source.name
      }
    }
    entry_point = var.cloud_function_parameters.entrypoint
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
      DESTINATION__FILESYSTEM__BUCKET_URL                = "gs://${var.bucket_name}"
      DESTINATION__FILESYSTEM__CREDENTIALS__CLIENT_EMAIL = google_service_account.cloud_function.email
      DESTINATION__FILESYSTEM__CREDENTIALS__PROJECT_ID   = var.project_id
      NORMALIZE__LOADER_FILE_FORMAT                      = "parquet"
      RUNTIME__LOG_LEVEL                                 = "WARNING"
      RUNTIME__DLTHUB_TELEMETRY                          = false
    }

    secret_environment_variables {
      project_id = var.project_id
      key        = "SOURCES__NOTION__API_KEY"
      secret     = google_secret_manager_secret.notion.secret_id
      version    = "latest"
    }

    secret_environment_variables {
      project_id = var.project_id
      key        = "DESTINATION__FILESYSTEM__CREDENTIALS__PRIVATE_KEY"
      secret     = google_secret_manager_secret.cloud_function_service_account_key.secret_id
      version    = "latest"
    }
  }
}

# Cloud Scheduler to invoke the Cloud Function regularly

resource "google_service_account" "cloud_scheduler" {
  account_id   = var.sa_account_id_cloud_scheduler
  display_name = "Cloud Scheduler SA"
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

resource "google_cloud_scheduler_job" "dlt" {
  paused = var.cloud_scheduler_parameters.paused

  name        = var.cloud_scheduler_parameters.name
  description = "Cloud Function dlt invoker"
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
