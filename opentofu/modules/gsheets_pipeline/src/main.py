import dlt
import functions_framework
from google_sheets import google_spreadsheet


@functions_framework.http
def gsheets_pipeline(request):
    """Loads Google Sheets data using Iceberg format."""
    
    pipeline = dlt.pipeline(
        pipeline_name="gsheets_pipeline",
        destination="filesystem",
        dataset_name="raw",
    )
    
    source = google_spreadsheet(range_names=["Data", "Rate"])
    
    # Configure monthly_category_amounts with Iceberg
    source.resources["Data"].apply_hints(
        table_name="monthly_category_amounts",
        table_format="iceberg",  # Enable Iceberg format
        write_disposition="replace",  # Budget data typically replaces entirely
    )
    
    # Configure rate data with Iceberg  
    source.resources["Rate"].apply_hints(
        table_name="rate",
        table_format="iceberg",  # Enable Iceberg format
        write_disposition="replace",  # Rate data typically replaces entirely
    )

    load_info = pipeline.run(source)
    print(load_info)

    return "Pipeline run successfully!"
