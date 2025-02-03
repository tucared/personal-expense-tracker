import functions_framework

from notion_pipeline import load_databases


@functions_framework.http
def notion_pipeline(request):
    load_databases()
    return "Pipeline run successfully!"
