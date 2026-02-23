-- ============================================================
-- PostgreSQL Schema: Supply Chain Dashboard & Inventory Tracker
-- Author : Mousumi Paul | Feb 2025
-- DB     : supply_chain_db
-- ============================================================

-- ── Drop & recreate (dev convenience) ────────────────────────
DROP TABLE IF EXISTS fact_inventory       CASCADE;
DROP TABLE IF EXISTS fact_sales           CASCADE;
DROP TABLE IF EXISTS fact_purchase_orders CASCADE;
DROP TABLE IF EXISTS dim_products         CASCADE;
DROP TABLE IF EXISTS dim_suppliers        CASCADE;
DROP TABLE IF EXISTS dim_date             CASCADE;

-- ── Dimension: Date ──────────────────────────────────────────
CREATE TABLE dim_date (
    date_id       SERIAL       PRIMARY KEY,
    full_date     DATE         NOT NULL UNIQUE,
    year          SMALLINT     NOT NULL,
    quarter       SMALLINT     NOT NULL CHECK (quarter BETWEEN 1 AND 4),
    month_num     SMALLINT     NOT NULL CHECK (month_num BETWEEN 1 AND 12),
    month_name    VARCHAR(10)  NOT NULL,
    week_num      SMALLINT     NOT NULL,
    day_of_week   SMALLINT     NOT NULL,
    is_weekend    BOOLEAN      NOT NULL DEFAULT FALSE,
    is_holiday    BOOLEAN      NOT NULL DEFAULT FALSE
);

-- ── Dimension: Products ──────────────────────────────────────
CREATE TABLE dim_products (
    product_id      SERIAL       PRIMARY KEY,
    product_name    VARCHAR(100) NOT NULL,
    category_code   CHAR(3)      NOT NULL,
    category_name   VARCHAR(60)  NOT NULL,
    unit_cost_inr   NUMERIC(10,2) NOT NULL,
    holding_cost_pct NUMERIC(5,4) NOT NULL CHECK (holding_cost_pct BETWEEN 0 AND 1),
    annual_demand   INTEGER      NOT NULL,
    demand_std_dev  NUMERIC(8,2) NOT NULL,
    created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    updated_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ── Dimension: Suppliers ─────────────────────────────────────
CREATE TABLE dim_suppliers (
    supplier_id     SERIAL       PRIMARY KEY,
    supplier_code   VARCHAR(10)  NOT NULL UNIQUE,
    supplier_name   VARCHAR(100) NOT NULL,
    product_id      INTEGER      REFERENCES dim_products(product_id),
    agreed_lead_time_days INTEGER NOT NULL,
    actual_lead_time_days INTEGER,
    on_time_delivery_pct  NUMERIC(5,2),
    contact_email   VARCHAR(120),
    country         VARCHAR(60)  DEFAULT 'India',
    rating          SMALLINT     CHECK (rating BETWEEN 1 AND 5),
    is_active       BOOLEAN      DEFAULT TRUE,
    created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ── Fact: Inventory Snapshots ────────────────────────────────
CREATE TABLE fact_inventory (
    inventory_id    SERIAL       PRIMARY KEY,
    snapshot_date   DATE         NOT NULL,
    product_id      INTEGER      NOT NULL REFERENCES dim_products(product_id),
    current_stock   INTEGER      NOT NULL CHECK (current_stock >= 0),
    eoq_qty         INTEGER      NOT NULL,
    safety_stock    INTEGER      NOT NULL,
    reorder_point   INTEGER      NOT NULL,
    daily_demand    NUMERIC(10,4) NOT NULL,
    lead_time_days  INTEGER      NOT NULL DEFAULT 14,
    excess_stock    INTEGER      GENERATED ALWAYS AS
                        (GREATEST(0, current_stock - (reorder_point + eoq_qty))) STORED,
    stockout_risk_pct NUMERIC(5,2) GENERATED ALWAYS AS
                        (ROUND(GREATEST(0, 1.0 - CAST(current_stock AS NUMERIC) /
                            NULLIF(reorder_point, 0)) * 100, 2)) STORED,
    alert_status    VARCHAR(30)  GENERATED ALWAYS AS (
                        CASE
                            WHEN current_stock < safety_stock  THEN 'CRITICAL'
                            WHEN current_stock < reorder_point THEN 'REORDER'
                            WHEN current_stock > (reorder_point + eoq_qty) THEN 'EXCESS'
                            ELSE 'HEALTHY'
                        END) STORED,
    created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (snapshot_date, product_id)
);

-- ── Fact: Daily Sales ────────────────────────────────────────
CREATE TABLE fact_sales (
    sale_id         SERIAL       PRIMARY KEY,
    sale_date       DATE         NOT NULL,
    product_id      INTEGER      NOT NULL REFERENCES dim_products(product_id),
    units_sold      INTEGER      NOT NULL CHECK (units_sold >= 0),
    unit_price_inr  NUMERIC(10,2) NOT NULL,
    revenue_inr     NUMERIC(14,2) GENERATED ALWAYS AS
                        (units_sold * unit_price_inr) STORED,
    channel         VARCHAR(30)  DEFAULT 'Online',
    created_at      TIMESTAMP    DEFAULT CURRENT_TIMESTAMP
);

-- ── Fact: Purchase Orders ────────────────────────────────────
CREATE TABLE fact_purchase_orders (
    po_id            SERIAL      PRIMARY KEY,
    po_number        VARCHAR(20) NOT NULL UNIQUE,
    product_id       INTEGER     NOT NULL REFERENCES dim_products(product_id),
    supplier_id      INTEGER     NOT NULL REFERENCES dim_suppliers(supplier_id),
    order_date       DATE        NOT NULL,
    expected_date    DATE        NOT NULL,
    actual_date      DATE,
    quantity_ordered INTEGER     NOT NULL CHECK (quantity_ordered > 0),
    unit_cost_inr    NUMERIC(10,2) NOT NULL,
    total_cost_inr   NUMERIC(14,2) GENERATED ALWAYS AS
                        (quantity_ordered * unit_cost_inr) STORED,
    po_status        VARCHAR(20) DEFAULT 'PENDING'
                        CHECK (po_status IN ('PENDING','IN_TRANSIT','RECEIVED','CANCELLED')),
    lead_time_actual INTEGER     GENERATED ALWAYS AS
                        (CASE WHEN actual_date IS NOT NULL
                              THEN actual_date - order_date ELSE NULL END) STORED,
    created_at       TIMESTAMP   DEFAULT CURRENT_TIMESTAMP
);

-- ── Indexes ──────────────────────────────────────────────────
CREATE INDEX idx_fact_inventory_date     ON fact_inventory(snapshot_date);
CREATE INDEX idx_fact_inventory_product  ON fact_inventory(product_id);
CREATE INDEX idx_fact_inventory_alert    ON fact_inventory(alert_status);
CREATE INDEX idx_fact_sales_date         ON fact_sales(sale_date);
CREATE INDEX idx_fact_sales_product      ON fact_sales(product_id);
CREATE INDEX idx_fact_po_status          ON fact_purchase_orders(po_status);
CREATE INDEX idx_fact_po_product         ON fact_purchase_orders(product_id);

-- ── Updated-at trigger ───────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON dim_products
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();
