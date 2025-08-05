import plotly.graph_objects as go
import streamlit as st
from database import get_duckdb_memory

st.set_page_config(initial_sidebar_state="collapsed")
st.title("💰 Expense Tracker")

# Get database connection
duckdb_conn = get_duckdb_memory()

expenses = duckdb_conn.sql("""
    SELECT
        date:properties__date__date__start,
        category:properties__category__select__name,
        date_month:strftime(properties__date__date__start, '%Y-%m'),
        amount: ROUND(IF(properties__credit__checkbox, -1, 1) * COALESCE(properties__amount__number, properties__amount_brl__number / eur_brl), 2)
    FROM raw.expenses
    ASOF JOIN raw.rate ON properties__date__date__start >= raw.rate.date
""")

expenses_without_alllowances = expenses.filter("category NOT LIKE 'Allowance%'")

monthly_expenses = expenses.aggregate(
    "date_month, category, amount: SUM(amount)"
).select("""
    date_month,
    category,
    amount""")

monthly_budget = duckdb_conn.sql("""
    SELECT
        date_month:strftime(month, '%Y-%m'),
        category,
        budget:ROUND(budget_eur,2)
    FROM raw.monthly_category_amounts""")

monthly_category_budget_and_expenses = monthly_budget.join(
    monthly_expenses, condition="date_month, category", how="left"
).select("""
    date_month,
    category,
    budget,
    expenses: COALESCE(amount, 0),
    remaining_budget: COALESCE(budget, 0) - COALESCE(amount, 0)""")


# Calculate allowances with caching - they aggregate across ALL months
@st.cache_data
def get_allowances():
    return (
        monthly_category_budget_and_expenses.filter("category LIKE 'Allowance%'")
        .aggregate("category, allowance_left: SUM(budget) - SUM(expenses)")
        .select("category, allowance_left")
        .fetchall()
    )


allowances = get_allowances()

# Show allowances
col1, col2 = st.columns(2)
with col1:
    st.metric(
        allowances[0][0],
        f"€{allowances[0][1]:,.2f}",
        border=True,
    )
with col2:
    st.metric(
        allowances[1][0],
        f"€{allowances[1][1]:,.2f}",
        border=True,
    )

# Month selector in sidebar
months_data = expenses.select("date_month").distinct().order("date_month DESC")
month_options = [row[0] for row in months_data.fetchall()]
selected_month = st.sidebar.selectbox("Select Month:", month_options)

monthly_category_budget_and_expenses_without_allowances = (
    monthly_category_budget_and_expenses.filter("category NOT LIKE 'Allowance%'")
)

