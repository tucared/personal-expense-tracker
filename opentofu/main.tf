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

  name        = var.cloud_schedulers_parameters.full_refresh_scheduler.name
  description = "Cloud Function invoker, refreshing all items in BigQuery"
  schedule    = var.cloud_schedulers_parameters.full_refresh_scheduler.schedule
  region      = var.cloud_schedulers_parameters.region

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