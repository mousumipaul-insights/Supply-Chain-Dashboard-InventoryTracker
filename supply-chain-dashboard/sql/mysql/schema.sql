-- ============================================================
-- MySQL Schema: Supply Chain Dashboard & Inventory Tracker
-- Author : Mousumi Paul | Feb 2025
-- Compatible: MySQL 8.0+
-- ============================================================

CREATE DATABASE IF NOT EXISTS supply_chain_db
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE supply_chain_db;

-- ── Dimension: Products ──────────────────────────────────────
CREATE TABLE IF NOT EXISTS dim_products (
    product_id       INT          AUTO_INCREMENT PRIMARY KEY,
    product_name     VARCHAR(100) NOT NULL,
    category_code    CHAR(3)      NOT NULL,
    category_name    VARCHAR(60)  NOT NULL,
    unit_cost_inr    DECIMAL(10,2) NOT NULL,
    holding_cost_pct DECIMAL(5,4) NOT NULL,
    annual_demand    INT          NOT NULL,
    demand_std_dev   DECIMAL(8,2) NOT NULL,
    created_at       DATETIME     DEFAULT CURRENT_TIMESTAMP,
    updated_at       DATETIME     DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ── Dimension: Suppliers ─────────────────────────────────────
CREATE TABLE IF NOT EXISTS dim_suppliers (
    supplier_id            INT          AUTO_INCREMENT PRIMARY KEY,
    supplier_code          VARCHAR(10)  NOT NULL UNIQUE,
    supplier_name          VARCHAR(100) NOT NULL,
    product_id             INT,
    agreed_lead_time_days  INT          NOT NULL,
    actual_lead_time_days  INT,
    on_time_delivery_pct   DECIMAL(5,2),
    contact_email          VARCHAR(120),
    country                VARCHAR(60)  DEFAULT 'India',
    rating                 TINYINT      CHECK (rating BETWEEN 1 AND 5),
    is_active              TINYINT(1)   DEFAULT 1,
    created_at             DATETIME     DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES dim_products(product_id)
) ENGINE=InnoDB;

-- ── Fact: Inventory Snapshots ────────────────────────────────
CREATE TABLE IF NOT EXISTS fact_inventory (
    inventory_id    INT      AUTO_INCREMENT PRIMARY KEY,
    snapshot_date   DATE     NOT NULL,
    product_id      INT      NOT NULL,
    current_stock   INT      NOT NULL,
    eoq_qty         INT      NOT NULL,
    safety_stock    INT      NOT NULL,
    reorder_point   INT      NOT NULL,
    daily_demand    DECIMAL(10,4) NOT NULL,
    lead_time_days  INT      NOT NULL DEFAULT 14,
    -- MySQL doesn't support GENERATED from other generated cols in same table easily
    -- excess_stock and alert computed via VIEW
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_snap_prod (snapshot_date, product_id),
    FOREIGN KEY (product_id) REFERENCES dim_products(product_id)
) ENGINE=InnoDB;

-- ── Fact: Daily Sales ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS fact_sales (
    sale_id        INT          AUTO_INCREMENT PRIMARY KEY,
    sale_date      DATE         NOT NULL,
    product_id     INT          NOT NULL,
    units_sold     INT          NOT NULL,
    unit_price_inr DECIMAL(10,2) NOT NULL,
    revenue_inr    DECIMAL(14,2) AS (units_sold * unit_price_inr) STORED,
    channel        VARCHAR(30)  DEFAULT 'Online',
    created_at     DATETIME     DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES dim_products(product_id)
) ENGINE=InnoDB;

-- ── Fact: Purchase Orders ────────────────────────────────────
CREATE TABLE IF NOT EXISTS fact_purchase_orders (
    po_id             INT          AUTO_INCREMENT PRIMARY KEY,
    po_number         VARCHAR(20)  NOT NULL UNIQUE,
    product_id        INT          NOT NULL,
    supplier_id       INT          NOT NULL,
    order_date        DATE         NOT NULL,
    expected_date     DATE         NOT NULL,
    actual_date       DATE,
    quantity_ordered  INT          NOT NULL,
    unit_cost_inr     DECIMAL(10,2) NOT NULL,
    total_cost_inr    DECIMAL(14,2) AS (quantity_ordered * unit_cost_inr) STORED,
    po_status         ENUM('PENDING','IN_TRANSIT','RECEIVED','CANCELLED') DEFAULT 'PENDING',
    created_at        DATETIME     DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id)  REFERENCES dim_products(product_id),
    FOREIGN KEY (supplier_id) REFERENCES dim_suppliers(supplier_id)
) ENGINE=InnoDB;

-- ── Indexes ──────────────────────────────────────────────────
CREATE INDEX idx_inv_date    ON fact_inventory(snapshot_date);
CREATE INDEX idx_inv_product ON fact_inventory(product_id);
CREATE INDEX idx_sales_date  ON fact_sales(sale_date);
CREATE INDEX idx_sales_prod  ON fact_sales(product_id);
CREATE INDEX idx_po_status   ON fact_purchase_orders(po_status);
