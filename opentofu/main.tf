#################################
# Common Resources
#################################

resource "random_id" "data_bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "data_bucket" {
  name          = "${random_id.data_bucket_prefix.hex}-data-bucket"
  force_destroy = true
  location      = var.region

  uniform_bucket_level_access = true
}

resource "google_service_account" "data_bucket_writer" {
  account_id   = "ingestion-pipeline"
  display_name = "Ingestion Pipeline SA"
  description  = "Service account impersonated for ingestion pipeline"
}

resource "google_storage_bucket_iam_member" "data_bucket_writer" {
  bucket = google_storage_bucket.data_bucket.name
  role   = "roles/storage.objectUser"
  member = "serviceAccount:${google_service_account.data_bucket_writer.email}"
}

#################################
# Ingestion Pipeline Resources
#################################

module "notion_pipeline" {
  source = "./modules/notion_pipeline"

  project_id                               = var.project_id
  region                                   = var.region
  data_bucket_name                         = google_storage_bucket.data_bucket.name
  data_bucket_writer_service_account_email = google_service_account.data_bucket_writer.email
  cloud_scheduler_parameters               = var.notion_pipeline.cloud_scheduler_parameters

  notion_api_key     = var.notion_pipeline.notion_api_key
  notion_database_id = var.notion_pipeline.notion_database_id
}

module "google_sheets_pipeline" {
  source = "./modules/google_sheets_pipeline"

  project_id                               = var.project_id
  region                                   = var.region
  data_bucket_name                         = google_storage_bucket.data_bucket.name
  data_bucket_writer_service_account_email = google_service_account.data_bucket_writer.email
  cloud_scheduler_parameters               = var.google_sheets_pipeline.cloud_scheduler_parameters

  spreadsheet_url_or_id = var.google_sheets_pipeline.spreadsheet_url_or_id
}

#################################
# Data Explorer App Resources
#################################

module "data_explorer" {
  source = "./modules/data_explorer"

  project_id       = var.project_id
  region           = var.region
  data_bucket_name = google_storage_bucket.data_bucket.name
  build_region     = var.data_explorer.build_region
  cloudrun_limits  = var.data_explorer.cloudrun_limits
}
