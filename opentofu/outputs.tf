output "bucket_name" {
  description = "Name of bucket containing cloud function state file"
  value       = google_storage_bucket.cloud_function.name
}

output "bq_table_id" {
  description = "Name of destination table for Notion data"
  value       = local.bq_table_id
}

output "bq_table_id_colon" {
  description = "Name of destination table for Notion data, colon style"
  value       = "${var.project_id}:${var.bq_dataset_id}.${var.bq_notion_table_name}"
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

output "scheduler_append_name" {
  description = "Name of Cloud Scheduler to trigger Cloud Function with append strategy"
  value       = google_cloud_scheduler_job.append.name
}

output "scheduler_append_region" {
  description = "Region of Cloud Scheduler to trigger Cloud Function with append strategy"
  value       = google_cloud_scheduler_job.append.region
}

output "scheduler_full_refresh_name" {
  description = "Name of Cloud Scheduler to trigger Cloud Function with full strategy"
  value       = google_cloud_scheduler_job.full_refresh.name
}

output "scheduler_full_refresh_region" {
  description = "Region of Cloud Scheduler to trigger Cloud Function with full strategy"
  value       = google_cloud_scheduler_job.full_refresh.region
}

output "sa_email_cloud_function" {
  description = "Email of service account used when running the Cloud Function"
  value       = google_service_account.cloud_function.email
}

output "sa_email_cloud_scheduler" {
  description = "Email of service account used by Cloud Scheduler when invoking Cloud Function"
  value       = google_service_account.cloud_scheduler.email
}

output "sa_email_tofu" {
  description = "Email of service account used whe running tofu commands"
  value       = local.tofu_service_account
}