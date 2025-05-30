import os
import streamlit as st
import streamlit_authenticator as stauth
import yaml
from yaml.loader import SafeLoader


# --- AUTHENTICATION SETUP ---
def setup_authentication():
    """Set up the authentication system and handle login/logout."""
    # Get username from environment variable
    username = os.getenv("AUTH_USERNAME")
    
    # Get password from secret environment variable
    password = os.getenv("AUTH_PASSWORD")
    
    if not username or not password:
        st.error("Authentication configuration missing. Please check environment variables.")
        st.stop()
    
    # Load base configuration file for cookie settings
    with open("config.yaml") as file:
        config = yaml.load(file, SafeLoader)
    
    # Override credentials with environment variables
    config["credentials"] = {
        "usernames": {
            username: {
                "email": f"{username}@example.com",
                "first_name": username.capitalize(),
                "last_name": "User",
                "password": password
            }
        }
    }

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

    return authenticator, config