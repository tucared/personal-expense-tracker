output "build_trigger_name" {
  description = "Name of Cloud Build trigger for Data Explorer service"
  value       = google_cloudbuild_trigger.data_explorer.name
}

output "build_trigger_region" {
  description = "Region of Cloud Build trigger for Data Explorer service"
  value       = google_cloudbuild_trigger.data_explorer.location
}

output "service_url" {
  description = "URL of deployed Data Explorer service"
  value       = google_cloud_run_v2_service.data_explorer.uri
}

output "service_account_email" {
  description = "Email of service account used by Cloud Run when running Data Explorer service"
  value       = google_service_account.data_explorer.email
}

output "hmac_access_id" {
  value = google_storage_hmac_key.data_bucket_reader.access_id
}

output "hmac_secret" {
  value     = google_storage_hmac_key.data_bucket_reader.secret
  sensitive = true
}
