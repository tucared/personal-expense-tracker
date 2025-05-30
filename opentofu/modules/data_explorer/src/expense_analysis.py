import plotly.express as px
import streamlit as st

from database import get_in_memory_tables, get_query_dataframe


# --- EXPENSE ANALYSIS COMPONENTS ---
def render_expense_analysis():
    """Render the expense analysis tab with cumulative expenses plot."""
    st.title("Expense Analysis")

    # Check if expenses table exists
    in_memory_tables = get_in_memory_tables()
    expenses_table = None
    for schema, table in in_memory_tables:
        if table == "expenses":
            expenses_table = f"{schema}.{table}"
            break

    if not expenses_table:
        st.warning("No expenses table found. Please make sure the data is loaded.")
        return

    # Month filter
    st.subheader("Cumulative Expenses Over Time")

    # Get available months from the data
    months_query = f"""
    SELECT DISTINCT DATE_TRUNC('month', properties__date__date__start::DATE) as month
    FROM {expenses_table}
    WHERE properties__date__date__start IS NOT NULL
    ORDER BY month DESC
    """

    months_df = get_query_dataframe(months_query)
    if months_df is None or months_df.empty:
        st.error("Could not load month data from expenses table")
        return

    # Convert to list of months for selectbox
    available_months = months_df["month"].dt.strftime("%Y-%m").tolist()

    # Month selection
    selected_month = st.selectbox(
        "Select Month:", options=available_months, index=0 if available_months else None
    )

    if selected_month:
        # Query for cumulative expenses data
        cumulative_query = f"""
        WITH daily_expenses AS (
            SELECT
                properties__date__date__start::DATE as expense_date,
                SUM(properties__amount__number) as daily_total
            FROM {expenses_table}
            WHERE properties__date__date__start IS NOT NULL
                AND DATE_TRUNC('month', properties__date__date__start::DATE) = '{selected_month}-01'::DATE
            GROUP BY properties__date__date__start::DATE
            ORDER BY expense_date
        ),
        cumulative_expenses AS (
            SELECT
                expense_date,
                daily_total,
                SUM(daily_total) OVER (ORDER BY expense_date) as cumulative_total,
                EXTRACT(DAY FROM expense_date) as day_of_month
            FROM daily_expenses
        )
        SELECT
            day_of_month,
            cumulative_total
        FROM cumulative_expenses
        ORDER BY day_of_month
        """

        df = get_query_dataframe(cumulative_query)

        if df is not None and not df.empty:
            # Create the plot
            fig = px.line(
                df,
                x="day_of_month",
                y="cumulative_total",
                title=f"Cumulative Expenses for {selected_month}",
                labels={
                    "day_of_month": "Day of Month",
                    "cumulative_total": "Cumulative Expenses",
                },
            )
            fig.update_traces(mode="lines+markers")
            fig.update_layout(
                xaxis_title="Day of Month",
                yaxis_title="Cumulative Expenses",
                height=500,
            )

            st.plotly_chart(fig, use_container_width=True)

            # Show summary statistics
            st.subheader("Summary")
            col1, col2, col3 = st.columns(3)
            with col1:
                st.metric("Total Expenses", f"{df['cumulative_total'].iloc[-1]:.2f}")
            with col2:
                avg_daily = df["cumulative_total"].iloc[-1] / len(df)
                st.metric("Average Daily", f"{avg_daily:.2f}")
            with col3:
                st.metric("Days with Expenses", len(df))
        else:
            st.info(f"No expense data found for {selected_month}")
