#################################
# Common Resources
#################################

resource "random_id" "bucket_prefix" {
  byte_length = 8
}

resource "google_storage_bucket" "this" {
  name          = "${random_id.bucket_prefix.hex}-data-bucket"
  force_destroy = true
  location      = var.region

  uniform_bucket_level_access = true
}

#################################
# Ingestion Pipeline Resources
#################################

module "notion_pipeline" {
  source = "./modules/notion_pipeline"

  project_id                 = var.project_id
  region                     = var.region
  bucket_name                = google_storage_bucket.this.name
  notion_api_key             = var.notion_pipeline.notion_api_key
  cloud_scheduler_parameters = var.notion_pipeline.cloud_scheduler_parameters
}

#################################
# Streamlit App Resources
#################################

module "streamlit" {
  source = "./modules/streamlit"

  project_id      = var.project_id
  region          = var.region
  bucket_name     = google_storage_bucket.this.name
  build_region    = var.streamlit.build_region
  cloudrun_limits = var.streamlit.cloudrun_limits
}
