output "bucket_name" {
  description = "Name of bucket containing cloud function state file"
  value       = google_storage_bucket.this.name
}

output "function_name" {
  description = "Name of deployed Cloud Function"
  value       = google_cloudfunctions2_function.this.name
}

output "function_region" {
  description = "Region of deployed Cloud Function"
  value       = google_cloudfunctions2_function.this.location
}

output "function_uri" {
  description = "URI of deployed Cloud Function"
  value       = google_cloudfunctions2_function.this.service_config[0].uri
}

output "function_env_vars" {
  description = "Environment variables of deployed Cloud Function"
  value       = google_cloudfunctions2_function.this.service_config[0].environment_variables
}

output "scheduler_dlt_name" {
  description = "Name of Cloud Scheduler to trigger Cloud Function with append strategy"
  value       = google_cloud_scheduler_job.dlt.name
}

output "scheduler_dlt_region" {
  description = "Region of Cloud Scheduler to trigger Cloud Function with append strategy"
  value       = google_cloud_scheduler_job.dlt.region
}

output "sa_email_cloud_function" {
  description = "Email of service account used when running the Cloud Function"
  value       = google_service_account.cloud_function.email
}

output "bucket_name_cloud_function" {
  description = "Name of bucket containing cloud function state file"
  value       = google_storage_bucket.this.name
}

output "sa_email_cloud_scheduler" {
  description = "Email of service account used by Cloud Scheduler when invoking Cloud Function"
  value       = google_service_account.cloud_scheduler.email
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

output "hmac_access_id" {
  value = google_storage_hmac_key.data_bucket_reader.access_id
}

output "hmac_secret" {
  value     = google_storage_hmac_key.data_bucket_reader.secret
  sensitive = true
}
