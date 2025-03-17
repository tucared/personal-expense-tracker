import os
from typing import List, Optional

import duckdb
import streamlit as st
import streamlit_authenticator as stauth  # type: ignore
import yaml
from google.cloud import storage
from yaml.loader import SafeLoader

GCS_BUCKET_NAME = os.getenv("GCS_BUCKET_NAME")
HMAC_ACCESS_ID = os.getenv("HMAC_ACCESS_ID")
HMAC_SECRET = os.getenv("HMAC_SECRET")


@st.cache_resource
def get_duckdb_connection():
    """Create and configure a cached DuckDB connection."""
    con = duckdb.connect()
    con.execute("install httpfs;")
    con.execute("load httpfs;")
    con.execute(
        f"CREATE SECRET (TYPE GCS, KEY_ID '{HMAC_ACCESS_ID}', SECRET '{HMAC_SECRET}');"
    ).fetchone()
    return con


@st.cache_data(ttl=3600)  # Cache parquet file list for 1 hour
def scan_gcs_for_parquet_files() -> List[str]:
    """Scan the GCS bucket for all parquet files."""
    client = storage.Client()
    bucket = client.get_bucket(GCS_BUCKET_NAME)
    blobs = bucket.list_blobs()

    parquet_files = []
    for blob in blobs:
        if blob.name.endswith(".parquet"):
            parquet_files.append(f"gs://{GCS_BUCKET_NAME}/{blob.name}")

    return parquet_files


def execute_query(query: str) -> Optional[duckdb.DuckDBPyRelation]:
    """Execute a SQL query without caching the connection object."""
    con = get_duckdb_connection()
    try:
        return con.execute(query)
    except Exception as e:
        st.error(f"Error executing query: {str(e)}")
        return None


@st.cache_data
def get_query_dataframe(query: str):
    """Execute a query and return a cached DataFrame result."""
    result = execute_query(query)
    if result is not None:
        return result.df()
    return None


# Load configuration file
with open("config.yaml") as file:
    config = yaml.load(file, Loader=SafeLoader)

authenticator = stauth.Authenticate(
    config["credentials"],
    config["cookie"]["name"],
    config["cookie"]["key"],
    config["cookie"]["expiry_days"],
)

try:
    authenticator.login()
except Exception as e:
    st.error(e)

if st.session_state["authentication_status"]:
    authenticator.logout()
    st.write(f"Welcome *{st.session_state['name']}*")
    st.title("Powered by DuckDB")

    # Get the cached DuckDB connection
    con = get_duckdb_connection()

    st.header("Streamlit Hello World")
    x = st.slider("Select a value")
    result_df = get_query_dataframe(f"SELECT {x}*{x} as result")
    if result_df is not None and not result_df.empty:
        st.write(result_df.iloc[0]["result"])

    st.header("SQL Query")
    # Get list of parquet files using cached function
    parquet_files = scan_gcs_for_parquet_files()

    st.text("Example queries for available parquet files:")
    for file in parquet_files:
        st.code(
            f"SELECT *\nFROM '{file}';",
            language="sql",
        )

    query = st.text_area("Enter your query", "SELECT 42;", height=100)
    if query:
        df = get_query_dataframe(query)
        if df is not None:
            if df.empty:
                st.info("Query returned no results")
            else:
                st.dataframe(df)

elif st.session_state["authentication_status"] is False:
    st.error("Username/password is incorrect")
elif st.session_state["authentication_status"] is None:
    st.warning("Please enter your username and password")

with open("config.yaml", "w") as file:
    yaml.dump(config, file, default_flow_style=False)
