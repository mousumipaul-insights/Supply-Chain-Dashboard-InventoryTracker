-- ============================================================
-- Tableau Custom SQL Queries
-- Author : Mousumi Paul | Feb 2025
-- Connection: PostgreSQL via JDBC/ODBC
-- ============================================================

-- ── Custom SQL 1: Inventory Health (Tableau Main Data Source) ─
SELECT
    d.snapshot_date,
    p.product_name,
    p.category_code,
    p.category_name,
    d.current_stock,
    d.eoq_qty,
    d.safety_stock,
    d.reorder_point,
    d.days_of_supply,
    d.stockout_risk_pct,
    d.excess_stock,
    d.excess_holding_cost,
    d.total_inventory_cost,
    d.alert_status,
    d.recommended_action,
    -- Tableau-specific: stock status numeric for color encoding
    CASE d.alert_status
        WHEN 'CRITICAL' THEN 1
        WHEN 'REORDER'  THEN 2
        WHEN 'EXCESS'   THEN 3
        ELSE                 4
    END                                               AS status_code,
    -- Stock vs ROP ratio (for gauge charts)
    ROUND(d.current_stock::NUMERIC / NULLIF(d.reorder_point,0) * 100, 1)
                                                      AS stock_vs_rop_pct
FROM vw_inventory_dashboard d
JOIN dim_products p ON p.category_code = d.category_code
ORDER BY d.snapshot_date DESC, p.category_code;


-- ── Custom SQL 2: Sales & Demand (Tableau Line Sheet) ─────────
SELECT
    s.sale_date,
    EXTRACT(YEAR  FROM s.sale_date)::INT              AS year,
    EXTRACT(MONTH FROM s.sale_date)::INT              AS month_num,
    TO_CHAR(s.sale_date, 'Mon YYYY')                  AS month_year,
    TO_CHAR(s.sale_date, 'Q')::INT                    AS quarter,
    p.product_name,
    p.category_name,
    SUM(s.units_sold)                                 AS units_sold,
    SUM(s.revenue_inr)                                AS revenue_inr,
    -- Tableau running total (can also do in calculated field)
    SUM(SUM(s.units_sold)) OVER (
        PARTITION BY p.product_id
        ORDER BY s.sale_date
    )                                                 AS cumulative_units
FROM fact_sales   s
JOIN dim_products p ON p.product_id = s.product_id
GROUP BY s.sale_date, p.product_id, p.product_name, p.category_name
ORDER BY s.sale_date, p.product_name;


-- ── Custom SQL 3: Supplier Scorecard (Tableau Bar Chart) ──────
SELECT
    sup.supplier_name,
    p.product_name,
    p.category_code,
    sup.agreed_lead_time_days,
    sup.actual_lead_time_days,
    sup.actual_lead_time_days - sup.agreed_lead_time_days AS lt_variance,
    sup.on_time_delivery_pct,
    sup.rating,
    COUNT(po.po_id)                                   AS order_count,
    COALESCE(SUM(po.total_cost_inr), 0)               AS total_spend,
    CASE
        WHEN sup.on_time_delivery_pct >= 90 THEN 'Excellent'
        WHEN sup.on_time_delivery_pct >= 80 THEN 'Good'
        WHEN sup.on_time_delivery_pct >= 70 THEN 'Average'
        ELSE                                     'Poor'
    END                                               AS performance_band
FROM dim_suppliers             sup
JOIN dim_products               p   ON p.product_id   = sup.product_id
LEFT JOIN fact_purchase_orders  po  ON po.supplier_id  = sup.supplier_id
GROUP BY
    sup.supplier_id, sup.supplier_name, p.product_name,
    p.category_code, sup.agreed_lead_time_days,
    sup.actual_lead_time_days, sup.on_time_delivery_pct, sup.rating
ORDER BY sup.on_time_delivery_pct DESC;


-- ── Custom SQL 4: EOQ Cost Curve Data (Tableau Path Chart) ────
-- Generates data points for EOQ cost curve visualization
WITH product_params AS (
    SELECT
        p.product_id,
        p.product_name,
        p.annual_demand,
        p.unit_cost_inr * p.holding_cost_pct AS holding_cost_pu,
        2500                                  AS ordering_cost,
        ROUND(SQRT(2.0 * p.annual_demand * 2500
                   / (p.unit_cost_inr * p.holding_cost_pct))) AS eoq
    FROM dim_products p
),
order_qty_range AS (
    SELECT generate_series(50, 800, 25) AS order_qty
)
SELECT
    pp.product_name,
    oq.order_qty,
    pp.eoq                                             AS optimal_eoq,
    ROUND((oq.order_qty / 2.0) * pp.holding_cost_pu, 2)
                                                       AS holding_cost,
    ROUND((pp.annual_demand::NUMERIC / oq.order_qty) * pp.ordering_cost, 2)
                                                       AS ordering_cost,
    ROUND(
        (oq.order_qty / 2.0) * pp.holding_cost_pu
        + (pp.annual_demand::NUMERIC / oq.order_qty) * pp.ordering_cost
    , 2)                                               AS total_cost
FROM product_params pp
CROSS JOIN order_qty_range oq
ORDER BY pp.product_name, oq.order_qty;
