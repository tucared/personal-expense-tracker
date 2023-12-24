import json
from typing import Any, Dict, Optional, Tuple, Union

import requests
from requests.adapters import HTTPAdapter, Retry


def updated_notion_pages(
    notion_integration_secret: str, database_id: str, edited_on_or_after: Optional[str]
):
    next_cursor = None
    session = requests.Session()
    retries = Retry(allowed_methods=frozenset(["GET", "POST"]))
    session.mount("https://", HTTPAdapter(max_retries=retries))

    while True:
        data, next_cursor = query_notion_database(
            session,
            notion_integration_secret,
            database_id,
            edited_on_or_after,
            next_cursor,
        )

        yield from data

        if next_cursor is None:
            break


def query_notion_database(
    session: requests.Session,
    notion_integration_secret: str,
    database_id: str,
    edited_on_or_after: Optional[str],
    start_cursor: Optional[str],
) -> Tuple[list, Union[str, None]]:
    """Queries a Notion database to return pages edited on or after a date or time.

    Args:
        session (requests.Session): Session object to use for requests.
        notion_integration_secret (str): Self-describing.
        database_id (str): Source database id to get pages from.
        edited_on_or_after (str, optional): Date to filter pages on (ISO 8601).
        start_cursor (str, optional): Start cursor to include as part of pagination.

    Returns:
        list: List of pages edited on or after provided date.
    """
    url = f"https://api.notion.com/v1/databases/{database_id}/query"

    payload_dict: Dict[str, Any] = {}
    if edited_on_or_after:
        payload_dict.update(
            {
                "filter": {
                    "timestamp": "last_edited_time",
                    "last_edited_time": {"on_or_after": edited_on_or_after},
                }
            }
        )
    if start_cursor:
        payload_dict.update({"start_cursor": start_cursor})

    payload = json.dumps(payload_dict)

    headers = {
        "Authorization": "Bearer " + notion_integration_secret,
        "Content-Type": "application/json",
        "Notion-Version": "2022-06-28",
    }

    response = session.post(url, headers=headers, data=payload)
    response_json = response.json()
    response_results = response_json.get("results", [])
    next_cursor = response_json.get("next_cursor", None)

    return (response_results, next_cursor)
