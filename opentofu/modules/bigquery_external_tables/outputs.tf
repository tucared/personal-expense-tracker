output "dataset_id" {
  description = "The ID of the BigQuery dataset"
  value       = google_bigquery_dataset.raw.dataset_id
}

output "dataset_project" {
  description = "The project of the BigQuery dataset"
  value       = google_bigquery_dataset.raw.project
}

output "expenses_table_id" {
  description = "The ID of the expenses external table"
  value       = google_bigquery_table.expenses.table_id
}

output "monthly_category_amounts_table_id" {
  description = "The ID of the monthly_category_amounts external table"
  value       = google_bigquery_table.monthly_category_amounts.table_id
}

output "rate_table_id" {
  description = "The ID of the rate external table"
  value       = google_bigquery_table.rate.table_id
}