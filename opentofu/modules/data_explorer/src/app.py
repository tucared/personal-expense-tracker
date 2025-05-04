import hashlib
import os
import re
from typing import Dict, List, Optional, Tuple

import duckdb
import streamlit as st
import streamlit_authenticator as stauth
import yaml
from google.cloud import storage
from yaml.loader import SafeLoader

# --- CONFIGURATION ---
st.set_page_config(
    page_title="DuckDB Data Explorer",
    page_icon="📊",
    layout="wide"
)

# --- ENVIRONMENT VARIABLES ---
GCS_BUCKET_NAME = os.getenv("GCS_BUCKET_NAME")
HMAC_ACCESS_ID = os.getenv("HMAC_ACCESS_ID")
HMAC_SECRET = os.getenv("HMAC_SECRET")

# --- CUSTOM CSS ---
st.markdown("""
    <style>
    .stButton button {
        text-align: left !important;
        justify-content: flex-start !important;
    }
    </style>
    """, unsafe_allow_html=True)

# --- DATABASE CONNECTION ---
@st.cache_resource
def get_duckdb_connection():
    """Create and configure a cached DuckDB connection."""
    con = duckdb.connect()
    con.execute("INSTALL httpfs;")
    con.execute("LOAD httpfs;")
    con.execute(
        f"CREATE SECRET (TYPE GCS, KEY_ID '{HMAC_ACCESS_ID}', SECRET '{HMAC_SECRET}');"
    )
    return con

# --- GCS DATA FUNCTIONS ---
@st.cache_data(ttl=3600)  # Cache parquet file list for 1 hour
def scan_gcs_for_parquet_files() -> List[Dict]:
    """Scan the GCS bucket for all parquet files with metadata."""
    client = storage.Client()
    bucket = client.get_bucket(GCS_BUCKET_NAME)
    blobs = bucket.list_blobs()

    parquet_files = []
    for blob in blobs:
        if blob.name.endswith(".parquet"):
            # Extract meaningful parts from the path
            path_parts = blob.name.split("/")
            filename = path_parts[-1]

            # Extract folder structure for categorization
            folder_path = "/".join(path_parts[:-1]) if len(path_parts) > 1 else ""

            # Calculate a unique ID based on path
            file_id = hashlib.md5(blob.name.encode()).hexdigest()[:8]

            # Get basic metadata
            size_kb = round(blob.size / 1024, 1)
            last_modified = blob.updated.strftime("%Y-%m-%d") if blob.updated else "Unknown"

            # Create a clean display name for the file
            display_name = re.sub(r"\d{10,}\.\d+\.\w+\.parquet$", ".parquet", filename)
            display_name = re.sub(r"\d{8,}[\.-_]", "", display_name)

            # If display name is too simplified, use original filename
            if display_name == ".parquet" or not display_name:
                display_name = filename

            parquet_files.append({
                "path": f"gs://{GCS_BUCKET_NAME}/{blob.name}",
                "name": blob.name,
                "display_name": display_name,
                "folder": folder_path,
                "size_kb": size_kb,
                "last_modified": last_modified,
                "file_id": file_id,
            })

    # Sort files by folder, then by name
    return sorted(parquet_files, key=lambda x: (x["folder"], x["name"]))

def generate_table_name(file_info: Dict) -> Tuple[str, str]:
    """Generate schema and table name from file path."""
    # Extract path parts from the file path
    path = file_info["name"]
    path_parts = path.split("/")
    
    # Default schema and table if we can't extract from path
    schema_name = "main"
    table_name = "data"
    
    # Need at least 2 parts (schema/table) to have a proper structure
    if len(path_parts) >= 2:
        # Schema is the first directory
        schema_name = path_parts[0]
        
        # Table is the second directory
        if len(path_parts) >= 3:
            table_name = path_parts[1]
        
        # Clean the names - replace non-alphanumeric chars with underscores
        schema_name = re.sub(r"[^a-zA-Z0-9_]", "_", schema_name)
        table_name = re.sub(r"[^a-zA-Z0-9_]", "_", table_name)
        
        # Ensure names start with a letter (not a number)
        if schema_name and schema_name[0].isdigit():
            schema_name = "s_" + schema_name
        if table_name and table_name[0].isdigit():
            table_name = "t_" + table_name
            
        # Remove consecutive underscores and trim
        schema_name = re.sub(r"_+", "_", schema_name).strip("_")
        table_name = re.sub(r"_+", "_", table_name).strip("_")
    
    # If any name is empty or too short, use defaults
    if not schema_name or len(schema_name) < 2:
        schema_name = "main"
    if not table_name or len(table_name) < 2:
        table_name = "data_" + file_info['file_id']
    
    return schema_name, table_name

# --- DATABASE QUERY FUNCTIONS ---
def execute_query(query: str) -> Optional[duckdb.DuckDBPyRelation]:
    """Execute a SQL query using the cached connection."""
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

def get_in_memory_tables() -> List[Tuple[str, str]]:
    """Get all tables currently loaded in memory."""
    result = execute_query("SHOW ALL TABLES;")
    if result is not None:
        df = result.df()
        # Return list of (schema, table_name) tuples
        return list(zip(df["schema"].tolist(), df["name"].tolist()))
    return []

