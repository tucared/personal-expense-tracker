import hashlib
import os
import re
from typing import Dict, List, Optional, Tuple

import duckdb
import streamlit as st
import streamlit_authenticator as stauth  # type: ignore
import yaml
from google.cloud import storage
from yaml.loader import SafeLoader

GCS_BUCKET_NAME = os.getenv("GCS_BUCKET_NAME")
HMAC_ACCESS_ID = os.getenv("HMAC_ACCESS_ID")
HMAC_SECRET = os.getenv("HMAC_SECRET")

# Set page configuration to wide mode
st.set_page_config(layout="wide")


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
            last_modified = (
                blob.updated.strftime("%Y-%m-%d") if blob.updated else "Unknown"
            )

            # Create a clean display name for the file
            display_name = re.sub(r"\d{10,}\.\d+\.\w+\.parquet$", ".parquet", filename)
            display_name = re.sub(r"\d{8,}[\.-_]", "", display_name)

            # If display name is too simplified, use original filename
            if display_name == ".parquet" or not display_name:
                display_name = filename

            parquet_files.append(
                {
                    "path": f"gs://{GCS_BUCKET_NAME}/{blob.name}",
                    "name": blob.name,
                    "display_name": display_name,
                    "folder": folder_path,
                    "size_kb": size_kb,
                    "last_modified": last_modified,
                    "file_id": file_id,
                }
            )

    # Sort files by folder, then by name
    return sorted(parquet_files, key=lambda x: (x["folder"], x["name"]))


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


def generate_table_name(file_info: Dict) -> str:
    """Generate a valid and clean table name from file information without adding hash."""
    # Start with the display name
    display_name = file_info["display_name"]

    # Remove file extension
    clean_name = display_name.replace(".parquet", "")

    # Replace non-alphanumeric characters with underscores
    clean_name = re.sub(r"[^a-zA-Z0-9_]", "_", clean_name)

    # Ensure the name starts with a letter (not a number)
    if clean_name and clean_name[0].isdigit():
        clean_name = "t_" + clean_name

    # Remove consecutive underscores
    clean_name = re.sub(r"_+", "_", clean_name)

    # Remove leading/trailing underscores
    clean_name = clean_name.strip("_")

    # If the name is empty or too short, use file ID with a prefix
    if not clean_name or len(clean_name) < 3:
        clean_name = f"table_{file_info['file_id']}"

    # Truncate if too long but don't add the hash suffix
    if len(clean_name) > 30:
        clean_name = clean_name[:30]

    return clean_name


def get_in_memory_tables() -> List[Tuple[str, str]]:
    """Get all tables currently loaded in memory."""
    result = execute_query("SHOW ALL TABLES;")
    if result is not None:
        df = result.df()
        # Return list of (schema, table_name) tuples
        return list(zip(df["schema"].tolist(), df["name"].tolist()))
    return []


def group_files_by_folder(files: List[Dict]) -> Dict[str, List[Dict]]:
    """Group files by their folder path for hierarchical display."""
    folders = {}

    # First pass: collect all unique folders
    for file in files:
        folder = file["folder"]
        if folder not in folders:
            folders[folder] = []
        folders[folder].append(file)

    return folders


