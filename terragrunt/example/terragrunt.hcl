# User-defined environment variables
locals {
  env_vars = yamldecode(file("env_vars.yaml"))
}

# Include root terragrunt.hcl
include "root" {
  path           = find_in_parent_folders("root.hcl")
  expose         = true
  merge_strategy = "deep"
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
  project_id = local.env_vars.project_id
  region     = local.env_vars.region
  zone       = local.env_vars.zone

  notion_pipeline = {
    notion_api_key = local.env_vars.notion_pipeline.notion_api_key
    cloud_scheduler_parameters = {
      paused   = local.env_vars.notion_pipeline.cloud_scheduler_parameters.paused
      schedule = local.env_vars.notion_pipeline.cloud_scheduler_parameters.schedule
      region   = local.env_vars.notion_pipeline.cloud_scheduler_parameters.region
    }
  }

  streamlit = {
    build_region = local.env_vars.streamlit.build_region
    cloudrun_limits = {
      memory = local.env_vars.streamlit.cloudrun_limits.memory
      cpu    = local.env_vars.streamlit.cloudrun_limits.cpu
    }
  }
}
