module "base_pipeline" {
  source = "../base_pipeline"

  project_id                               = var.project_id
  region                                   = var.region
  data_bucket_name                         = var.data_bucket_name
  data_bucket_writer_service_account_email = var.data_bucket_writer_service_account_email
  pipeline_name                            = "gsheets_pipeline"
  entry_point                              = "gsheets_pipeline"
  cloud_scheduler_parameters               = var.cloud_scheduler_parameters
  function_config = {
    max_instance_count = 1
    available_memory   = "512Mi"
    timeout_seconds    = 600
  }

  environment_variables = {
    SOURCES__GOOGLE_SHEETS__CREDENTIALS__CLIENT_EMAIL = var.data_bucket_writer_service_account_email
    SOURCES__GOOGLE_SHEETS__CREDENTIALS__PROJECT_ID   = var.project_id
    SOURCES__GOOGLE_SHEETS__SPREADSHEET_URL_OR_ID     = var.spreadsheet_url_or_id
  }

  secrets = [
    {
      name  = "SOURCES__GOOGLE_SHEETS__CREDENTIALS__PRIVATE_KEY"
      value = var.data_bucket_writer_private_key
    }
  ]
}
