import os

import dlt
import functions_framework
from notion import notion_databases


@functions_framework.http
def notion_pipeline(request):
    """Loads all databases from a Notion workspace which have been shared with
    an integration.
    """
    database_id = os.environ.get("SOURCES__NOTION__DATABASE_ID")

    pipeline = dlt.pipeline(
        pipeline_name="notion_pipeline",
        destination="filesystem",
        dataset_name="raw",
    )
    expenses = notion_databases(database_ids=[{"id": database_id}])

    expenses_info = pipeline.run(
        expenses,
        table_name="expenses",
        columns={
            "properties__amount__number": {"data_type": "double"},
            "properties__amount_brl__number": {"data_type": "double"},
            "properties__date__date__start": {"data_type": "date"},
            "properties__debit_credit__formula__number": {"data_type": "double"},
        },
        loader_file_format="parquet"
    )
    print(expenses_info)

    return "Pipeline run successfully!"
