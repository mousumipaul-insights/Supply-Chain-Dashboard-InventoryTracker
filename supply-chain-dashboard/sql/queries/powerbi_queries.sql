-- ============================================================
-- Power BI DirectQuery Queries
-- Author : Mousumi Paul | Feb 2025
-- Usage  : Import into Power BI via PostgreSQL connector
-- ============================================================

-- ── Query 1: Main Dashboard Table ────────────────────────────
-- Used by: Inventory Health table visual, KPI cards
SELECT
    snapshot_date,
    product_name,
    category_code,
    category_name,
    current_stock,
    eoq_qty,
    safety_stock,
    reorder_point,
    days_of_supply,
    stockout_risk_pct,
    excess_stock,
    excess_holding_cost,
    annual_holding_cost,
    annual_ordering_cost,
    total_inventory_cost,
    alert_status,
    recommended_action
FROM vw_inventory_dashboard
ORDER BY snapshot_date DESC, category_code;


-- ── Query 2: Monthly Sales Trend ─────────────────────────────
-- Used by: Demand trend line chart, MoM growth chart
SELECT
    month_label,
    month_num,
    year,
    product_name,
    category_code,
    total_units,
    total_revenue,
    avg_daily_units,
    mom_growth_pct
FROM vw_sales_trend
ORDER BY year, month_num, category_code;


-- ── Query 3: Low-Stock Alerts ─────────────────────────────────
-- Used by: Alert banner, conditional formatting table
SELECT
    alert_generated_at,
    product_name,
    category_code,
    current_stock,
    reorder_point,
    safety_stock,
    days_of_supply,
    stockout_risk_pct,
    alert_status,
    alert_priority,
    action_message
FROM vw_low_stock_alerts
ORDER BY alert_priority, stockout_risk_pct DESC;


-- ── Query 4: Supplier Performance ────────────────────────────
-- Used by: Supplier scorecard table
SELECT
    supplier_name,
    supplier_code,
    product_name,
    category_code,
    agreed_lead_time_days,
    actual_lead_time_days,
    lead_time_variance,
    on_time_delivery_pct,
    total_orders,
    total_spend_inr,
    avg_actual_lead_time,
    supplier_grade,
    rating
FROM vw_supplier_performance
ORDER BY on_time_delivery_pct DESC;


-- ── Query 5: KPI Summary Cards ────────────────────────────────
-- Used by: KPI card visuals at top of dashboard
SELECT
    total_products,
    critical_count,
    reorder_count,
    healthy_count,
    avg_days_supply,
    total_excess_units,
    total_excess_holding_cost,
    total_annual_inv_cost
FROM vw_kpi_summary;


-- ── Query 6: Purchase Order Pipeline ─────────────────────────
-- Used by: Inbound pipeline table
SELECT
    po.po_number,
    p.product_name,
    p.category_code,
    s.supplier_name,
    po.order_date,
    po.expected_date,
    po.actual_date,
    po.quantity_ordered,
    po.total_cost_inr,
    po.po_status,
    po.lead_time_actual,
    po.expected_date - CURRENT_DATE AS days_until_arrival
FROM fact_purchase_orders po
JOIN dim_products           p  ON p.product_id  = po.product_id
JOIN dim_suppliers          s  ON s.supplier_id = po.supplier_id
WHERE po.po_status IN ('PENDING', 'IN_TRANSIT')
ORDER BY po.expected_date;


-- ── Query 7: Rolling 3-Month Average Demand ──────────────────
-- Used by: Rolling demand line chart
SELECT
    product_name,
    category_code,
    month_label,
    total_units                                                   AS actual_units,
    AVG(total_units) OVER (
        PARTITION BY category_code
        ORDER BY year, month_num
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    )                                                             AS rolling_3m_avg,
    AVG(total_units) OVER (
        PARTITION BY category_code
        ORDER BY year, month_num
        ROWS BETWEEN 5 PRECEDING AND CURRENT ROW
    )                                                             AS rolling_6m_avg
FROM vw_sales_trend
ORDER BY category_code, year, month_num;
