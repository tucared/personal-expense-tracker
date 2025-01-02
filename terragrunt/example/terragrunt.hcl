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
  notion_database_id  = local.env_vars.notion_database_id
  notion_secret_value = local.env_vars.notion_secret_value

  region  = local.env_vars.region
  zone    = local.env_vars.zone
  sa_tofu = local.env_vars.sa_tofu

  cloud_schedulers_parameters = {
    paused = local.env_vars.cloud_schedulers_parameters.paused
    region = local.env_vars.cloud_schedulers_parameters.region
    append_scheduler = {
      schedule = local.env_vars.cloud_schedulers_parameters.append_scheduler.schedule
    }
    full_refresh_scheduler = {
      schedule = local.env_vars.cloud_schedulers_parameters.full_refresh_scheduler.schedule
    }
  }

  bq_dataset_id        = local.env_vars.bq_dataset_id
  bq_location          = local.env_vars.bq_location
  bq_notion_table_name = local.env_vars.bq_notion_table_name
}
