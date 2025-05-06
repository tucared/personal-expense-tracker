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
        dataset_name="raw",
    )
    monthly_category_amounts = google_spreadsheet(range_names=["Data", "Rate"])
    monthly_category_amounts.resources["Data"].apply_hints(
        table_name="monthly_category_amounts"
    )
    monthly_category_amounts.resources["Rate"].apply_hints(table_name="rate")

    monthly_category_amounts_info = pipeline.run(monthly_category_amounts)
    print(monthly_category_amounts_info)

    return "Pipeline run successfully!"
