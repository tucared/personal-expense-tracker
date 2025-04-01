output "bucket_name" {
  description = "Name of bucket containing cloud function state file"
  value       = google_storage_bucket.this.name
}

# Outputs for Notion pipeline module

output "notion_pipeline_function_uri" {
  description = "URI of deployed Cloud Function"
  value       = module.notion_pipeline.function_uri
}

output "notion_pipeline_function_service_account_email" {
  description = "Email of service account used when running the Cloud Function"
  value       = module.notion_pipeline.function_service_account_email
}

output "notion_pipeline_scheduler_name" {
  description = "Name of deployed Cloud Function"
  value       = module.notion_pipeline.scheduler_name
}

output "notion_pipeline_scheduler_region" {
  description = "Region of deployed Cloud Function"
  value       = module.notion_pipeline.scheduler_region
}

# Outputs for Data explorer module

output "data_explorer_build_trigger_name" {
  description = "Name of Cloud Build trigger for data explorer service"
  value       = module.data_explorer.build_trigger_name
}

output "data_explorer_build_trigger_region" {
  description = "Region of Cloud Build trigger for data explorer service"
  value       = module.data_explorer.build_trigger_region
}

output "data_explorer_service_url" {
  description = "URL of deployed data explorer service"
  value       = module.data_explorer.service_url
}

output "data_explorer_service_account_email" {
  description = "Email of service account used by Cloud Run when running data explorer service"
  value       = module.data_explorer.service_account_email
}

output "data_explorer_hmac_access_id" {
  value = module.data_explorer.hmac_access_id
}

output "data_explorer_hmac_secret" {
  value     = module.data_explorer.hmac_secret
  sensitive = true
}
