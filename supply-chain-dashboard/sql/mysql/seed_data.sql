-- ============================================================
-- Seed Data: Supply Chain Dashboard (MySQL)
-- Author : Mousumi Paul | Feb 2025
-- Run after: mysql/schema.sql
-- ============================================================

USE supply_chain_db;

-- ── dim_products ─────────────────────────────────────────────
INSERT INTO dim_products
    (product_name, category_code, category_name, unit_cost_inr,
     holding_cost_pct, annual_demand, demand_std_dev)
VALUES
    ('Electronics Bundle',    'P01', 'Electronics',       4500.00, 0.20, 6060, 88.00),
    ('Apparel Collection',    'P02', 'Apparel',            850.00, 0.25, 4980, 72.00),
    ('Home & Kitchen Set',    'P03', 'Home & Kitchen',    1200.00, 0.22, 4200, 55.00),
    ('Sports & Outdoors Kit', 'P04', 'Sports & Outdoors', 2200.00, 0.18, 3690, 100.00),
    ('Beauty & Health Pack',  'P05', 'Beauty & Health',    650.00, 0.28, 4980, 48.00);

-- ── dim_suppliers ────────────────────────────────────────────
INSERT INTO dim_suppliers
    (supplier_code, supplier_name, product_id, agreed_lead_time_days,
     actual_lead_time_days, on_time_delivery_pct, contact_email, rating)
VALUES
    ('SUP01', 'TechSupply Co.',   1, 12, 14, 92.0, 'orders@techsupply.in',  5),
    ('SUP02', 'FashionTextiles',  2, 10, 11, 88.0, 'supply@fashiontex.in',  4),
    ('SUP03', 'HomeGoods Ltd.',   3, 14, 13, 95.0, 'contact@homegoods.in',  5),
    ('SUP04', 'SportsPro India',  4, 16, 18, 78.0, 'po@sportspro.in',       3),
    ('SUP05', 'BeautyWholesale',  5, 10, 12, 83.0, 'orders@beautywhole.in', 4);

-- ── fact_inventory ───────────────────────────────────────────
INSERT INTO fact_inventory
    (snapshot_date, product_id, current_stock, eoq_qty,
     safety_stock, reorder_point, daily_demand, lead_time_days)
VALUES
    ('2025-02-01', 1,  850, 183,  90, 428, 24.2400, 14),
    ('2025-02-01', 2,  420, 242,  74, 355, 19.9200, 14),
    ('2025-02-01', 3,  320, 200,  56, 291, 16.8000, 14),
    ('2025-02-01', 4,  250, 204, 103, 450, 14.7600, 14),
    ('2025-02-01', 5,  510, 330,  49, 326, 19.9200, 14);

-- ── fact_sales (Jan-Dec 2024 monthly summaries) ──────────────
INSERT INTO fact_sales (sale_date, product_id, units_sold, unit_price_inr, channel) VALUES
-- Electronics
('2024-01-31',1,420,4500.00,'Online'),('2024-02-29',1,390,4500.00,'Online'),
('2024-03-31',1,410,4500.00,'Online'),('2024-04-30',1,450,4500.00,'Online'),
('2024-05-31',1,470,4500.00,'Online'),('2024-06-30',1,500,4500.00,'Online'),
('2024-07-31',1,520,4500.00,'Online'),('2024-08-31',1,540,4500.00,'Online'),
('2024-09-30',1,510,4500.00,'Online'),('2024-10-31',1,580,4500.00,'Online'),
('2024-11-30',1,720,4500.00,'Online'),('2024-12-31',1,850,4500.00,'Online'),
-- Apparel
('2024-01-31',2,310,850.00,'Online'),('2024-02-29',2,290,850.00,'Online'),
('2024-03-31',2,320,850.00,'Online'),('2024-04-30',2,380,850.00,'Online'),
('2024-05-31',2,420,850.00,'Online'),('2024-06-30',2,460,850.00,'Online'),
('2024-07-31',2,480,850.00,'Online'),('2024-08-31',2,500,850.00,'Online'),
('2024-09-30',2,440,850.00,'Online'),('2024-10-31',2,390,850.00,'Online'),
('2024-11-30',2,550,850.00,'Online'),('2024-12-31',2,680,850.00,'Online'),
-- Home & Kitchen
('2024-01-31',3,280,1200.00,'Online'),('2024-02-29',3,260,1200.00,'Online'),
('2024-03-31',3,275,1200.00,'Online'),('2024-04-30',3,310,1200.00,'Online'),
('2024-05-31',3,340,1200.00,'Online'),('2024-06-30',3,360,1200.00,'Online'),
('2024-07-31',3,370,1200.00,'Online'),('2024-08-31',3,380,1200.00,'Online'),
('2024-09-30',3,350,1200.00,'Online'),('2024-10-31',3,400,1200.00,'Online'),
('2024-11-30',3,490,1200.00,'Online'),('2024-12-31',3,580,1200.00,'Online'),
-- Sports & Outdoors
('2024-01-31',4,190,2200.00,'Online'),('2024-02-29',4,180,2200.00,'Online'),
('2024-03-31',4,210,2200.00,'Online'),('2024-04-30',4,280,2200.00,'Online'),
('2024-05-31',4,350,2200.00,'Online'),('2024-06-30',4,420,2200.00,'Online'),
('2024-07-31',4,460,2200.00,'Online'),('2024-08-31',4,440,2200.00,'Online'),
('2024-09-30',4,380,2200.00,'Online'),('2024-10-31',4,310,2200.00,'Online'),
('2024-11-30',4,250,2200.00,'Online'),('2024-12-31',4,220,2200.00,'Online'),
-- Beauty & Health
('2024-01-31',5,350,650.00,'Online'),('2024-02-29',5,330,650.00,'Online'),
('2024-03-31',5,355,650.00,'Online'),('2024-04-30',5,370,650.00,'Online'),
('2024-05-31',5,390,650.00,'Online'),('2024-06-30',5,410,650.00,'Online'),
('2024-07-31',5,420,650.00,'Online'),('2024-08-31',5,430,650.00,'Online'),
('2024-09-30',5,415,650.00,'Online'),('2024-10-31',5,440,650.00,'Online'),
('2024-11-30',5,510,650.00,'Online'),('2024-12-31',5,560,650.00,'Online');

-- ── fact_purchase_orders ─────────────────────────────────────
INSERT INTO fact_purchase_orders
    (po_number, product_id, supplier_id, order_date, expected_date,
     actual_date, quantity_ordered, unit_cost_inr, po_status)
VALUES
    ('PO-2025-001',1,1,'2025-01-10','2025-01-24','2025-01-26',183,4500.00,'RECEIVED'),
    ('PO-2025-002',2,2,'2025-01-15','2025-01-25','2025-01-26',242, 850.00,'RECEIVED'),
    ('PO-2025-003',3,3,'2025-01-08','2025-01-22','2025-01-21',200,1200.00,'RECEIVED'),
    ('PO-2025-004',4,4,'2025-01-20','2025-02-07', NULL,        204,2200.00,'IN_TRANSIT'),
    ('PO-2025-005',5,5,'2025-01-12','2025-01-24','2025-01-26',330, 650.00,'RECEIVED'),
    ('PO-2025-006',3,3,'2025-02-01','2025-02-15', NULL,        200,1200.00,'PENDING'),
    ('PO-2025-007',4,4,'2025-02-01','2025-02-19', NULL,        204,2200.00,'PENDING');
