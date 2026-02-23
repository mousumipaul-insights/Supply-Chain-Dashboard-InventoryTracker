"""
sql_connector.py
-----------------
Database connection helpers for PostgreSQL and MySQL.
Loads inventory data from SQL into pandas DataFrames.
Author: Mousumi Paul | Feb 2025
"""

import os
import pandas as pd


# ── PostgreSQL ────────────────────────────────────────────────

def get_pg_engine(host: str = "localhost", port: int = 5432,
                  dbname: str = "supply_chain_db",
                  user: str = "postgres", password: str = None):
    """
    Create a SQLAlchemy engine for PostgreSQL.
    Install: pip install sqlalchemy psycopg2-binary
    """
    try:
        from sqlalchemy import create_engine
        pwd = password or os.getenv("PG_PASSWORD", "postgres")
        url = f"postgresql+psycopg2://{user}:{pwd}@{host}:{port}/{dbname}"
        engine = create_engine(url)
        return engine
    except ImportError:
        raise ImportError("Install sqlalchemy and psycopg2-binary: pip install sqlalchemy psycopg2-binary")


def get_mysql_engine(host: str = "localhost", port: int = 3306,
                     dbname: str = "supply_chain_db",
                     user: str = "root", password: str = None):
    """
    Create a SQLAlchemy engine for MySQL.
    Install: pip install sqlalchemy pymysql
    """
    try:
        from sqlalchemy import create_engine
        pwd = password or os.getenv("MYSQL_PASSWORD", "")
        url = f"mysql+pymysql://{user}:{pwd}@{host}:{port}/{dbname}"
        engine = create_engine(url)
        return engine
    except ImportError:
        raise ImportError("Install sqlalchemy and pymysql: pip install sqlalchemy pymysql")


# ── Query Runners ─────────────────────────────────────────────

def load_inventory_dashboard(engine) -> pd.DataFrame:
    """Load current inventory status from vw_inventory_dashboard."""
    query = """
        SELECT
            snapshot_date, product_name, category_code,
            current_stock, eoq_qty, safety_stock, reorder_point,
            days_of_supply, stockout_risk_pct, excess_stock,
            excess_holding_cost, total_inventory_cost, alert_status,
            recommended_action
        FROM vw_inventory_dashboard
        ORDER BY snapshot_date DESC, category_code
    """
    return pd.read_sql(query, engine)


def load_sales_trend(engine, year: int = 2024) -> pd.DataFrame:
    """Load monthly sales data."""
    query = f"""
        SELECT
            sale_date, month_num, month_label, year,
            product_name, category_code,
            total_units, total_revenue, mom_growth_pct
        FROM vw_sales_trend
        WHERE year = {year}
        ORDER BY year, month_num, category_code
    """
    return pd.read_sql(query, engine)


def load_low_stock_alerts(engine) -> pd.DataFrame:
    """Load current low-stock alerts."""
    query = """
        SELECT *
        FROM vw_low_stock_alerts
        ORDER BY alert_priority, stockout_risk_pct DESC
    """
    return pd.read_sql(query, engine)


def load_supplier_performance(engine) -> pd.DataFrame:
    """Load supplier scorecard data."""
    query = """
        SELECT *
        FROM vw_supplier_performance
        ORDER BY on_time_delivery_pct DESC
    """
    return pd.read_sql(query, engine)


def load_purchase_orders(engine, status: list = None) -> pd.DataFrame:
    """Load purchase order pipeline."""
    status_filter = ""
    if status:
        quoted = ", ".join(f"'{s}'" for s in status)
        status_filter = f"WHERE po_status IN ({quoted})"
    query = f"""
        SELECT
            po.po_number, p.product_name, p.category_code,
            s.supplier_name, po.order_date, po.expected_date,
            po.actual_date, po.quantity_ordered, po.total_cost_inr,
            po.po_status, po.lead_time_actual
        FROM fact_purchase_orders po
        JOIN dim_products   p ON p.product_id  = po.product_id
        JOIN dim_suppliers  s ON s.supplier_id = po.supplier_id
        {status_filter}
        ORDER BY po.expected_date
    """
    return pd.read_sql(query, engine)


def refresh_inventory_snapshot(engine, snapshot_date: str = None):
    """
    Call sp_refresh_inventory_snapshot() stored procedure (PostgreSQL).
    snapshot_date: 'YYYY-MM-DD' string, defaults to CURRENT_DATE
    """
    from sqlalchemy import text
    date_param = f"'{snapshot_date}'" if snapshot_date else "CURRENT_DATE"
    with engine.connect() as conn:
        conn.execute(text(f"CALL sp_refresh_inventory_snapshot({date_param})"))
        conn.commit()
    print(f"✅ Inventory snapshot refreshed for {snapshot_date or 'today'}")


def print_alert_summary(engine):
    """Print a quick console alert report."""
    df = load_low_stock_alerts(engine)
    print("\n" + "="*60)
    print("🚨 LOW-STOCK ALERT REPORT")
    print("="*60)
    for _, row in df.iterrows():
        print(f"  [{row['alert_status']:8}] {row['product_name']:<25} "
              f"Stock: {row['current_stock']:>5} | ROP: {row['reorder_point']:>5} | "
              f"Days Supply: {row['days_of_supply']:>5}")
    print("="*60)


# ── Fallback: Load from CSV ───────────────────────────────────

def load_from_csv(data_dir: str = "data/raw") -> dict:
    """Fallback when DB is unavailable — loads from local CSVs."""
    return {
        "inventory": pd.read_csv(f"{data_dir}/inventory_params.csv"),
        "sales":     pd.read_csv(f"{data_dir}/sales_data_2024.csv"),
    }
