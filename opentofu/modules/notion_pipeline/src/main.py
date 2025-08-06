import os

import dlt
import functions_framework
from notion import notion_databases


@functions_framework.http
def notion_pipeline(request):
    """Loads expenses from Notion database using Iceberg format with merge strategy."""
    database_id = os.environ.get("SOURCES__NOTION__DATABASE_ID")

    pipeline = dlt.pipeline(
        pipeline_name="notion_pipeline",
        destination="filesystem",
        dataset_name="raw",
    )
    
    # Configure expenses resource with Iceberg and merge strategy
    expenses = notion_databases(database_ids=[{"id": database_id}])
    
    # Apply Iceberg configuration with merge strategy
    expenses.resources[database_id].apply_hints(
        table_name="expenses",
        table_format="iceberg",  # Enable Iceberg format
        primary_key="id",  # Required for merge operations
        write_disposition={
            "disposition": "merge", 
            "strategy": "upsert"  # Use upsert for insert/update operations
        },
        # Add incremental loading with cursor
        incremental=dlt.sources.incremental(
            "last_edited_time",  # Notion's last modified field
            initial_value="1970-01-01T00:00:00.000Z"
        ),
        columns={
            "properties__amount__number": {"data_type": "double"},
            "properties__amount_brl__number": {"data_type": "double"},
            "properties__date__date__start": {"data_type": "date"},
            "properties__debit_credit__formula__number": {"data_type": "double"},
        }
    )

    expenses_info = pipeline.run(expenses)
    print(expenses_info)

    return "Pipeline run successfully!"
