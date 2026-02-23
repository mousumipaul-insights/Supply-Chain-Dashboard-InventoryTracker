-- ============================================================
-- Stored Procedures: Supply Chain Dashboard
-- Author : Mousumi Paul | Feb 2025
-- PostgreSQL syntax
-- ============================================================

-- ── Proc 1: Refresh Daily Inventory Snapshot ─────────────────
-- Called via cron job or scheduler to insert today's stock levels
CREATE OR REPLACE PROCEDURE sp_refresh_inventory_snapshot(
    p_snapshot_date DATE DEFAULT CURRENT_DATE
)
LANGUAGE plpgsql AS $$
DECLARE
    v_count  INT;
    v_wdays  INT := 250;
    v_lt     INT := 14;
    v_z      NUMERIC := 1.65;
    v_oc     NUMERIC := 2500;
BEGIN
    -- Skip if snapshot already exists for this date
    SELECT COUNT(*) INTO v_count
    FROM fact_inventory
    WHERE snapshot_date = p_snapshot_date;

    IF v_count > 0 THEN
        RAISE NOTICE 'Snapshot for % already exists. Skipping.', p_snapshot_date;
        RETURN;
    END IF;

    INSERT INTO fact_inventory
        (snapshot_date, product_id, current_stock, eoq_qty,
         safety_stock, reorder_point, daily_demand, lead_time_days)
    SELECT
        p_snapshot_date,
        p.product_id,
        -- Current stock: carry forward from yesterday + received POs - sales
        COALESCE(prev.current_stock, 0)
            + COALESCE(po_recv.received_qty, 0)
            - COALESCE(daily_sales.sold_qty, 0)                  AS current_stock,
        -- EOQ
        ROUND(SQRT(2.0 * p.annual_demand * v_oc
                   / (p.unit_cost_inr * p.holding_cost_pct)))    AS eoq_qty,
        -- Safety stock
        ROUND(v_z * p.demand_std_dev * SQRT(v_lt::NUMERIC / 30)) AS safety_stock,
        -- Reorder point
        ROUND((p.annual_demand::NUMERIC / v_wdays) * v_lt
              + v_z * p.demand_std_dev * SQRT(v_lt::NUMERIC / 30))AS reorder_point,
        -- Daily demand
        ROUND(p.annual_demand::NUMERIC / v_wdays, 4)              AS daily_demand,
        v_lt
    FROM dim_products p
    LEFT JOIN LATERAL (
        SELECT current_stock
        FROM fact_inventory fi
        WHERE fi.product_id = p.product_id
        ORDER BY snapshot_date DESC LIMIT 1
    ) prev ON TRUE
    LEFT JOIN LATERAL (
        SELECT COALESCE(SUM(quantity_ordered), 0) AS received_qty
        FROM fact_purchase_orders po
        WHERE po.product_id   = p.product_id
          AND po.actual_date  = p_snapshot_date
          AND po.po_status    = 'RECEIVED'
    ) po_recv ON TRUE
    LEFT JOIN LATERAL (
        SELECT COALESCE(SUM(units_sold), 0) AS sold_qty
        FROM fact_sales fs
        WHERE fs.product_id = p.product_id
          AND fs.sale_date  = p_snapshot_date
    ) daily_sales ON TRUE;

    RAISE NOTICE 'Inventory snapshot created for %', p_snapshot_date;
END;
$$;


-- ── Proc 2: Generate Low-Stock Alert Report ───────────────────
CREATE OR REPLACE PROCEDURE sp_generate_alert_report(
    p_min_priority INT DEFAULT 2   -- 1=CRITICAL only, 2=incl REORDER, 3=incl EXCESS
)
LANGUAGE plpgsql AS $$
BEGIN
    RAISE NOTICE '====================================================';
    RAISE NOTICE 'LOW-STOCK ALERT REPORT  |  %', CURRENT_TIMESTAMP;
    RAISE NOTICE '====================================================';

    FOR rec IN
        SELECT * FROM vw_low_stock_alerts
        WHERE alert_priority <= p_min_priority
        ORDER BY alert_priority
    LOOP
        RAISE NOTICE '[%] % | Stock: % | ROP: % | Days Supply: % | Action: %',
            rec.alert_status,
            rec.product_name,
            rec.current_stock,
            rec.reorder_point,
            rec.days_of_supply,
            rec.action_message;
    END LOOP;
