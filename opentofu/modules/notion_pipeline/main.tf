module "base_pipeline" {
  source = "../base_pipeline"

  project_id                 = var.project_id
  region                     = var.region
  data_bucket_name           = var.data_bucket_name
  service_account_email      = var.data_bucket_writer_service_account_email
  pipeline_name              = "notion_pipeline"
  entry_point                = "notion_pipeline"
  cloud_scheduler_parameters = var.cloud_scheduler_parameters

  environment_variables = {
    SOURCES__NOTION__DATABASE_ID = var.notion_database_id
  }

  secrets = [
    {
      name  = "SOURCES__NOTION__API_KEY"
      value = var.notion_api_key
    }
  ]
}
