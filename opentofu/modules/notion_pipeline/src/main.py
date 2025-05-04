import dlt
import functions_framework
from notion import notion_databases


@functions_framework.http
def notion_pipeline(request):
    """Loads all databases from a Notion workspace which have been shared with
    an integration.
    """
    pipeline = dlt.pipeline(
        pipeline_name="notion_pipeline",
        destination="filesystem",
        dataset_name="raw",
    )
    expenses = notion_databases()
    expenses_info = pipeline.run(expenses, table_name="expenses")
    print(expenses_info)

    return "Pipeline run successfully!"
