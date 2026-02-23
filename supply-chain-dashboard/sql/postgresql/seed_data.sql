-- ============================================================
-- Seed Data: Supply Chain Dashboard
-- Author : Mousumi Paul | Feb 2025
-- Run after: postgresql/schema.sql
-- ============================================================

-- ── dim_products ─────────────────────────────────────────────
INSERT INTO dim_products
    (product_name, category_code, category_name, unit_cost_inr,
     holding_cost_pct, annual_demand, demand_std_dev)
VALUES
    ('Electronics Bundle',    'P01', 'Electronics',       4500.00, 0.20, 6060, 88.00),
    ('Apparel Collection',    'P02', 'Apparel',            850.00, 0.25, 4980, 72.00),
    ('Home & Kitchen Set',    'P03', 'Home & Kitchen',    1200.00, 0.22, 4200, 55.00),
    ('Sports & Outdoors Kit', 'P04', 'Sports & Outdoors', 2200.00, 0.18, 3690,100.00),
    ('Beauty & Health Pack',  'P05', 'Beauty & Health',    650.00, 0.28, 4980, 48.00);

-- ── dim_suppliers ────────────────────────────────────────────
INSERT INTO dim_suppliers
    (supplier_code, supplier_name, product_id, agreed_lead_time_days,
     actual_lead_time_days, on_time_delivery_pct, contact_email, rating)
VALUES
    ('SUP01', 'TechSupply Co.',    1, 12, 14, 92.0, 'orders@techsupply.in',   5),
    ('SUP02', 'FashionTextiles',   2, 10, 11, 88.0, 'supply@fashiontex.in',   4),
    ('SUP03', 'HomeGoods Ltd.',    3, 14, 13, 95.0, 'contact@homegoods.in',   5),
    ('SUP04', 'SportsPro India',   4, 16, 18, 78.0, 'po@sportspro.in',        3),
    ('SUP05', 'BeautyWholesale',   5, 10, 12, 83.0, 'orders@beautywhole.in',  4);

-- ── fact_inventory (current snapshot) ───────────────────────
INSERT INTO fact_inventory
    (snapshot_date, product_id, current_stock, eoq_qty,
     safety_stock, reorder_point, daily_demand, lead_time_days)
VALUES
    ('2025-02-01', 1,  850, 183,  90, 428, 24.2400, 14),
    ('2025-02-01', 2,  420, 242,  74, 355, 19.9200, 14),
    ('2025-02-01', 3,  320, 200,  56, 291, 16.8000, 14),
    ('2025-02-01', 4,  250, 204, 103, 450, 14.7600, 14),
    ('2025-02-01', 5,  510, 330,  49, 326, 19.9200, 14);

-- ── fact_sales (Jan 2024 monthly totals as daily averages) ───
-- Electronics – Jan through Dec 2024
INSERT INTO fact_sales (sale_date, product_id, units_sold, unit_price_inr, channel)
SELECT
    date_trunc('month', d)::date + (generate_series(0, 27)) AS sale_date,
    1 AS product_id,
    CASE EXTRACT(MONTH FROM d)
        WHEN 1  THEN 14 WHEN 2  THEN 13 WHEN 3  THEN 14
        WHEN 4  THEN 15 WHEN 5  THEN 16 WHEN 6  THEN 17
        WHEN 7  THEN 17 WHEN 8  THEN 18 WHEN 9  THEN 17
        WHEN 10 THEN 19 WHEN 11 THEN 24 WHEN 12 THEN 28
    END AS units_sold,
    4500.00,
    'Online'
FROM generate_series('2024-01-01'::date, '2024-12-01'::date, '1 month'::interval) d;

-- ── fact_purchase_orders ─────────────────────────────────────
INSERT INTO fact_purchase_orders
    (po_number, product_id, supplier_id, order_date, expected_date,
     actual_date, quantity_ordered, unit_cost_inr, po_status)
VALUES
    ('PO-2025-001', 1, 1, '2025-01-10', '2025-01-24', '2025-01-26', 183, 4500.00, 'RECEIVED'),
    ('PO-2025-002', 2, 2, '2025-01-15', '2025-01-25', '2025-01-26', 242,  850.00, 'RECEIVED'),
    ('PO-2025-003', 3, 3, '2025-01-08', '2025-01-22', '2025-01-21', 200, 1200.00, 'RECEIVED'),
    ('PO-2025-004', 4, 4, '2025-01-20', '2025-02-07',          NULL, 204, 2200.00, 'IN_TRANSIT'),
    ('PO-2025-005', 5, 5, '2025-01-12', '2025-01-24', '2025-01-26', 330,  650.00, 'RECEIVED'),
    ('PO-2025-006', 3, 3, '2025-02-01', '2025-02-15',          NULL, 200, 1200.00, 'PENDING'),
    ('PO-2025-007', 4, 4, '2025-02-01', '2025-02-19',          NULL, 204, 2200.00, 'PENDING');
