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
  project_id          = local.env_vars.project_id
  notion_secret_value = local.env_vars.notion_secret_value

  sa_tofu = local.env_vars.sa_tofu

  region                 = local.env_vars.region
  region_streamlit_build = local.env_vars.region_streamlit_build
  zone                   = local.env_vars.zone

  cloud_scheduler_parameters = {
    paused   = local.env_vars.cloud_scheduler_parameters.paused
    schedule = local.env_vars.cloud_scheduler_parameters.schedule
  }

  streamlit_cloudrun_limits = {
    cpu    = local.env_vars.streamlit_cloudrun_limits.cpu
    memory = local.env_vars.streamlit_cloudrun_limits.memory
  }
}
