import plotly.graph_objects as go
import streamlit as st
from database import get_duckdb_memory

# ============================================================================
# PAGE CONFIGURATION
# ============================================================================

st.set_page_config(initial_sidebar_state="collapsed")
st.title("💰 Expense Tracker")

# ============================================================================
# DATABASE CONNECTION
# ============================================================================

duckdb_conn = get_duckdb_memory()

# ============================================================================
# DATA PREPARATION - Using DuckDB Relational API
# ============================================================================
# Note: DuckDB automatically caches external files, so we don't need to cache
# the base data loading. We only cache computed/aggregated results.


def prepare_base_expenses():
    """
    Prepare base expenses data with currency conversion.
    Uses SQL for ASOF JOIN as it's not directly available in relational API.
    Returns a DuckDB relation (not materialized).
    """
    return duckdb_conn.sql("""
        SELECT
            date:properties__date__date__start,
            category:properties__category__select__name,
            date_month:strftime(properties__date__date__start, '%Y-%m'),
            amount: ROUND(
                IF(properties__credit__checkbox, -1, 1) *
                COALESCE(properties__amount__number, properties__amount_brl__number / eur_brl),
                2
            )
        FROM raw.expenses
        ASOF JOIN raw.rate ON properties__date__date__start >= raw.rate.date
    """)


def prepare_monthly_budget():
    """
    Load monthly budget data from raw source.
    Returns a DuckDB relation (not materialized).
    """
    return duckdb_conn.sql("""
        SELECT
            date_month:strftime(month, '%Y-%m'),
            category,
            budget:ROUND(budget_eur, 2)
        FROM raw.monthly_category_amounts
    """)


# Load base data - these remain as DuckDB relations (lazy evaluation)
# DuckDB's external file cache handles the underlying data caching
expenses = prepare_base_expenses()
expenses_without_allowances = expenses.filter("category NOT LIKE 'Allowance%'")
monthly_budget = prepare_monthly_budget()

# Build data transformations - these are still DuckDB relations (lazy)
# Aggregate expenses by month and category
monthly_expenses = expenses.aggregate(
    "date_month, category, amount: SUM(amount)"
).select("date_month, category, amount")

# Join budget with expenses to calculate remaining budget
monthly_category_budget_and_expenses = monthly_budget.join(
    monthly_expenses, condition="date_month, category", how="left"
).select("""
        date_month,
        category,
        budget,
        expenses: COALESCE(amount, 0),
        remaining_budget: COALESCE(budget, 0) - COALESCE(amount, 0)
    """)

# Filter out allowances for main budget tracking
monthly_category_budget_and_expenses_without_allowances = (
    monthly_category_budget_and_expenses.filter("category NOT LIKE 'Allowance%'")
)

# ============================================================================
# CACHED COMPUTATIONS
# ============================================================================
# We cache computed results that aggregate data or involve expensive operations.
# Base data doesn't need caching as DuckDB handles external file caching.


@st.cache_data
def get_allowances():
    """
    Calculate total allowances across all months.
    Cached because it's an aggregation across all historical data.
    """
    return (
        monthly_category_budget_and_expenses.filter("category LIKE 'Allowance%'")
        .aggregate("category, allowance_left: SUM(budget) - SUM(expenses)")
        .select("category, allowance_left")
        .fetchall()  # Materialize here for caching
    )


@st.cache_data
def get_available_months():
    """
    Get list of available months from expenses data.
    Cached because it's a distinct operation across all data.
    """
    return (
        expenses.select("date_month")
        .distinct()
        .order("date_month DESC")
        .df()["date_month"]
        .tolist()  # Materialize as list for sidebar
    )


@st.cache_data
def get_monthly_totals(selected_month: str):
    """
    Get total budget and category breakdown for a specific month.
    Also calculates total spent for metrics display.
    Cached per month to avoid recomputing aggregations.
    """
    # Get total monthly budget
    total_budget = (
        monthly_category_budget_and_expenses_without_allowances.filter(
            f"date_month = '{selected_month}'"
        )
        .aggregate("total_budget: SUM(budget)")
        .fetchone()[0]
        or 0
    )

    # Get total spent (sum of expenses without allowances)
    total_spent = (
        monthly_category_budget_and_expenses_without_allowances.filter(
            f"date_month = '{selected_month}'"
        )
        .aggregate("total_spent: SUM(expenses)")
        .fetchone()[0]
        or 0
    )

    # Get category breakdown for the month
    category_breakdown = (
        monthly_category_budget_and_expenses_without_allowances.filter(
            f"date_month = '{selected_month}'"
        )
        .order("remaining_budget DESC")
        .select("category, budget, expenses, remaining_budget")
        .df()  # Materialize for caching
    )

    return total_budget, total_spent, category_breakdown


