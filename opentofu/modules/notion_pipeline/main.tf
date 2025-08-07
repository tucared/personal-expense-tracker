module "base_pipeline" {
  source = "../base_pipeline"

  project_id                               = var.project_id
  region                                   = var.region
  data_bucket_name                         = var.data_bucket_name
  data_bucket_writer_service_account_email = var.data_bucket_writer_service_account_email
  pipeline_name                            = "notion_pipeline"
  entry_point                              = "notion_pipeline"
  cloud_scheduler_parameters               = var.cloud_scheduler_parameters
  function_config = {
    max_instance_count = 1
    available_memory   = "512Mi"
    timeout_seconds    = 600
  }

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
