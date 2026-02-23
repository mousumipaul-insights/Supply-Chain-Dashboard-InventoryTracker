-- ============================================================
-- SQL Views: Supply Chain Dashboard
-- Author : Mousumi Paul | Feb 2025
-- Compatible: PostgreSQL (use in MySQL with minor adjustments)
-- ============================================================

-- ── View 1: Main Inventory Dashboard ─────────────────────────
-- Primary view used by Power BI DirectQuery and Tableau
CREATE OR REPLACE VIEW vw_inventory_dashboard AS
SELECT
    i.snapshot_date,
    p.product_id,
    p.product_name,
    p.category_code,
    p.category_name,
    p.unit_cost_inr,
    p.holding_cost_pct,
    ROUND(p.unit_cost_inr * p.holding_cost_pct, 2)              AS holding_cost_per_unit,
    i.current_stock,
    i.eoq_qty,
    i.safety_stock,
    i.reorder_point,
    i.daily_demand,
    i.lead_time_days,
    i.excess_stock,
    i.stockout_risk_pct,
    i.alert_status,
    -- Annual cost model
    ROUND((i.eoq_qty / 2.0 + i.safety_stock) * (p.unit_cost_inr * p.holding_cost_pct), 2)
                                                                 AS annual_holding_cost,
    ROUND((p.annual_demand::NUMERIC / NULLIF(i.eoq_qty,0)) * 2500, 2)
                                                                 AS annual_ordering_cost,
    ROUND(
        (i.eoq_qty / 2.0 + i.safety_stock) * (p.unit_cost_inr * p.holding_cost_pct)
        + (p.annual_demand::NUMERIC / NULLIF(i.eoq_qty,0)) * 2500
    , 2)                                                         AS total_inventory_cost,
    -- Days of supply
    ROUND(i.current_stock::NUMERIC / NULLIF(i.daily_demand, 0), 1)
                                                                 AS days_of_supply,
    -- Excess holding cost
    ROUND(i.excess_stock * (p.unit_cost_inr * p.holding_cost_pct), 2)
                                                                 AS excess_holding_cost,
    -- Recommended action
    CASE i.alert_status
        WHEN 'CRITICAL' THEN 'Place emergency order immediately'
        WHEN 'REORDER'  THEN 'Place standard replenishment order'
        WHEN 'EXCESS'   THEN 'Review demand; consider promotion'
        ELSE                 'No action needed'
    END                                                          AS recommended_action
FROM fact_inventory i
JOIN dim_products   p ON p.product_id = i.product_id;


-- ── View 2: Sales Trend (for demand charts) ───────────────────
CREATE OR REPLACE VIEW vw_sales_trend AS
SELECT
    s.sale_date,
    EXTRACT(YEAR  FROM s.sale_date)::INT   AS year,
    EXTRACT(MONTH FROM s.sale_date)::INT   AS month_num,
    TO_CHAR(s.sale_date, 'Mon-YYYY')       AS month_label,
    p.product_name,
    p.category_code,
    p.category_name,
    SUM(s.units_sold)                      AS total_units,
    SUM(s.revenue_inr)                     AS total_revenue,
    AVG(s.units_sold)                      AS avg_daily_units,
    -- MoM growth using window function
    LAG(SUM(s.units_sold)) OVER (
        PARTITION BY p.product_id
        ORDER BY EXTRACT(YEAR FROM s.sale_date), EXTRACT(MONTH FROM s.sale_date)
    )                                      AS prev_month_units,
    ROUND(
        (SUM(s.units_sold) - LAG(SUM(s.units_sold)) OVER (
            PARTITION BY p.product_id
            ORDER BY EXTRACT(YEAR FROM s.sale_date), EXTRACT(MONTH FROM s.sale_date)
        ))::NUMERIC
        / NULLIF(LAG(SUM(s.units_sold)) OVER (
            PARTITION BY p.product_id
            ORDER BY EXTRACT(YEAR FROM s.sale_date), EXTRACT(MONTH FROM s.sale_date)
        ), 0) * 100
    , 2)                                   AS mom_growth_pct
FROM fact_sales    s
JOIN dim_products  p ON p.product_id = s.product_id
GROUP BY
    s.sale_date, p.product_id, p.product_name,
    p.category_code, p.category_name;


