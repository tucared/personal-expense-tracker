import plotly.express as px
import streamlit as st
from database import get_duckdb_memory

st.title("💰 Daily Expenses")

# Configuration
EXPENSES_TABLE = "raw.expenses"
DATE_FIELD = "properties__date__date__start"

# Get database connection
duckdb_conn = get_duckdb_memory()

# Get available months
months_data = duckdb_conn.sql(f"""
    SELECT DISTINCT
        EXTRACT(YEAR FROM CAST({DATE_FIELD} AS DATE)) as year,
        EXTRACT(MONTH FROM CAST({DATE_FIELD} AS DATE)) as month
    FROM {EXPENSES_TABLE}
    ORDER BY year DESC, month DESC
""").fetchall()

if not months_data:
    st.error("No expense data found")
    st.stop()

# Month selector
month_options = [f"{int(row[0])}-{int(row[1]):02d}" for row in months_data]
selected_month = st.selectbox("Select Month:", month_options)

if selected_month:
    year, month = selected_month.split("-")

    # Get daily cumulative expenses
    daily_data = duckdb_conn.sql(f"""
        SELECT
            EXTRACT(DAY FROM CAST({DATE_FIELD} AS DATE)) as day,
            SUM(properties__amount__number) OVER (ORDER BY CAST({DATE_FIELD} AS DATE)) as cumulative_amount
        FROM {EXPENSES_TABLE}
        WHERE EXTRACT(YEAR FROM CAST({DATE_FIELD} AS DATE)) = {year}
        AND EXTRACT(MONTH FROM CAST({DATE_FIELD} AS DATE)) = {month}
        ORDER BY CAST({DATE_FIELD} AS DATE)
    """).fetchall()

    if daily_data:
        # Create plotly chart
        days = [int(row[0]) for row in daily_data]
        amounts = [float(row[1]) for row in daily_data]

        fig = px.line(
            x=days,
            y=amounts,
            title=f"Cumulative Expenses - {selected_month}",
            labels={"x": "Day", "y": "Cumulative Amount"},
        )

        st.plotly_chart(fig, use_container_width=True)

        # Show total
        st.metric("Total Expenses", f"${amounts[-1]:,.2f}")
    else:
        st.info(f"No expenses found for {selected_month}")
