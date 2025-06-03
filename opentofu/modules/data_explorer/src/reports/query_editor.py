import streamlit as st
from database import get_duckdb_memory

st.title("📝 Query Editor")

# Get database connection
duckdb_conn = get_duckdb_memory()

# Initialize query state
if "current_query" not in st.session_state:
    st.session_state["current_query"] = "SHOW ALL TABLES;"

# Show available tables
with st.expander("Available Tables", expanded=False):
    tables_result = duckdb_conn.execute("SHOW ALL TABLES;").fetchall()
    if tables_result:
        # Simple table list with click-to-query
        for table_info in tables_result[:10]:  # Limit to first 10 tables
            schema, table = table_info[1], table_info[2]
            if st.button(f"{schema}.{table}", key=f"table_{schema}_{table}"):
                st.session_state["current_query"] = f"FROM {schema}.{table} LIMIT 100;"
                st.rerun()
    else:
        st.info("No tables found")

# Query input
query = st.text_area(
    "SQL Query:",
    value=st.session_state["current_query"],
    height=150,
    placeholder="FROM table_name LIMIT 10;",
)

# Execute button
if st.button("Execute", type="primary"):
    if query.strip():
        try:
            with st.spinner("Running query..."):
                df = duckdb_conn.execute(query).df()

            if len(df) > 0:
                st.success(f"Found {len(df)} rows")
                st.dataframe(df, use_container_width=True)
            else:
                st.info("No results found")

        except Exception as e:
            st.error(f"Query error: {str(e)}")
    else:
        st.warning("Please enter a query")