@st.cache_data
def get_daily_chart_data(selected_month: str, total_monthly_budget: float):
    """
    Calculate daily expense tracking data for charts.
    Cached per month as it involves complex window functions and date generation.

    Uses SQL for complex window functions and date generation that aren't
    available in relational API.
    """
    return duckdb_conn.sql(f"""
        WITH month_dates AS (
            -- Generate all days in the month
            SELECT UNNEST(generate_series(
                DATE '{selected_month}-01',
                LAST_DAY(DATE '{selected_month}-01'),
                INTERVAL 1 DAY
            )) AS date
        ),
        daily_expenses AS (
            -- Calculate cumulative expenses for days with transactions
            SELECT
                date,
                SUM(amount) OVER (ORDER BY date) AS cumulative_expenses
            FROM expenses_without_allowances
            WHERE date_month = '{selected_month}'
        ),
        days_in_month AS (
            -- Get total days for projection calculation
            SELECT DAY(LAST_DAY(DATE '{selected_month}-01')) AS total_days
        ),
        daily_projection AS (
            -- Calculate projected budget rundown
            SELECT
                md.date,
                {total_monthly_budget} -
                ({total_monthly_budget} / dim.total_days * (DAY(md.date) - 1))
                AS projected_budget_remaining
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
    """).fetchall()  # Materialize for caching


# ============================================================================
# UI COMPONENTS - ALLOWANCES
# ============================================================================

# Get and display allowances
allowances = get_allowances()

if allowances and len(allowances) >= 2:
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

# ============================================================================
# UI COMPONENTS - MONTH SELECTOR
# ============================================================================

# Setup month selector in sidebar
month_options = get_available_months()

# Use container to prevent sidebar from auto-expanding
with st.sidebar:
    selected_month = st.selectbox("Select Month:", month_options)

# ============================================================================
# UI COMPONENTS - MONTHLY VIEW
# ============================================================================

if selected_month:
    # Get cached monthly totals and category breakdown (lightweight operation)
    total_monthly_budget, total_spent, category_df = get_monthly_totals(selected_month)
    actual_budget_remaining = total_monthly_budget - total_spent

    # ========================================================================
    # METRICS DISPLAY (before any heavy chart calculations)
    # ========================================================================

    # Display top metrics
    col1, col2, col3 = st.columns(3)
    with col1:
        st.metric("Total Budget", f"€{total_monthly_budget:,.2f}", border=True)
    with col2:
        st.metric("Total Spent", f"€{total_spent:,.2f}", border=True)
    with col3:
        st.metric("Budget Remaining", f"€{actual_budget_remaining:,.2f}", border=True)

    # ========================================================================
    # CHART SECTION (heavier computation, loaded only when needed)
    # ========================================================================

    # Get cached daily chart data (more expensive operation)
    daily_chart_data = get_daily_chart_data(selected_month, total_monthly_budget)

    if daily_chart_data:
        # Separate actual vs projected data for chart
        actual_data = [(row[0], float(row[2])) for row in daily_chart_data if row[4]]
        actual_days = [d[0] for d in actual_data]
        actual_budget_remaining_daily = [d[1] for d in actual_data]

        projected_days = [row[0] for row in daily_chart_data]
        projected_budget = [float(row[3]) for row in daily_chart_data]

        # Create chart
        fig = go.Figure()

        # Add actual budget line
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

        # Configure chart layout
        fig.update_layout(
            title=f"Monthly Budget Tracking - {selected_month}",
            xaxis_title="Date",
            yaxis_title="Amount (EUR)",
            yaxis_tickformat="€,.0f",
            hovermode="x unified",
            legend=dict(yanchor="top", y=0.99, xanchor="right", x=0.99),
        )

        st.plotly_chart(fig, use_container_width=True)

    # ========================================================================
    # CATEGORY BREAKDOWN TABLE
    # ========================================================================

    def color_cell_background(val):
        """Apply conditional formatting to remaining budget column."""
        if val < 0:
            return "background-color: #ffebee"  # Light red for overspent
        elif val > 0:
            return "background-color: #e8f5e8"  # Light green for underspent
        return ""

    # Display category breakdown (already materialized from cache)
    st.dataframe(
        category_df.style.map(color_cell_background, subset=["remaining_budget"]),
        column_config={
            "category": st.column_config.TextColumn("Category"),
            "budget": st.column_config.NumberColumn("Budget", format="€ %.2f"),
            "expenses": st.column_config.NumberColumn("Spent", format="€ %.2f"),
            "remaining_budget": st.column_config.NumberColumn("Left", format="€ %.2f"),
        },
        use_container_width=True,
        hide_index=True,
    )
