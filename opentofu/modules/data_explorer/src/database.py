import datetime
import os
from typing import Optional

import duckdb
import streamlit as st

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
    Create DuckDB views for hardcoded list of tables.
    Uses standard path format: gs://BUCKET_NAME/raw/{table_name}/data.parquet

    Args:
        duckdb_conn: DuckDB connection with GCS access configured
    """

    # Hardcoded list of tables
    tables = ["expenses", "monthly_category_amounts", "rate"]

    # Create raw schema
    duckdb_conn.execute("CREATE SCHEMA IF NOT EXISTS raw")

    # Create views for each table
    for table_name in tables:
        view_name = f"raw.{table_name}"
        gcs_path = f"gcs://{GCS_BUCKET_NAME}/raw/{table_name}/data.parquet"

        # Create the view
        create_view_sql = f"""
        CREATE OR REPLACE VIEW {view_name} AS
        SELECT * FROM read_parquet('{gcs_path}')
        """

        # Fail fast - let any exception bubble up
        duckdb_conn.execute(create_view_sql)
