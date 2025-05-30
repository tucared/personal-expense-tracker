output "function_uri" {
  description = "URI of the deployed cloud function"
  value       = google_cloudfunctions2_function.this.service_config[0].uri
}

output "function_name" {
  description = "Name of the deployed cloud function"
  value       = google_cloudfunctions2_function.this.name
}

output "scheduler_job_name" {
  description = "Name of the cloud scheduler job"
  value       = google_cloud_scheduler_job.this.name
}

output "scheduler_service_account_email" {
  description = "Service account email used by the cloud scheduler"
  value       = google_service_account.cloud_scheduler.email
}
