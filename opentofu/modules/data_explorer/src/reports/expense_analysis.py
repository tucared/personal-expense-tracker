import plotly.express as px
import streamlit as st
from database import get_duckdb_memory

st.title("💰 Daily Expenses")

# Get database connection
duckdb_conn = get_duckdb_memory()

expenses = duckdb_conn.sql("""
    SELECT
        date:properties__date__date__start::DATE,
        date_month:strftime(properties__date__date__start::DATE, '%Y-%m'),
        amount: COALESCE(properties__amount__number, properties__amount_brl__number / eur_brl)
    FROM raw.expenses
    ASOF JOIN raw.rate ON properties__date__date__start::DATE >= date::DATE
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
                        cumulative_amount: SUM(amount) OVER (PARTITION BY date_month ORDER BY date)""")
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
            labels={"x": "Day", "y": "Cumulative Amount (EUR)"},
        )
        
        # Format y-axis to show EUR
        fig.update_layout(yaxis_tickformat="€,.0f")
        fig.update_traces(hovertemplate="<b>%{x}</b><br>Amount: €%{y:,.2f}<extra></extra>")

        st.plotly_chart(fig, use_container_width=True)

        # Show total
        st.metric("Total Expenses", f"€{amounts[-1]:,.2f}")
    else:
        st.info(f"No expenses found for {selected_month}")
