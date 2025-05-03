import dlt
import functions_framework
from google_sheets import google_spreadsheet


@functions_framework.http
def google_sheets_pipeline(request):
    """
    Will load all the sheets in the spreadsheet, but it will not load any of the named ranges in the spreadsheet.
    """
    pipeline = dlt.pipeline(
        pipeline_name="google_sheets_pipeline",
        destination="filesystem",
        dev_mode=True,
        dataset_name="sample_google_sheet_data",
    )
    data = google_spreadsheet(range_names=["Data"])
    info = pipeline.run(data)
    print(info)

    return "Pipeline run successfully!"
