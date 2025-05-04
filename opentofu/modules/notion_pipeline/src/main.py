import dlt
import functions_framework
from notion import notion_databases


@functions_framework.http
def notion_pipeline(request):
    """Loads all databases from a Notion workspace which have been shared with
    an integration.
    """
    pipeline = dlt.pipeline(
        pipeline_name="notion",
        destination="filesystem",
        dataset_name="notion_data",
    )
    data = notion_databases()
    info = pipeline.run(data)
    print(info)

    return "Pipeline run successfully!"
