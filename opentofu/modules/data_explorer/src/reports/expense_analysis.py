import plotly.express as px
import streamlit as st
from database import get_duckdb_memory

st.title("💰 Daily Expenses")

# Get database connection
duckdb_conn = get_duckdb_memory()

expenses = duckdb_conn.sql("""
    SELECT
        date:properties__date__date__start::DATE,
        category:properties__category__select__name,
        date_month:strftime(properties__date__date__start::DATE, '%Y-%m'),
        amount: COALESCE(properties__amount__number, properties__amount_brl__number / eur_brl)
    FROM raw.expenses
    ASOF JOIN raw.rate ON properties__date__date__start::DATE >= raw.rate.date::DATE
""")

monthly_expenses = expenses.aggregate(
    "date_month, category, amount: SUM(amount)"
).select("""
    date_month,
    category,
    amount""")

monthly_budget = duckdb_conn.sql("""
    SELECT
        date_month:strftime(month::DATE, '%Y-%m'),
        category,
        budget:budget_eur
    FROM raw.monthly_category_amounts""")

monthly_category_budget_and_expenses = monthly_budget.join(
    monthly_expenses, condition="date_month, category", how="left"
).select("""
    date_month,
    category,
    budget,
    expenses: COALESCE(amount, 0),
    remaining_budget: COALESCE(budget, 0) - COALESCE(amount, 0),
    budget_consumed_ratio: COALESCE(amount, 0) / COALESCE(budget, 1)""")

allowances = monthly_category_budget_and_expenses.filter("category LIKE 'Allowance%'").aggregate(
    "category, allowance_left: SUM(budget) - SUM(expenses)"
).select("category, allowance_left")

# Show allowances
col1, col2 = st.columns(2)
with col1:
    st.metric("Allowance Max", f"€{allowances.filter("category = 'Allowance - Max'").fetchall()[0][1]:,.2f}")
with col2:
    st.metric("Allowance Cla", f"€{allowances.filter("category = 'Allowance - Cla'").fetchall()[0][1]:,.2f}")

# Month selector
months_data = expenses.select("date_month").distinct().order("date_month DESC")
month_options = [row[0] for row in months_data.fetchall()]
selected_month = st.selectbox("Select Month:", month_options)

monthly_category_budget_and_expenses_without_allowances = monthly_category_budget_and_expenses.filter(
    "category NOT LIKE 'Allowance%'")

if selected_month:
    # Show budget and remaining budget
    category_budget_and_expenses = monthly_category_budget_and_expenses_without_allowances.filter(
        f"date_month = '{selected_month}'"
    ).order("remaining_budget DESC")
    st.dataframe(
        category_budget_and_expenses.select(
            "category, budget, expenses, remaining_budget, budget_consumed_ratio"
        ).df(),
        column_config={
            "_index": st.column_config.TextColumn("Category"),
            "budget": st.column_config.NumberColumn("Budget (EUR)", format="€ %.2f"),
            "expenses": st.column_config.NumberColumn(
                "Expenses (EUR)", format="€ %.2f"
            ),
            "remaining_budget": st.column_config.NumberColumn(
                "Remaining Budget (EUR)", format="€ %.2f"
            ),
            "budget_consumed_ratio": st.column_config.ProgressColumn(
                "Remaining Ratio",
                format="percent",
                min_value=0,
                max_value=1,
            ),
        },
        use_container_width=True,
        hide_index=True,
    )

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
        fig.update_traces(
            hovertemplate="<b>%{x}</b><br>Amount: €%{y:,.2f}<extra></extra>"
        )

        st.plotly_chart(fig, use_container_width=True)

        # Show total
        st.metric("Total Expenses", f"€{amounts[-1]:,.2f}")
    else:
        st.info(f"No expenses found for {selected_month}")
