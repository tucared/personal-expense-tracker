import datetime
import logging
import os
import re
from typing import Optional

import duckdb
import streamlit as st
from google.cloud import storage

# --- ENVIRONMENT VARIABLES ---
GCS_BUCKET_NAME = os.getenv("GCS_BUCKET_NAME")
HMAC_ACCESS_ID = os.getenv("HMAC_ACCESS_ID")
HMAC_SECRET = os.getenv("HMAC_SECRET")


# --- DATABASE CONNECTION ---
@st.cache_resource(ttl=datetime.timedelta(hours=1), max_entries=2)
def get_duckdb_memory(session_id: Optional[str] = None) -> duckdb.DuckDBPyConnection:
    """
    Set a caching resource which will be refreshed
     - either at each hour
     - either at each third call
     - either when the connection is established for a new session_id
    """

    duckdb_conn = duckdb.connect()
    prepare_duckdb(duckdb_conn=duckdb_conn)

    return duckdb_conn


def prepare_duckdb(duckdb_conn: duckdb.DuckDBPyConnection) -> duckdb.DuckDBPyConnection:
    duckdb_conn.sql("INSTALL httpfs;")
    duckdb_conn.sql("LOAD httpfs;")

    # Prepared statements fail for creating secrets
    # https://github.com/duckdb/duckdb/issues/13459
    duckdb_conn.execute(
        f"CREATE SECRET (TYPE GCS, KEY_ID '{HMAC_ACCESS_ID}', SECRET '{HMAC_SECRET}')"
    )

    # Load all tables/views on connection creation
    create_gcs_views(duckdb_conn)

    return duckdb_conn


def create_gcs_views(duckdb_conn: duckdb.DuckDBPyConnection) -> None:
    """
    Create DuckDB views for each parquet file in the GCS bucket.
    Uses ADC for authentication and fails fast on any error.
    Auto-detects prefixes by scanning the bucket structure.

    Args:
        duckdb_conn: DuckDB connection with GCS access configured
    """

    # Initialize GCS client (uses ADC)
    client = storage.Client()
    bucket = client.bucket(GCS_BUCKET_NAME)

    # Get all parquet files and detect valid ones
    valid_files = []
    ambiguous_files = []

    for blob in bucket.list_blobs():
        if blob.name.endswith(".parquet"):
            if _is_valid_structure(blob.name):
                valid_files.append(blob.name)
            else:
                ambiguous_files.append(blob.name)

    # Log warnings for ambiguous files
    for file_path in ambiguous_files:
        logging.warning(f"Ambiguous file structure, skipping: {file_path}")

    if not valid_files:
        raise ValueError(f"No valid parquet files found in bucket '{GCS_BUCKET_NAME}'")

    # Extract all unique schemas from view names and create them
    schemas = set()
    for file_path in valid_files:
        view_name = _extract_view_name(file_path)
        if "." in view_name:
            schema_name = view_name.split(".")[0]
            schemas.add(schema_name)

    # Create all schemas first
    for schema in schemas:
        duckdb_conn.execute(f"CREATE SCHEMA IF NOT EXISTS {schema}")

    # Create views for valid files
    for file_path in valid_files:
        view_name = _extract_view_name(file_path)
        gcs_path = f"gcs://{GCS_BUCKET_NAME}/{file_path}"

        # Create the view
        create_view_sql = f"""
        CREATE OR REPLACE VIEW {view_name} AS
        SELECT * FROM read_parquet('{gcs_path}')
        """

        # Fail fast - let any exception bubble up
        duckdb_conn.execute(create_view_sql)


def _is_valid_structure(file_path: str) -> bool:
    """
    Check if file path follows expected structure: prefix/table_name/timestamp.hash.parquet

    Returns True if valid, False if ambiguous.
    """
    parts = file_path.split("/")

    # Need at least 3 parts: prefix/table/filename
    if len(parts) < 3:
        return False

    # Check if filename matches timestamp.hash pattern
    filename = parts[-1]
    filename_without_ext = filename.rsplit(".parquet", 1)[0]

    # Pattern: numbers.numbers.alphanumeric (timestamp.hash)
    pattern = r"^\d+\.\d+\.[a-zA-Z0-9]+$"

    return bool(re.match(pattern, filename_without_ext))


def _extract_view_name(file_path: str) -> str:
    """
    Extract view name from file path by removing timestamp and hash suffix.

    Examples:
        raw/expenses/1748614244.989846.6b6faba454.parquet -> raw.expenses
        raw/expenses__properties__name__title/1748614244.989846.2690c0b4b6.parquet -> raw.expenses__properties__name__title
    """
    # Remove the .parquet extension
    path_without_extension = file_path.rsplit(".parquet", 1)[0]

    # Split by '/' to separate directory structure from filename
    parts = path_without_extension.split("/")

    # The filename contains timestamp.hash pattern - remove it
    if len(parts) >= 2:
        directory_parts = parts[:-1]  # Everything except the filename

        # Join directory parts with dots instead of slashes for view name
        view_name = ".".join(directory_parts)
        return view_name

    # This should not happen with valid files, but be explicit
    raise ValueError(f"Cannot extract view name from file path: {file_path}")
