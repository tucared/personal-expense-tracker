output "bucket_name" {
  description = "Name of bucket containing cloud function state file"
  value       = google_storage_bucket.this.name
}

output "hmac_access_id" {
  value = google_storage_hmac_key.data_bucket_reader.access_id
}

output "hmac_secret" {
  value     = google_storage_hmac_key.data_bucket_reader.secret
  sensitive = true
}

output "sa_email_tofu" {
  description = "Email of service account used whe running tofu commands"
  value       = local.tofu_service_account
}

output "streamlit_build_trigger_name" {
  description = "Name of Cloud Build trigger for Streamlit service"
  value       = google_cloudbuild_trigger.streamlit.name
}

output "streamlit_build_trigger_region" {
  description = "Region of Cloud Build trigger for Streamlit service"
  value       = google_cloudbuild_trigger.streamlit.location
}

output "streamlit_service_url" {
  description = "URL of deployed Streamlit service"
  value       = google_cloud_run_v2_service.streamlit.uri
}

output "sa_email_streamlit_cloud_run" {
  description = "Email of service account used by Cloud Run when running Streamlit service"
  value       = google_service_account.streamlit.email
}

output "notion_pipeline_function_uri" {
  description = "URI of deployed Cloud Function"
  value       = module.notion_pipeline.function_uri
}

output "notion_pipeline_scheduler_dlt_name" {
  description = "Name of deployed Cloud Function"
  value       = module.notion_pipeline.scheduler_dlt_name
}

output "notion_pipeline_scheduler_dlt_region" {
  description = "Region of deployed Cloud Function"
  value       = module.notion_pipeline.scheduler_dlt_region
}
