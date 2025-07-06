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
    # Read the SQL script
    with open("duckdb_init.sql", "r") as f:
        sql_script = f.read()

    # Substitute placeholders with environment variables
    sql_script = sql_script.replace("$HMAC_ACCESS_ID", HMAC_ACCESS_ID)
    sql_script = sql_script.replace("$HMAC_SECRET", HMAC_SECRET)
    sql_script = sql_script.replace("$GCS_BUCKET_NAME", GCS_BUCKET_NAME)

    # Execute the script
    duckdb_conn.execute(sql_script)
    return duckdb_conn
