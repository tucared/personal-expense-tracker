import plotly.express as px
import streamlit as st
from database import get_in_memory_tables, get_query_dataframe

# --- EXPENSE ANALYSIS COMPONENTS ---
st.title("📊 Expense Analysis")

# Check if expenses table exists
in_memory_tables = get_in_memory_tables()
if not in_memory_tables:
    st.warning("No tables loaded. Use the refresh button in the sidebar to load data.")
    st.stop()

expenses_table = None
for schema, table in in_memory_tables:
    if table == "expenses":
        expenses_table = f"{schema}.{table}"
        break

if not expenses_table:
    st.warning("No expenses table found. Please make sure the data is loaded.")
    st.stop()

# Auto-detect columns
struct_query = f"DESCRIBE {expenses_table}"
struct_df = get_query_dataframe(struct_query)

if struct_df is not None:
    all_columns = struct_df['column_name'].tolist()
    
    # Find date column (exclude ID columns, prefer 'start')
    date_columns = [col for col in all_columns if 'date' in col.lower() and 'id' not in col.lower()]
    preferred_date_cols = [col for col in date_columns if 'start' in col.lower()]
    date_col = preferred_date_cols[0] if preferred_date_cols else (date_columns[0] if date_columns else None)
    
    # Find amount column (prefer 'number')
    amount_columns = [col for col in all_columns if any(word in col.lower() for word in ['amount', 'number', 'value', 'cost', 'price', 'total'])]
    preferred_amount_cols = [col for col in amount_columns if 'number' in col.lower()]
    amount_col = preferred_amount_cols[0] if preferred_amount_cols else (amount_columns[0] if amount_columns else None)
    
    if not date_col or not amount_col:
        st.error("Could not find suitable date and amount columns")
        st.stop()
else:
    st.error(f"Could not describe table {expenses_table}")
    st.stop()

# Debug: Check what's in the date column
debug_query = f"""
SELECT {date_col}, COUNT(*) as count
FROM {expenses_table}
WHERE {date_col} IS NOT NULL
GROUP BY {date_col}
ORDER BY count DESC
LIMIT 10
"""
debug_df = get_query_dataframe(debug_query)
if debug_df is not None and not debug_df.empty:
    st.write("Sample date values:")
    st.dataframe(debug_df)

# Get available months - try different approaches
months_df = None

# Try 1: Direct date parsing
try:
    months_query = f"""
    SELECT DISTINCT DATE_TRUNC('month', {date_col}::DATE) as month
    FROM {expenses_table}
    WHERE {date_col} IS NOT NULL
      AND LENGTH({date_col}) >= 10
    ORDER BY month DESC
    """
    months_df = get_query_dataframe(months_query)
    if months_df is not None and not months_df.empty:
        st.success("Using direct date parsing")
except Exception as e:
    st.warning(f"Direct parsing failed: {e}")

# Try 2: TRY_CAST approach
if months_df is None or months_df.empty:
    try:
        months_query = f"""
        SELECT DISTINCT DATE_TRUNC('month', parsed_date) as month
        FROM (
            SELECT TRY_CAST({date_col} AS DATE) as parsed_date
            FROM {expenses_table}
            WHERE {date_col} IS NOT NULL
        ) subq
        WHERE parsed_date IS NOT NULL
        ORDER BY month DESC
        """
        months_df = get_query_dataframe(months_query)
        if months_df is not None and not months_df.empty:
            st.success("Using TRY_CAST parsing")
    except Exception as e:
        st.warning(f"TRY_CAST parsing failed: {e}")

if months_df is None or months_df.empty:
    st.error("No valid date data found - check the sample values above")
    st.stop()

# Month filter
available_months = months_df["month"].dt.strftime("%Y-%m").tolist()
selected_month = st.selectbox("Select Month:", options=available_months, index=0 if available_months else None)

if selected_month:
    # Query for cumulative expenses data with dynamic columns
    try:
        cumulative_query = f"""
        WITH daily_expenses AS (
            SELECT
                {date_col}::DATE as expense_date,
                SUM(CAST({amount_col} AS DOUBLE)) as daily_total
            FROM {expenses_table}
            WHERE {date_col} IS NOT NULL
                AND {amount_col} IS NOT NULL
                AND DATE_TRUNC('month', {date_col}::DATE) = '{selected_month}-01'::DATE
            GROUP BY {date_col}::DATE
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
    except Exception as e:
        st.error(f"Error running analysis query: {e}")
        df = None

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
