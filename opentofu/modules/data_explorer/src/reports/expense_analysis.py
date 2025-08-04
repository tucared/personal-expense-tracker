import streamlit as st
from database import get_duckdb_memory

st.title("💰 Daily Expenses")

# Get database connection
duckdb_conn = get_duckdb_memory()

expenses = duckdb_conn.sql("""
    SELECT
        date:properties__date__date__start,
        category:properties__category__select__name,
        date_month:strftime(properties__date__date__start, '%Y-%m'),
        amount: IF(properties__credit__checkbox, -1, 1) * COALESCE(properties__amount__number, properties__amount_brl__number / eur_brl)
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
        budget:budget_eur
    FROM raw.monthly_category_amounts""")

monthly_category_budget_and_expenses = monthly_budget.join(
    monthly_expenses, condition="date_month, category", how="left"
).select("""
    date_month,
    category,
    budget,
    expenses: COALESCE(amount, 0),
    remaining_budget: COALESCE(budget, 0) - COALESCE(amount, 0)""")

allowances = (
    monthly_category_budget_and_expenses.filter("category LIKE 'Allowance%'")
    .aggregate("category, allowance_left: SUM(budget) - SUM(expenses)")
    .select("category, allowance_left")
)


# Show allowances
@st.fragment
def show_allowances():
    col1, col2 = st.columns(2)
    with col1:
        st.metric(
            "Allowance Max",
            f"€{allowances.filter("category = 'Allowance - Max'").fetchall()[0][1]:,.2f}",
            border=True,
        )
    with col2:
        st.metric(
            "Allowance Cla",
            f"€{allowances.filter("category = 'Allowance - Cla'").fetchall()[0][1]:,.2f}",
            border=True,
        )


show_allowances()


# Month selector
@st.fragment
def monthly_expenses():
    months_data = expenses.select("date_month").distinct().order("date_month DESC")
    month_options = [row[0] for row in months_data.fetchall()]
    selected_month = st.selectbox("Select Month:", month_options)

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

        # Get total monthly budget for selected month
        total_monthly_budget = (
            monthly_category_budget_and_expenses_without_allowances.filter(
                f"date_month = '{selected_month}'"
            )
            .aggregate("total_budget: SUM(budget)")
            .fetchall()[0][0]
        )

        # Get daily cumulative expenses for metrics calculation
        daily_data = (
            expenses_without_alllowances.select("""
                            date,
                            date_month,
                            cumulative_amount: SUM(amount) OVER (PARTITION BY date_month ORDER BY date)""")
            .filter(f"date_month = '{selected_month}'")
            .order("date")
            .fetchall()
        )

        if daily_data:
            # Show top 3 metrics first
            cumulative_expenses = [float(row[2]) for row in daily_data]
            actual_budget_remaining = total_monthly_budget - cumulative_expenses[-1]

            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Total Budget", f"€{total_monthly_budget:,.2f}", border=True)
            with col2:
                st.metric(
                    "Total Spent", f"€{cumulative_expenses[-1]:,.2f}", border=True
                )
            with col3:
                st.metric(
                    "Budget Remaining", f"€{actual_budget_remaining:,.2f}", border=True
                )
            # Show the graph second
            import plotly.graph_objects as go
            from datetime import datetime, timedelta
            import calendar

            # Create data for the chart
            days = [row[0] for row in daily_data]
            cumulative_expenses_daily = [float(row[2]) for row in daily_data]

            # Calculate actual budget remaining (total budget - cumulative expenses)
            actual_budget_remaining_daily = [
                total_monthly_budget - expense for expense in cumulative_expenses_daily
            ]

            # Create projected budget line (straight line from total budget to 0)
            first_day = datetime.strptime(f"{selected_month}-01", "%Y-%m-%d")
            year, month = first_day.year, first_day.month
            days_in_month = calendar.monthrange(year, month)[1]
            last_day = datetime.strptime(
                f"{selected_month}-{days_in_month:02d}", "%Y-%m-%d"
            )

            # Create daily projection points
            projected_days = []
            projected_budget = []
            current_day = first_day
            while current_day <= last_day:
                projected_days.append(current_day.strftime("%Y-%m-%d"))
                days_passed = (current_day - first_day).days
                daily_budget_decrease = total_monthly_budget / days_in_month
                remaining_projection = total_monthly_budget - (
                    daily_budget_decrease * days_passed
                )
                projected_budget.append(max(0, remaining_projection))
                current_day += timedelta(days=1)

            # Create figure with plotly graph objects
            fig = go.Figure()

            # Add actual budget remaining line
            fig.add_trace(
                go.Scatter(
                    x=days,
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

            # Show the table third
            def color_left_column(val):
                if val < 0:
                    return "color: red"
                elif val > 0:
                    return "color: green"
                else:
                    return ""

            df = category_budget_and_expenses.select(
                "category, budget, expenses, remaining_budget"
            ).df()

            styled_df = df.style.map(color_left_column, subset=["remaining_budget"])

            st.dataframe(
                styled_df,
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


monthly_expenses()