def load_all_tables(parquet_files: List[Dict]):
    """Load all external parquet files into DuckDB tables with clean names, organized by folder structure."""
    # Clear cache to ensure fresh data
    st.cache_data.clear()

    successful_loads = []
    failed_loads = []

    with st.sidebar.status("Loading tables...") as status:
        # Group files by folder for organization
        folder_groups = {}
        for file in parquet_files:
            folder_path = file["folder"]

            # Extract first level folder from path for schema name
            schema_name = "external_data"  # Default schema
            if folder_path:
                # Extract first folder level as schema
                first_folder = folder_path.split("/")[0]
                if first_folder:
                    # Clean schema name - must be a valid SQL identifier
                    schema_name = re.sub(r"[^a-zA-Z0-9_]", "_", first_folder)
                    # Ensure schema name starts with a letter
                    if schema_name and schema_name[0].isdigit():
                        schema_name = "s_" + schema_name

            if schema_name not in folder_groups:
                folder_groups[schema_name] = []

            folder_groups[schema_name].append(file)

        # Create schemas and load tables
        con = get_duckdb_connection()
        for schema_name, files in folder_groups.items():
            try:
                # Create schema if needed
                con.execute(f"CREATE SCHEMA IF NOT EXISTS {schema_name};")

                # Load files into tables within this schema
                for file in files:
                    table_name = generate_table_name(file)
                    qualified_table_name = f"{schema_name}.{table_name}"

                    # Use read_parquet() function for more explicit handling
                    load_sql = f"CREATE OR REPLACE TABLE {qualified_table_name} AS SELECT * FROM read_parquet('{file['path']}');"

                    try:
                        con.execute(load_sql)
                        successful_loads.append((qualified_table_name, file))
                        status.update(
                            label=f"Loaded {len(successful_loads)} tables...",
                            state="running",
                        )
                    except Exception as e:
                        failed_loads.append((file, str(e)))
                        status.update(
                            label=f"Error loading {file['display_name']}",
                            state="running",
                        )
                        # Log the error and the SQL that caused it
                        with st.sidebar.expander(
                            f"Error details for {file['display_name']}"
                        ):
                            st.write(f"**Error:** {str(e)}")
                            st.write(f"**SQL:** {load_sql}")
            except Exception as e:
                st.sidebar.error(f"Error creating schema {schema_name}: {str(e)}")

        if successful_loads:
            status.update(
                label=f"Loaded {len(successful_loads)} tables successfully",
                state="complete",
            )
        else:
            status.update(label="No tables were loaded", state="error")

    if failed_loads:
        st.sidebar.error(f"Failed to load {len(failed_loads)} tables")
        with st.sidebar.expander("Failed loads"):
            for file, error in failed_loads:
                st.write(f"**{file['display_name']}**: {error}")

    # Force refresh after loading
    st.rerun()


