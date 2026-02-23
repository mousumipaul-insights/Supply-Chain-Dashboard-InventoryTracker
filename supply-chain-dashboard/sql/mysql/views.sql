-- ============================================================
-- MySQL Views: Supply Chain Dashboard
-- Author : Mousumi Paul | Feb 2025
-- Compatible: MySQL 8.0+
-- ============================================================

USE supply_chain_db;

-- ── View 1: Main Inventory Dashboard ─────────────────────────
CREATE OR REPLACE VIEW vw_inventory_dashboard AS
SELECT
    i.snapshot_date,
    p.product_id,
    p.product_name,
    p.category_code,
    p.category_name,
    p.unit_cost_inr,
    p.holding_cost_pct,
    ROUND(p.unit_cost_inr * p.holding_cost_pct, 2)             AS holding_cost_per_unit,
    i.current_stock,
    i.eoq_qty,
    i.safety_stock,
    i.reorder_point,
    i.daily_demand,
    i.lead_time_days,
    GREATEST(0, i.current_stock - (i.reorder_point + i.eoq_qty)) AS excess_stock,
    ROUND(GREATEST(0, 1.0 - i.current_stock / NULLIF(i.reorder_point,0)) * 100, 2)
                                                                AS stockout_risk_pct,
    CASE
        WHEN i.current_stock < i.safety_stock  THEN 'CRITICAL'
        WHEN i.current_stock < i.reorder_point THEN 'REORDER'
        WHEN i.current_stock > (i.reorder_point + i.eoq_qty) THEN 'EXCESS'
        ELSE 'HEALTHY'
    END                                                         AS alert_status,
    ROUND(i.current_stock / NULLIF(i.daily_demand, 0), 1)      AS days_of_supply,
    ROUND(
        (i.eoq_qty / 2.0 + i.safety_stock) * (p.unit_cost_inr * p.holding_cost_pct)
      + (p.annual_demand / NULLIF(i.eoq_qty, 0)) * 2500
    , 2)                                                        AS total_inventory_cost
FROM fact_inventory i
JOIN dim_products   p ON p.product_id = i.product_id;


-- ── View 2: Low-Stock Alert Feed ─────────────────────────────
CREATE OR REPLACE VIEW vw_low_stock_alerts AS
SELECT
    NOW()                                                      AS alert_generated_at,
    p.product_name,
    p.category_code,
    i.current_stock,
    i.safety_stock,
    i.reorder_point,
    i.eoq_qty,
    CASE
        WHEN i.current_stock < i.safety_stock  THEN 'CRITICAL'
        WHEN i.current_stock < i.reorder_point THEN 'REORDER'
        ELSE 'EXCESS'
    END                                                        AS alert_status,
    ROUND(i.current_stock / NULLIF(i.daily_demand, 0), 1)     AS days_of_supply,
    CASE
        WHEN i.current_stock < i.safety_stock  THEN 1
        WHEN i.current_stock < i.reorder_point THEN 2
        ELSE 3
    END                                                        AS alert_priority
FROM fact_inventory i
JOIN dim_products   p ON p.product_id = i.product_id
WHERE i.snapshot_date = (SELECT MAX(snapshot_date) FROM fact_inventory)
  AND (i.current_stock < i.reorder_point
       OR i.current_stock > (i.reorder_point + i.eoq_qty))
ORDER BY alert_priority, i.current_stock ASC;


-- ── View 3: Monthly Sales Trend ──────────────────────────────
CREATE OR REPLACE VIEW vw_sales_trend AS
SELECT
    s.sale_date,
    YEAR(s.sale_date)                                          AS year,
    MONTH(s.sale_date)                                         AS month_num,
    DATE_FORMAT(s.sale_date, '%b-%Y')                         AS month_label,
    p.product_name,
    p.category_code,
    SUM(s.units_sold)                                          AS total_units,
    SUM(s.revenue_inr)                                         AS total_revenue
FROM fact_sales   s
JOIN dim_products p ON p.product_id = s.product_id
GROUP BY s.sale_date, p.product_id, p.product_name, p.category_code
ORDER BY s.sale_date, p.product_name;


-- ── View 4: Supplier Performance ─────────────────────────────
CREATE OR REPLACE VIEW vw_supplier_performance AS
SELECT
    sup.supplier_code,
    sup.supplier_name,
    p.product_name,
    p.category_code,
    sup.agreed_lead_time_days,
    sup.actual_lead_time_days,
    sup.actual_lead_time_days - sup.agreed_lead_time_days      AS lead_time_variance,
    sup.on_time_delivery_pct,
    COUNT(po.po_id)                                            AS total_orders,
    COALESCE(SUM(po.total_cost_inr), 0)                       AS total_spend_inr,
    sup.rating,
    CASE
        WHEN sup.on_time_delivery_pct >= 90 THEN 'Excellent'
        WHEN sup.on_time_delivery_pct >= 80 THEN 'Good'
        WHEN sup.on_time_delivery_pct >= 70 THEN 'Average'
        ELSE 'Poor'
    END                                                        AS performance_band
FROM dim_suppliers              sup
JOIN dim_products                p   ON p.product_id   = sup.product_id
LEFT JOIN fact_purchase_orders   po  ON po.supplier_id = sup.supplier_id
GROUP BY sup.supplier_id, sup.supplier_name, p.product_name,
         p.category_code, sup.agreed_lead_time_days,
         sup.actual_lead_time_days, sup.on_time_delivery_pct, sup.rating;