if selected_month:
    # Show budget and remaining budget
    category_budget_and_expenses = (
        monthly_category_budget_and_expenses_without_allowances.filter(
            f"date_month = '{selected_month}'"
        ).order("remaining_budget DESC")
    )

    # Get total monthly budget for selected month using DuckDB
    total_monthly_budget_result = (
        monthly_category_budget_and_expenses_without_allowances.filter(
            f"date_month = '{selected_month}'"
        )
        .aggregate("total_budget: SUM(budget)")
        .fetchone()
    )
    total_monthly_budget = (
        total_monthly_budget_result[0] if total_monthly_budget_result else 0
    )

    # Get comprehensive daily data with all calculations in DuckDB
    daily_chart_data = duckdb_conn.sql(f"""
        WITH month_dates AS (
            SELECT UNNEST(generate_series(
                DATE '{selected_month}-01',
                LAST_DAY(DATE '{selected_month}-01'),
                INTERVAL 1 DAY
            )) AS date
        ),
        daily_expenses AS (
            SELECT
                date,
                SUM(amount) OVER (ORDER BY date) AS cumulative_expenses
            FROM expenses_without_alllowances
            WHERE date_month = '{selected_month}'
        ),
        days_in_month AS (
            SELECT DAY(LAST_DAY(DATE '{selected_month}-01')) AS total_days
        ),
        daily_projection AS (
            SELECT
                md.date,
                {total_monthly_budget} - ({total_monthly_budget} / dim.total_days * (DAY(md.date) - 1)) AS projected_budget_remaining
            FROM month_dates md
            CROSS JOIN days_in_month dim
        )
        SELECT
            dp.date,
            COALESCE(de.cumulative_expenses, 0) AS cumulative_expenses,
            {total_monthly_budget} - COALESCE(de.cumulative_expenses, 0) AS actual_budget_remaining,
            dp.projected_budget_remaining,
            CASE WHEN de.date IS NOT NULL THEN TRUE ELSE FALSE END AS has_expenses
        FROM daily_projection dp
        LEFT JOIN daily_expenses de ON dp.date = de.date
        ORDER BY dp.date
    """).fetchall()

    if daily_chart_data:
        # Extract the last day's cumulative expenses for metrics
        last_day_data = [
            row for row in daily_chart_data if row[4]
        ]  # has_expenses = True
        total_spent = last_day_data[-1][1] if last_day_data else 0
        actual_budget_remaining = total_monthly_budget - total_spent

        # Show top 3 metrics
        col1, col2, col3 = st.columns(3)
        with col1:
            st.metric("Total Budget", f"€{total_monthly_budget:,.2f}", border=True)
        with col2:
            st.metric("Total Spent", f"€{total_spent:,.2f}", border=True)
        with col3:
            st.metric(
                "Budget Remaining", f"€{actual_budget_remaining:,.2f}", border=True
            )

        # Prepare data for chart - separate actual and projected data
        actual_days = [
            row[0] for row in daily_chart_data if row[4]
        ]  # has_expenses = True
        actual_budget_remaining_daily = [
            float(row[2]) for row in daily_chart_data if row[4]
        ]

        projected_days = [row[0] for row in daily_chart_data]
        projected_budget = [float(row[3]) for row in daily_chart_data]

        # Create figure with plotly graph objects
        fig = go.Figure()

        # Add actual budget remaining line
        fig.add_trace(
            go.Scatter(
                x=actual_days,
                y=actual_budget_remaining_daily,
                mode="lines",
                name="Actual budget remaining",
                line=dict(color="#1f77b4", width=3),
                hovertemplate="<b>%{x}</b><br>Budget left: €%{y:,.2f}<extra></extra>",
            )
        )

        # Add projected budget line
        fig.add_trace(
            go.Scatter(
                x=projected_days,
                y=projected_budget,
                mode="lines",
                name="Projected budget rundown",
                line=dict(color="#17becf", width=2),
                hovertemplate="<b>%{x}</b><br>Projected budget: €%{y:,.2f}<extra></extra>",
            )
        )

        # Update layout
        fig.update_layout(
            title=f"Monthly Budget Tracking - {selected_month}",
            xaxis_title="Date",
            yaxis_title="Amount (EUR)",
            yaxis_tickformat="€,.0f",
            hovermode="x unified",
            legend=dict(yanchor="top", y=0.99, xanchor="right", x=0.99),
        )

        st.plotly_chart(fig, use_container_width=True)

        def color_cell_background(val):
            if val < 0:
                return "background-color: #ffebee"  # Light red background
            elif val > 0:
                return "background-color: #e8f5e8"  # Light green background
            else:
                return ""

        st.dataframe(
            category_budget_and_expenses.select(
                "category, budget, expenses, remaining_budget"
            )
            .df()
            .style.map(color_cell_background, subset=["remaining_budget"]),
            column_config={
                "category": st.column_config.TextColumn("Category"),
                "budget": st.column_config.NumberColumn("Budget", format="€ %.2f"),
                "expenses": st.column_config.NumberColumn("Spent", format="€ %.2f"),
                "remaining_budget": st.column_config.NumberColumn(
                    "Left", format="€ %.2f"
                ),
            },
            use_container_width=True,
            hide_index=True,
        )
    else:
        st.info(f"No expenses found for {selected_month}")