def clear_in_memory_tables():
    """Drop all user-created tables in all schemas (except system tables)."""
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

            if not tables:
                st.sidebar.info("No tables to clear.")
                return

            # Drop each table
            with st.sidebar.status("Clearing tables...") as status:
                for schema_name, table_name in tables:
                    try:
                        con.execute(f"DROP TABLE {schema_name}.{table_name};")
                        status.update(
                            label=f"Dropped table {schema_name}.{table_name}",
                            state="running",
                        )
                    except Exception as e:
                        status.update(
                            label=f"Error dropping {schema_name}.{table_name}: {str(e)}",
                            state="error",
                        )

                status.update(label=f"Cleared {len(tables)} tables", state="complete")

            # Force refresh
            st.cache_data.clear()
            st.rerun()
    except Exception as e:
        st.sidebar.error(f"Error clearing tables: {str(e)}")


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
    # Layout: sidebar for navigation, main area for queries
    # Move logout button to top right
    col1, col2 = st.columns([6, 1])
    with col2:
        authenticator.logout()

    # Setup sidebar for table navigation
    st.sidebar.title("Data Navigator")
    st.sidebar.write(f"Welcome *{st.session_state['name']}*")

    # Get parquet files with metadata
    parquet_files = scan_gcs_for_parquet_files()

    # Add the Load All Tables, Clear Tables, and Refresh buttons
    btn_col1, btn_col2, btn_col3 = st.sidebar.columns(3)

    with btn_col1:
        if st.button(
            "Load All Tables", key="load_all_tables", use_container_width=True
        ):
            load_all_tables(parquet_files)

    with btn_col2:
        if st.button("Clear Tables", key="clear_tables", use_container_width=True):
            clear_in_memory_tables()

    with btn_col3:
        if st.button("Refresh", key="refresh_tables", use_container_width=True):
            st.cache_data.clear()
            st.rerun()

    # Custom CSS for left alignment
    st.markdown(
        """
    <style>
    .stButton button {
        text-align: left !important;
        justify-content: flex-start !important;
    }
    </style>
    """,
        unsafe_allow_html=True,
    )

    # Display In-Memory Tables section
    in_memory_tables = get_in_memory_tables()
    if in_memory_tables:
        st.sidebar.markdown("### In-Memory Tables")

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
                        st.session_state["current_query"] = (
                            f"FROM {schema}.{table} LIMIT 100;"
                        )

    # Display External Files with proper hierarchy
    if parquet_files:
        st.sidebar.markdown("### External Files")

        # Group files by folder
        folders = group_files_by_folder(parquet_files)

        # Extract and organize folder hierarchy
        folder_hierarchy = {}
        for folder_path, files in folders.items():
            if not folder_path:  # Root files
                folder_name = "Root Files"
            else:
                # Split the path and extract hierarchy parts
                path_parts = folder_path.split("/")

                # For top level, use just the first part
                folder_name = path_parts[0]

                # If there are more parts, organize subfolders
                if len(path_parts) > 1:
                    subfolder = "/".join(path_parts[1:])
                    folder_name = path_parts[0]

                    if folder_name not in folder_hierarchy:
                        folder_hierarchy[folder_name] = {}

                    if subfolder not in folder_hierarchy[folder_name]:
                        folder_hierarchy[folder_name][subfolder] = []

                    folder_hierarchy[folder_name][subfolder].extend(files)
                    continue  # Skip adding to top level

            if folder_name not in folder_hierarchy:
                folder_hierarchy[folder_name] = {}

            if "files" not in folder_hierarchy[folder_name]:
                folder_hierarchy[folder_name]["files"] = []

            folder_hierarchy[folder_name]["files"].extend(files)

        # Display the folder hierarchy
        for folder_name in sorted(folder_hierarchy.keys()):
            folder_data = folder_hierarchy[folder_name]

            # Count total files in this folder (including subfolders)
            total_files = len(folder_data.get("files", []))
            for subfolder, subfolder_files in folder_data.items():
                if subfolder != "files":
                    total_files += len(subfolder_files)

            # Create expandable section for this folder
            with st.sidebar.expander(f"{folder_name} ({total_files})", expanded=True):
                # Display files at root of this folder
                for file in sorted(
                    folder_data.get("files", []), key=lambda x: x["display_name"]
                ):
                    if st.button(
                        f"{file['display_name']}",
                        key=f"file_{file['file_id']}",
                        help=f"Size: {file['size_kb']} KB, Modified: {file['last_modified']}",
                        use_container_width=True,
                    ):
                        st.session_state["current_query"] = (
                            f"FROM '{file['path']}' LIMIT 100;"
                        )

                # Display subfolders
                for subfolder in sorted(
                    [k for k in folder_data.keys() if k != "files"]
                ):
                    subfolder_files = folder_data[subfolder]

                    # Get the last part of the subfolder path for display
                    subfolder_display = subfolder.split("/")[-1]

                    with st.sidebar.expander(
                        f"{subfolder_display} ({len(subfolder_files)})", expanded=False
                    ):
                        for file in sorted(
                            subfolder_files, key=lambda x: x["display_name"]
                        ):
                            if st.button(
                                f"{file['display_name']}",
                                key=f"file_{file['file_id']}",
                                help=f"Size: {file['size_kb']} KB, Modified: {file['last_modified']}",
                                use_container_width=True,
                            ):
                                st.session_state["current_query"] = (
                                    f"FROM '{file['path']}' LIMIT 100;"
                                )

    with col1:
        # Main content area for query and results
        st.title("DuckDB Query Explorer")

        # Ensure no 'SELECT *' in any generated queries
        if "current_query" not in st.session_state:
            st.session_state["current_query"] = "SELECT 42 AS answer;"

        # Store previous query state to detect CMD+Enter
        if "_previous_query" not in st.session_state:
            st.session_state["_previous_query"] = ""

        # Query editor
        query = st.text_area(
            "Enter SQL Query",
            value=st.session_state["current_query"],
            height=150,
            key="sql_query_input",
        )

        # Execute query button and CMD+Enter handling
        execute_pressed = st.button("Execute Query", key="execute_query")
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

elif st.session_state["authentication_status"] is False:
    st.error("Username/password is incorrect")
elif st.session_state["authentication_status"] is None:
    st.warning("Please enter your username and password")

# Save updated config back to the file
with open("config.yaml", "w") as file:
    yaml.dump(config, file, default_flow_style=False)