# --- TABLE MANAGEMENT FUNCTIONS ---
def load_all_tables(parquet_files: List[Dict]):
    """Create views for external parquet files in DuckDB based on their path structure."""
    # Clear cache to ensure fresh data
    st.cache_data.clear()

    successful_loads = []
    failed_loads = []

    with st.spinner("Creating views..."):
        con = get_duckdb_connection()
        
        for file in parquet_files:
            try:
                # Generate schema and table names from file path
                schema_name, table_name = generate_table_name(file)
                
                # Create schema if needed
                con.execute(f"CREATE SCHEMA IF NOT EXISTS {schema_name};")
                
                # Create view instead of loading data into table
                qualified_view_name = f"{schema_name}.{table_name}"
                view_sql = f"CREATE OR REPLACE VIEW {qualified_view_name} AS SELECT * FROM parquet_scan('{file['path']}');"
                
                try:
                    con.execute(view_sql)
                    successful_loads.append((qualified_view_name, file))
                except Exception as e:
                    failed_loads.append((file, str(e)))
            except Exception as e:
                st.sidebar.error(f"Error processing file {file['display_name']}: {str(e)}")

    if failed_loads:
        st.sidebar.error(f"Failed to create {len(failed_loads)} views")
        with st.sidebar.expander("Failed views"):
            for file, error in failed_loads:
                st.write(f"**{file['display_name']}**: {error}")

def refresh_data():
    """Delete all views, scan GCS again, and create views accordingly."""
    try:
        con = get_duckdb_connection()
        
        # Get list of all schemas and tables
        result = execute_query("""
            SELECT table_schema, table_name
            FROM information_schema.tables
            WHERE table_schema NOT IN ('pg_catalog', 'information_schema', 'main');
        """)

        if result is not None:
            tables = result.fetchall()

            # Drop each table
            with st.sidebar.status("Refreshing data...") as status:
                for schema_name, table_name in tables:
                    try:
                        con.execute(f"DROP TABLE {schema_name}.{table_name};")
                        status.update(
                            label=f"Dropped view {schema_name}.{table_name}",
                            state="running",
                        )
                    except Exception:
                        pass
                
                # Get parquet files and load them
                parquet_files = scan_gcs_for_parquet_files()
                load_all_tables(parquet_files)
                status.update(label="Data refreshed successfully", state="complete")

        # Force refresh cache
        st.cache_data.clear()
        
    except Exception as e:
        st.sidebar.error(f"Error refreshing data: {str(e)}")

# --- AUTHENTICATION SETUP ---
def setup_authentication():
    """Set up the authentication system and handle login/logout."""
    # Load configuration file
    with open("config.yaml") as file:
        config = yaml.load(file, SafeLoader)

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
    
    # Save updated config back to the file
    with open("config.yaml", "w") as file:
        yaml.dump(config, file, default_flow_style=False)
        
    return authenticator, config

# --- SIDEBAR COMPONENTS ---
def render_sidebar():
    """Render the sidebar with data navigation components."""
    st.sidebar.title("Data Navigator")
    st.sidebar.write(f"Welcome *{st.session_state['name']}*")

    # Add the Refresh button
    if st.sidebar.button("Refresh Data", key="refresh_tables", use_container_width=True):
        refresh_data()
        st.rerun()

    # Display In-Memory Tables section
    in_memory_tables = get_in_memory_tables()
    if in_memory_tables:
        st.sidebar.markdown("### Available Tables")

        # Group tables by schema
        schema_tables = {}
        for schema, table in in_memory_tables:
            if schema in ("pg_catalog", "information_schema"):
                continue  # Skip system schemas

            if schema not in schema_tables:
                schema_tables[schema] = []
            schema_tables[schema].append(table)

        # Display tables grouped by schema
        for schema in sorted(schema_tables.keys()):
            tables = schema_tables[schema]
            with st.sidebar.expander(f"{schema} ({len(tables)})", expanded=True):
                for table in sorted(tables):
                    if st.button(
                        f"{table}",
                        key=f"table_{schema}_{table}",
                        help=f"{schema}.{table}",
                        use_container_width=True,
                    ):
                        st.session_state["current_query"] = f"FROM {schema}.{table} LIMIT 100;"

# --- MAIN APP COMPONENTS --- 
def render_query_editor():
    """Render the query editor and results area."""
    st.title("DuckDB Data Explorer")

    # Initialize query state if needed
    if "current_query" not in st.session_state:
        st.session_state["current_query"] = "SHOW ALL TABLES;"
    
    # Store previous query state
    if "_previous_query" not in st.session_state:
        st.session_state["_previous_query"] = ""

    # Query editor
    query = st.text_area(
        "Enter SQL Query",
        value=st.session_state["current_query"],
        height=150,
        key="sql_query_input",
    )

    # Execute query button
    col1, col2 = st.columns([1, 5])
    with col1:
        execute_pressed = st.button("Execute Query", use_container_width=True)
    
    # Handle query execution
    query_changed = query != st.session_state["_previous_query"]
    if execute_pressed or query_changed:
        st.session_state["_previous_query"] = query
        st.session_state["current_query"] = query

        with st.spinner("Executing query..."):
            df = get_query_dataframe(query)

        if df is not None:
            if df.empty:
                st.info("Query returned no results")
            else:
                st.write(f"Results: {len(df)} rows")
                st.dataframe(df, use_container_width=True)

# --- MAIN APP FUNCTION ---
def main():
    """Main application entry point."""
    # Setup authentication
    authenticator, config = setup_authentication()
    
    # Check authentication status
    if st.session_state["authentication_status"]:
        # Layout: sidebar for navigation, main area for queries
        # Move logout button to top right
        col1, col2 = st.columns([6, 1])
        with col2:
            authenticator.logout("Logout", key="logout_button", location="main")

        # Run refresh_data on app startup if not already loaded
        if 'tables_loaded' not in st.session_state:
            st.session_state['tables_loaded'] = True
            refresh_data()

        # Render sidebar and main content
        render_sidebar()
        
        with col1:
            render_query_editor()
            
    elif st.session_state["authentication_status"] is False:
        st.error("Username/password is incorrect")
    elif st.session_state["authentication_status"] is None:
        st.warning("Please enter your username and password")

if __name__ == "__main__":
    main()