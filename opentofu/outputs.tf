
output "data_bucket_name" {
  description = "Name of the data bucket"
  value       = google_storage_bucket.data_bucket.name
}

output "data_bucket_writer_service_account_email" {
  description = "Email of the service account used to write to the data bucket"
  value       = google_service_account.data_bucket_writer.email
}

output "data_bucket_writer_private_key" {
  description = "Private key of the service account (for Google Sheets auth)"
  value       = local.data_bucket_writer_private_key
  sensitive   = true
}

output "notion_pipeline_function_uri" {
  description = "URI of the Notion pipeline cloud function"
  value       = module.notion_pipeline.function_uri
}

output "gsheets_pipeline_function_uri" {
  description = "URI of the Google Sheets pipeline cloud function"
  value       = module.gsheets_pipeline.function_uri
}

output "data_explorer_service_url" {
  description = "URL of the deployed Data Explorer"
  value       = module.data_explorer.service_url
}
