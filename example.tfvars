# tofu apply -var-file=example.tfvars
# -------------------------------------------------------

# Variables to set (no default defined)
notion_database_id  = "xxxxxxxxxxxxxx"
notion_secret_value = "secret_XXXXXX"
project_id          = "test-project-opentofu"

# Variables that contain defaults
bq_dataset_id          = "budget"
bq_location            = "EU"
bq_notion_table_name   = "raw_transactions__duplicated"
destination_state_file = "last_update_time.txt"
cloud_function_parameters = {
  entrypoint = "insert_notion_pages_to_bigquery"
  name       = "notion-to-bigquery"
  runtime    = "python311"
  source     = "cloud-functions/notion-to-bigquery"
}
cloud_scheduler_parameters = {
  count    = 1
  name     = "cloud-function-invoker"
  schedule = "0 * * * *"
  region   = "europe-west6"
}
gsm_notion_secret_name        = "NOTION_INTEGRATION_SECRET"
region                        = "europe-west9"
sa_account_id_cloud_function  = "sa-cloud-function"
sa_account_id_cloud_scheduler = "sa-cloud-scheduler"
sa_tofu                       = "tofu-sa"
zone                          = "europe-west9-a"