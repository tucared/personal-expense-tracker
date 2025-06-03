import streamlit as st
from auth import setup_authentication

# --- CONFIGURATION ---
st.set_page_config(page_title="Personal Expense Tracker", page_icon="📊")


# --- MAIN APP FUNCTION ---
def main():
    """Main application entry point."""
    # Setup authentication
    authenticator, _ = setup_authentication()

    # Check authentication status
    if st.session_state["authentication_status"]:
        # Define the pages
        query_page = st.Page("reports/query_editor.py", title="Query Editor", icon="📝")
        expense_page = st.Page(
            "reports/expense_analysis.py", title="Expense Analysis", icon="📊"
        )

        # Set up navigation
        pg = st.navigation([query_page, expense_page])

        # Run the selected page
        pg.run()

        # Add logout button
        with st.sidebar:
            authenticator.logout("Logout", key="logout_button")

    elif st.session_state["authentication_status"] is False:
        st.error("Username/password is incorrect")
    elif st.session_state["authentication_status"] is None:
        st.warning("Please enter your username and password")


if __name__ == "__main__":
    main()
