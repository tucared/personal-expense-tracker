variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "data_bucket_name" {
  description = "Name of the GCS bucket containing parquet files"
  type        = string
}