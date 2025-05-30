import streamlit as st
import streamlit_authenticator as stauth
import yaml
from yaml.loader import SafeLoader


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