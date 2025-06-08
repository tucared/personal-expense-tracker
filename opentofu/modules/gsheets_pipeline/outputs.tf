output "function_uri" {
  description = "URI of the deployed cloud function"
  value       = module.base_pipeline.function_uri
}

output "function_name" {
  description = "Name of the deployed cloud function"
  value       = module.base_pipeline.function_name
}

output "scheduler_job_name" {
  description = "Name of the cloud scheduler job"
  value       = module.base_pipeline.scheduler_job_name
}

output "scheduler_service_account_email" {
  description = "Service account email used by the cloud scheduler"
  value       = module.base_pipeline.scheduler_service_account_email
}
