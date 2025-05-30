import time
import streamlit as st
from database import get_in_memory_tables, get_query_dataframe, refresh_data


# --- DATA NAVIGATOR COMPONENTS ---
def render_data_navigator():
    """Render the data navigation components."""
    col1, col2 = st.columns([3, 1])
    with col1:
        st.subheader("Available Tables")
    with col2:
        # Initialize refresh state
        if "refresh_state" not in st.session_state:
            st.session_state.refresh_state = "idle"  # idle, loading, success

        # Determine button text and state based on refresh state
        if st.session_state.refresh_state == "idle":
            button_text = "Refresh Data"
            button_disabled = False
        elif st.session_state.refresh_state == "loading":
            button_text = "🔄 Refreshing..."
            button_disabled = True
        elif st.session_state.refresh_state == "success":
            button_text = "✅ Done"
            button_disabled = True

        if st.button(button_text, key="refresh_tables", disabled=button_disabled):
            st.session_state.refresh_state = "loading"
            st.rerun()

        # Handle the actual refresh process
        if st.session_state.refresh_state == "loading":
            refresh_data()
            st.session_state.refresh_state = "success"
            st.rerun()
        elif st.session_state.refresh_state == "success":
            # Show success state for 2 seconds, then reset
            time.sleep(2)
            st.session_state.refresh_state = "idle"
            st.rerun()

    # Display In-Memory Tables section
    in_memory_tables = get_in_memory_tables()
    if in_memory_tables:
        # Group tables by schema
        schema_tables = {}
        for schema, table in in_memory_tables:
            if schema in ("pg_catalog", "information_schema"):
                continue  # Skip system schemas

            if schema not in schema_tables:
                schema_tables[schema] = []
            schema_tables[schema].append(table)

        # Display tables in expandable sections
        for schema in sorted(schema_tables.keys()):
            tables = schema_tables[schema]
            with st.expander(f"{schema} ({len(tables)} tables)", expanded=True):
                # Create columns for table buttons
                cols = st.columns(3)
                for i, table in enumerate(sorted(tables)):
                    with cols[i % 3]:
                        if st.button(
                            table,
                            key=f"table_{schema}_{table}",
                            help=f"Click to query {schema}.{table}",
                            use_container_width=True,
                        ):
                            st.session_state["current_query"] = (
                                f"SELECT * FROM {schema}.{table} LIMIT 100;"
                            )
                            st.rerun()
    else:
        st.info("No tables loaded. Click Refresh Data to load data.")


def render_query_editor():
    """Render the query editor and results area."""
    # Data Navigator
    render_data_navigator()

    # Query Section
    st.subheader("SQL Query")

    # Initialize query state if needed
    if "current_query" not in st.session_state:
        st.session_state["current_query"] = "SHOW ALL TABLES;"

    # Store previous query state
    if "_previous_query" not in st.session_state:
        st.session_state["_previous_query"] = ""

    # Query editor
    query = st.text_area(
        "Enter your SQL query:",
        value=st.session_state["current_query"],
        height=200,
        key="sql_query_input",
        placeholder="SELECT * FROM schema.table_name LIMIT 10;",
    )

    # Execute query button and quick actions
    col1, col2, col3 = st.columns([2, 2, 2])
    with col1:
        execute_pressed = st.button(
            "Execute Query", type="primary", use_container_width=True
        )
    with col2:
        if st.button("Show Tables", use_container_width=True):
            st.session_state["current_query"] = "SHOW ALL TABLES;"
            st.rerun()
    with col3:
        if st.button("Clear Query", use_container_width=True):
            st.session_state["current_query"] = ""
            st.rerun()

    # Handle query execution
    query_changed = query != st.session_state["_previous_query"]
    if execute_pressed or query_changed:
        st.session_state["_previous_query"] = query
        st.session_state["current_query"] = query

        if query.strip():  # Only execute if query is not empty
            with st.spinner("Executing query..."):
                df = get_query_dataframe(query)

            # Results section
            st.subheader("Results")
            if df is not None:
                if df.empty:
                    st.info("Query executed successfully but returned no results")
                else:
                    col1, col2 = st.columns([3, 1])
                    with col1:
                        st.success(f"Query returned {len(df)} rows")
                    with col2:
                        if len(df) > 1000:
                            st.warning("Large result set - showing first 1000 rows")

                    st.dataframe(
                        df.head(1000) if len(df) > 1000 else df,
                        use_container_width=True,
                        height=400,
                    )
