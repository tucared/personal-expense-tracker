import streamlit as st
from auth import setup_authentication
from expense_analysis import render_expense_analysis
from query_editor import render_query_editor

# --- CONFIGURATION ---
st.set_page_config(page_title="DuckDB Data Explorer", page_icon="📊")


# --- MAIN APP FUNCTION ---
def main():
    """Main application entry point."""
    # Setup authentication
    authenticator, _ = setup_authentication()

    # Check authentication status
    if st.session_state["authentication_status"]:
        # Run refresh_data on app startup if not already loaded
        if "tables_loaded" not in st.session_state:
            from database import refresh_data

            st.session_state["tables_loaded"] = True
            refresh_data()

        # Simple header
        col1, col2 = st.columns([4, 1])
        with col1:
            st.title("📊 DuckDB Data Explorer")
        with col2:
            authenticator.logout("Logout", key="logout_button")

        # Create tabs
        tab1, tab2 = st.tabs(["Query Editor", "Expense Analysis"])

        with tab1:
            render_query_editor()

        with tab2:
            render_expense_analysis()

    elif st.session_state["authentication_status"] is False:
        st.error("Username/password is incorrect")
    elif st.session_state["authentication_status"] is None:
        st.warning("Please enter your username and password")


if __name__ == "__main__":
    main()
