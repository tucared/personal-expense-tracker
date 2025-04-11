import functions_framework

from google_sheets_pipeline import load_pipeline_with_sheets


@functions_framework.http
def google_sheets_pipeline(request):
    load_pipeline_with_sheets()
    return "Pipeline run successfully!"
