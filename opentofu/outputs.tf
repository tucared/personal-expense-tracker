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

# Outputs for Streamlit module

output "streamlit_build_trigger_name" {
  description = "Name of Cloud Build trigger for Streamlit service"
  value       = module.streamlit.build_trigger_name
}

output "streamlit_build_trigger_region" {
  description = "Region of Cloud Build trigger for Streamlit service"
  value       = module.streamlit.build_trigger_region
}

output "streamlit_service_url" {
  description = "URL of deployed Streamlit service"
  value       = module.streamlit.service_url
}

output "streamlit_service_account_email" {
  description = "Email of service account used by Cloud Run when running Streamlit service"
  value       = module.streamlit.service_account_email
}

output "streamlit_hmac_access_id" {
  value = module.streamlit.hmac_access_id
}

output "streamlit_hmac_secret" {
  value     = module.streamlit.hmac_secret
  sensitive = true
}