END;
$$;


-- ── Proc 3: Place Purchase Order ─────────────────────────────
CREATE OR REPLACE PROCEDURE sp_place_purchase_order(
    p_product_id  INT,
    p_supplier_id INT,
    p_quantity    INT DEFAULT NULL   -- NULL = use EOQ
)
LANGUAGE plpgsql AS $$
DECLARE
    v_eoq       INT;
    v_unit_cost NUMERIC;
    v_lt        INT;
    v_po_number VARCHAR(20);
BEGIN
    -- Get current EOQ and cost
    SELECT eoq_qty INTO v_eoq
    FROM fact_inventory
    WHERE product_id = p_product_id
    ORDER BY snapshot_date DESC LIMIT 1;

    SELECT unit_cost_inr INTO v_unit_cost
    FROM dim_products WHERE product_id = p_product_id;

    SELECT agreed_lead_time_days INTO v_lt
    FROM dim_suppliers WHERE supplier_id = p_supplier_id;

    -- Generate PO number
    v_po_number := 'PO-' || TO_CHAR(CURRENT_DATE, 'YYYY') || '-' ||
                   LPAD((SELECT COUNT(*)+1 FROM fact_purchase_orders)::TEXT, 4, '0');

    INSERT INTO fact_purchase_orders
        (po_number, product_id, supplier_id, order_date,
         expected_date, quantity_ordered, unit_cost_inr, po_status)
    VALUES (
        v_po_number,
        p_product_id,
        p_supplier_id,
        CURRENT_DATE,
        CURRENT_DATE + v_lt,
        COALESCE(p_quantity, v_eoq),
        v_unit_cost,
        'PENDING'
    );

    RAISE NOTICE 'PO % created | Product ID: % | Qty: % | Expected: %',
        v_po_number, p_product_id, COALESCE(p_quantity, v_eoq), CURRENT_DATE + v_lt;
END;
$$;


-- ── Proc 4: Mark PO as Received ──────────────────────────────
CREATE OR REPLACE PROCEDURE sp_receive_purchase_order(
    p_po_number   VARCHAR(20),
    p_actual_date DATE DEFAULT CURRENT_DATE
)
LANGUAGE plpgsql AS $$
BEGIN
    UPDATE fact_purchase_orders
    SET    actual_date = p_actual_date,
           po_status   = 'RECEIVED'
    WHERE  po_number   = p_po_number
      AND  po_status   = 'IN_TRANSIT';

    IF NOT FOUND THEN
        RAISE WARNING 'PO % not found or not IN_TRANSIT', p_po_number;
    ELSE
        RAISE NOTICE 'PO % marked RECEIVED on %', p_po_number, p_actual_date;
    END IF;
END;
$$;


-- ── Proc 5: Monthly Inventory Cost Report ────────────────────
CREATE OR REPLACE PROCEDURE sp_monthly_cost_report(
    p_year  INT DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INT,
    p_month INT DEFAULT EXTRACT(MONTH FROM CURRENT_DATE)::INT
)
LANGUAGE plpgsql AS $$
BEGIN
    RAISE NOTICE '=== MONTHLY INVENTORY COST REPORT  %-%  ===', p_year, p_month;

    FOR rec IN
        SELECT
            p.product_name,
            ROUND((i.eoq_qty/2.0 + i.safety_stock)*(p.unit_cost_inr*p.holding_cost_pct),2)
                AS holding_cost,
            ROUND((p.annual_demand::NUMERIC/NULLIF(i.eoq_qty,0))*2500/12, 2)
                AS monthly_ordering_cost,
            ROUND(
                (i.eoq_qty/2.0 + i.safety_stock)*(p.unit_cost_inr*p.holding_cost_pct)
                + (p.annual_demand::NUMERIC/NULLIF(i.eoq_qty,0))*2500/12
            ,2) AS total_monthly_cost
        FROM fact_inventory i
        JOIN dim_products   p ON p.product_id = i.product_id
        WHERE EXTRACT(YEAR  FROM i.snapshot_date) = p_year
          AND EXTRACT(MONTH FROM i.snapshot_date) = p_month
    LOOP
        RAISE NOTICE '  %-30s Hold: ₹%  Order: ₹%  Total: ₹%',
            rec.product_name, rec.holding_cost,
            rec.monthly_ordering_cost, rec.total_monthly_cost;
    END LOOP;
END;
$$;
