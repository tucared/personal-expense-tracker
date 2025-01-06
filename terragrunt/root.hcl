terraform {
  source = "../..//opentofu"
}

# Environment variables common to all deployments
locals {
  common_vars = yamldecode(file("common_vars.yaml"))
}

inputs = {
  cloud_function_parameters = {
    name       = local.common_vars.cloud_function_parameters.name
    runtime    = local.common_vars.cloud_function_parameters.runtime
    source     = local.common_vars.cloud_function_parameters.source
  }

  cloud_scheduler_parameters = {
    region   = local.common_vars.cloud_scheduler_parameters.region
    name     = local.common_vars.cloud_scheduler_parameters.name
  }

  gsm_notion_secret_name        = local.common_vars.gsm_notion_secret_name
  sa_account_id_cloud_function  = local.common_vars.sa_account_id_cloud_function
  sa_account_id_cloud_scheduler = local.common_vars.sa_account_id_cloud_scheduler
}
