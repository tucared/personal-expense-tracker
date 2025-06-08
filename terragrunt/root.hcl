terraform {
  source = "../..//opentofu"
}

# User-defined environment variables
locals {
  env_vars = yamldecode(file("${path_relative_to_include()}/env_vars.yaml"))
}

# Remote GCS backend
remote_state {
  backend = "gcs"

  config = {
    project  = local.env_vars.project_id
    location = local.env_vars.region
    bucket   = "${md5(local.env_vars.project_id)}-tfstate"
    prefix   = "terraform.tfstate"
  }
}

inputs = {
  project_id       = local.env_vars.project_id
  region           = local.env_vars.region
  zone             = local.env_vars.zone
  notion_pipeline  = local.env_vars.notion_pipeline
  gsheets_pipeline = local.env_vars.gsheets_pipeline
  data_explorer    = local.env_vars.data_explorer
}
