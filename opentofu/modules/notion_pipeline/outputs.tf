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

output "sa_email_cloud_scheduler" {
  description = "Email of service account used by Cloud Scheduler when invoking Cloud Function"
  value       = google_service_account.cloud_scheduler.email
}

output "scheduler_dlt_region" {
  description = "Region of Cloud Scheduler to trigger Cloud Function with append strategy"
  value       = google_cloud_scheduler_job.dlt.region
}

output "sa_email_cloud_function" {
  description = "Email of service account used when running the Cloud Function"
  value       = google_service_account.cloud_function.email
}
