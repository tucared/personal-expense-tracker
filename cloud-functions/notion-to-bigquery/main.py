import json
import os
from datetime import datetime

import functions_framework  # type: ignore
from dotenv import load_dotenv
from gcloud import (
    access_secret_version,
    read_text_file_from_gcs,
    upload_blob_from_memory,
)
from google.api_core.exceptions import NotFound
from google.cloud import bigquery
from notion import updated_notion_pages

load_dotenv()

# GOOGLE_APPLICATION_CREDENTIALS used locally, IAM binding used in cloud
bigquery_client = bigquery.Client()

# Google Cloud destination table
PROJECT_ID = os.environ["PROJECT_ID"]
TABLE_ID = os.environ["BQ_TABLE_ID"]

# Notion database ID and secret information
NOTION_DATABASE_ID = os.environ["NOTION_DATABASE_ID"]
NOTION_INTEGRATION_SECRET = access_secret_version(
    PROJECT_ID, os.environ["GSM_NOTION_SECRET_NAME"], "latest"
)

# Path to file containing Notion pages to append to BigQuery table
DATA_FILE_PATH = "data/notion_pages.jsonl"

# Information about state file containing last update time
BUCKET_NAME = os.environ["BUCKET_NAME"]
DESTINATION_BLOB_NAME = os.environ["DESTINATION_BLOB_NAME_STATE_FILE"]


@functions_framework.http
def insert_notion_pages_to_bigquery(request):
    # Refresh type is used to determine whether to refresh all pages or new and updated
    full_refresh = request.args.get("full_refresh")

    # Get last update time from Cloud Storage
    if full_refresh == "true":
        last_update_time = None
    else:
        last_update_time = read_text_file_from_gcs(BUCKET_NAME, DESTINATION_BLOB_NAME)

    # Query Notion pages edited since that time
    os.makedirs(os.path.dirname(DATA_FILE_PATH), exist_ok=True)
    query_timestamp = datetime.utcnow().isoformat()
    pages_count = 0
    with open(DATA_FILE_PATH, "w") as outfile:
        for notion_page in updated_notion_pages(
            NOTION_INTEGRATION_SECRET,
            NOTION_DATABASE_ID,
            last_update_time,
        ):
            json.dump(notion_page, outfile)
            outfile.write("\n")
            pages_count += 1

    # Update state file in Cloud Storage
    upload_blob_from_memory(BUCKET_NAME, query_timestamp, DESTINATION_BLOB_NAME)

    if pages_count > 0:
        # BigQuery load job config
        job_config = bigquery.LoadJobConfig()
        job_config.source_format = bigquery.SourceFormat.NEWLINE_DELIMITED_JSON

        # Overwrite all table data if full refresh, otherwise append
        if full_refresh == "true":
            job_config.write_disposition = bigquery.WriteDisposition.WRITE_TRUNCATE
        else:
            job_config.write_disposition = bigquery.WriteDisposition.WRITE_APPEND

        # If table exists, use its schema, otherwise autodetect
        try:
            table = bigquery_client.get_table(TABLE_ID)
            job_config.schema = table.schema
            message_prefix = ""
        except NotFound:
            job_config.autodetect = True
            message_prefix = "Table has been created!\n"

        # Create BigQuery job to load data from
        with open(DATA_FILE_PATH, "rb") as source_file:
            job = bigquery_client.load_table_from_file(
                source_file, TABLE_ID, job_config=job_config
            )

        job.result()  # Waits for the job to complete.

        return (
            message_prefix
            + (
                "Rows inserted:    {}\n"
                "State file loc.:  {}\n"
                "Saved timestamp:  {}\n"
                "BigQuery job ID:  {}\n"
                "Bigquery dest.:   {}"
            ).format(
                pages_count,
                f"gs://{BUCKET_NAME}/{DESTINATION_BLOB_NAME}",
                query_timestamp,
                job.job_id,
                job.destination,
            ),
            201,
        )
    else:
        return (
            (
                "No rows inserted\n" "State file loc.:  {}\n" "Saved timestamp:  {}"
            ).format(
                f"gs://{BUCKET_NAME}/{DESTINATION_BLOB_NAME}",
                query_timestamp,
            ),
            204,
        )
