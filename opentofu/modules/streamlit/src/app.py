import os

import duckdb
import streamlit_authenticator as stauth  # type: ignore
import yaml
from yaml.loader import SafeLoader

from google.cloud import storage
from typing import List

import streamlit as st

GCS_BUCKET_NAME = os.getenv("GCS_BUCKET_NAME")
HMAC_ACCESS_ID = os.getenv("HMAC_ACCESS_ID")
HMAC_SECRET = os.getenv("HMAC_SECRET")

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

    con = duckdb.connect()
    con.execute("install httpfs;")  # con.install_extension() does not work
    con.execute("load httpfs;")  # con.load_extension() does not work
    con.execute(
        f"CREATE SECRET (TYPE GCS, KEY_ID '{HMAC_ACCESS_ID}', SECRET '{HMAC_SECRET}');"
    ).fetchone()

    st.header("Streamlit Hello World")
    x = st.slider("Select a value")
    result = con.execute("SELECT $1*$1", [x]).fetchone()
    if result is not None:
        st.write(result[0])

    st.header("SQL Query")
    # Get list of parquet files

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

    st.text("Example queries for available parquet files:")
    parquet_files = scan_gcs_for_parquet_files()
    for file in parquet_files:
        st.code(
            f"SELECT *\nFROM '{file}';",
            language="sql",
        )
    query = st.text_area("Enter your query", "SELECT 42;", height=100)
    if query is not None:
        try:
            # Execute query and convert to pandas DataFrame
            result = con.execute(query).df()
            if result is None:
                st.info("Query returned no results")
            else:
                st.dataframe(result)
        except Exception as e:
            st.error(f"Error executing query: {str(e)}")

elif st.session_state["authentication_status"] is False:
    st.error("Username/password is incorrect")
elif st.session_state["authentication_status"] is None:
    st.warning("Please enter your username and password")

with open("config.yaml", "w") as file:
    yaml.dump(config, file, default_flow_style=False)
