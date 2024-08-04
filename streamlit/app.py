import os

import duckdb
import streamlit_authenticator as stauth  # type: ignore
import yaml
from yaml.loader import SafeLoader

import streamlit as st

BQ_PROJECT_ID = os.getenv("BQ_PROJECT_ID", "placeholder-project-id")
BQ_DATASET_ID = os.getenv("BQ_DATASET_ID", "placeholder-dataset-id")

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
    st.write(f'Welcome *{st.session_state["name"]}*')
    st.title("Powered by DuckDB")

    con = duckdb.connect()
    con.install_extension("bigquery", repository="community")
    con.load_extension("bigquery")
    # To change for prepared statement
    con.execute(
        f"ATTACH 'project={BQ_PROJECT_ID}' AS bq (TYPE bigquery, READ_ONLY);"
    ).fetchone()

    st.header("Streamlit Hello World")
    x = st.slider("Select a value")
    result = con.execute("SELECT $1*$1", [x]).fetchone()
    if result is not None:
        st.write(result[0])

    st.header("SQL Query")
    st.text("Example queries")
    st.code("SELECT 42;", language="sql")
    st.code("SHOW ALL TABLES;", language="sql")
    st.code(
        f"SELECT * FROM bigquery_query('bq', 'SELECT * FROM\n{BQ_DATASET_ID}.INFORMATION_SCHEMA.TABLES');",
        language="sql",
    )
    st.code(
        f"SUMMARIZE SELECT * FROM bq.{BQ_DATASET_ID}.raw_transactions__duplicated",
        language="sql",
    )
    query = st.text_area("Enter your query", "SHOW ALL TABLES;", height=100)
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
