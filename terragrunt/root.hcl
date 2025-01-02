terraform {
  source = "../..//opentofu"
}

# Environment variables common to all deployments
locals {
  common_vars = yamldecode(file("common_vars.yaml"))
}

inputs = {
  destination_state_file = local.common_vars.destination_state_file

  cloud_function_parameters = {
    entrypoint = local.common_vars.cloud_function_parameters.entrypoint
    name       = local.common_vars.cloud_function_parameters.name
    runtime    = local.common_vars.cloud_function_parameters.runtime
    source     = local.common_vars.cloud_function_parameters.source
  }

  cloud_schedulers_parameters = {
    append_scheduler = {
      name = local.common_vars.cloud_schedulers_parameters.append_scheduler.name
    }
    full_refresh_scheduler = {
      name = local.common_vars.cloud_schedulers_parameters.full_refresh_scheduler.name
    }
  }

  gsm_notion_secret_name        = local.common_vars.gsm_notion_secret_name
  sa_account_id_cloud_function  = local.common_vars.sa_account_id_cloud_function
  sa_account_id_cloud_scheduler = local.common_vars.sa_account_id_cloud_scheduler
}
