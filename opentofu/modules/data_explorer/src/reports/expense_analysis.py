import plotly.express as px
import streamlit as st
from database import get_duckdb_memory

st.title("💰 Daily Expenses")

# Configuration
EXPENSES_TABLE = "raw.expenses"
DATE_FIELD = "properties__date__date__start"

# Get database connection
duckdb_conn = get_duckdb_memory()

expenses = duckdb_conn.sql("""
    FROM raw.expenses
    SELECT
        date:properties__date__date__start::DATE,
        date_month:strftime(properties__date__date__start::DATE, '%Y-%m'),
        amount: properties__amount__number::FLOAT
""").set_alias("expenses")

# Get available months
months_data = expenses.select("date_month").distinct().order("date_month DESC").set_alias("months_data")

# Month selector
month_options = [row[0] for row in months_data.fetchall()]
selected_month = st.selectbox("Select Month:", month_options)

if selected_month:
    # Get daily cumulative expenses
    daily_data = (
        expenses.select("""
                        date,
                        date_month,
                        cumulative_amount: SUM(amount) OVER (ORDER BY date)""")
        .filter(f"date_month = '{selected_month}'")
        .order("date")
        .fetchall()
    )

    if daily_data:
        # Create plotly chart
        days = [row[0] for row in daily_data]
        amounts = [float(row[2]) for row in daily_data]

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