-- ── View 3: Supplier Performance ─────────────────────────────
CREATE OR REPLACE VIEW vw_supplier_performance AS
SELECT
    sup.supplier_id,
    sup.supplier_code,
    sup.supplier_name,
    p.product_name,
    p.category_code,
    sup.agreed_lead_time_days,
    sup.actual_lead_time_days,
    sup.actual_lead_time_days - sup.agreed_lead_time_days
                                            AS lead_time_variance,
    sup.on_time_delivery_pct,
    COUNT(po.po_id)                         AS total_orders,
    SUM(po.total_cost_inr)                  AS total_spend_inr,
    AVG(po.lead_time_actual)                AS avg_actual_lead_time,
    COUNT(CASE WHEN po.po_status = 'RECEIVED'
               AND po.actual_date <= po.expected_date
               THEN 1 END)::NUMERIC
    / NULLIF(COUNT(CASE WHEN po.po_status = 'RECEIVED' THEN 1 END), 0) * 100
                                            AS calculated_otd_pct,
    sup.rating,
    CASE
        WHEN sup.on_time_delivery_pct >= 90 THEN '★★★★★ Excellent'
        WHEN sup.on_time_delivery_pct >= 80 THEN '★★★★☆ Good'
        WHEN sup.on_time_delivery_pct >= 70 THEN '★★★☆☆ Average'
        ELSE                                     '★★☆☆☆ Poor'
    END                                     AS supplier_grade
FROM dim_suppliers           sup
JOIN dim_products             p   ON p.product_id    = sup.product_id
LEFT JOIN fact_purchase_orders po ON po.supplier_id  = sup.supplier_id
GROUP BY
    sup.supplier_id, sup.supplier_code, sup.supplier_name,
    p.product_name, p.category_code,
    sup.agreed_lead_time_days, sup.actual_lead_time_days,
    sup.on_time_delivery_pct, sup.rating;


-- ── View 4: Low-Stock Alert Feed ─────────────────────────────
-- Real-time alert feed for Power BI / Tableau automated alerts
CREATE OR REPLACE VIEW vw_low_stock_alerts AS
SELECT
    CURRENT_TIMESTAMP                       AS alert_generated_at,
    p.product_name,
    p.category_code,
    i.current_stock,
    i.safety_stock,
    i.reorder_point,
    i.eoq_qty,
    i.alert_status,
    ROUND(i.current_stock::NUMERIC / NULLIF(i.daily_demand,0), 1)
                                            AS days_of_supply,
    i.stockout_risk_pct,
    CASE i.alert_status
        WHEN 'CRITICAL' THEN 1
        WHEN 'REORDER'  THEN 2
        WHEN 'EXCESS'   THEN 3
        ELSE                 4
    END                                     AS alert_priority,
    CASE i.alert_status
        WHEN 'CRITICAL' THEN 'Place emergency order of ' || i.eoq_qty || ' units immediately'
        WHEN 'REORDER'  THEN 'Place order of '           || i.eoq_qty || ' units within 2 days'
        WHEN 'EXCESS'   THEN 'Review '  || i.excess_stock || ' excess units — consider promotion'
        ELSE 'No action needed'
    END                                     AS action_message
FROM fact_inventory i
JOIN dim_products   p ON p.product_id = i.product_id
WHERE i.snapshot_date = (SELECT MAX(snapshot_date) FROM fact_inventory)
ORDER BY alert_priority, i.stockout_risk_pct DESC;


-- ── View 5: KPI Summary (for Power BI KPI cards) ─────────────
CREATE OR REPLACE VIEW vw_kpi_summary AS
SELECT
    COUNT(*)                                                    AS total_products,
    COUNT(CASE WHEN alert_status = 'CRITICAL' THEN 1 END)      AS critical_count,
    COUNT(CASE WHEN alert_status = 'REORDER'  THEN 1 END)      AS reorder_count,
    COUNT(CASE WHEN alert_status = 'HEALTHY'  THEN 1 END)      AS healthy_count,
    ROUND(AVG(current_stock::NUMERIC / NULLIF(daily_demand,0)),1)
                                                                AS avg_days_supply,
    SUM(excess_stock)                                           AS total_excess_units,
    ROUND(SUM(
        excess_stock * p.unit_cost_inr * p.holding_cost_pct
    ), 2)                                                       AS total_excess_holding_cost,
    ROUND(SUM(
        (eoq_qty / 2.0 + safety_stock) * (p.unit_cost_inr * p.holding_cost_pct)
        + (p.annual_demand::NUMERIC / NULLIF(eoq_qty,0)) * 2500
    ), 2)                                                       AS total_annual_inv_cost
FROM fact_inventory i
JOIN dim_products   p ON p.product_id = i.product_id
WHERE i.snapshot_date = (SELECT MAX(snapshot_date) FROM fact_inventory);
