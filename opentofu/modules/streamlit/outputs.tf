output "build_trigger_name" {
  description = "Name of Cloud Build trigger for Streamlit service"
  value       = google_cloudbuild_trigger.streamlit.name
}

output "build_trigger_region" {
  description = "Region of Cloud Build trigger for Streamlit service"
  value       = google_cloudbuild_trigger.streamlit.location
}

output "service_url" {
  description = "URL of deployed Streamlit service"
  value       = google_cloud_run_v2_service.streamlit.uri
}

output "service_account_email" {
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
