# Tableau Connection Guide & Calculated Fields
**Author:** Mousumi Paul | Feb 2025

---

## 1. Database Connection Setup

### PostgreSQL via JDBC
| Field | Value |
|-------|-------|
| Server | `localhost` (or your host) |
| Port | `5432` |
| Database | `supply_chain_db` |
| Authentication | Username / Password |
| Schema | `public` |

### MySQL via JDBC
| Field | Value |
|-------|-------|
| Server | `localhost` |
| Port | `3306` |
| Database | `supply_chain_db` |
| Authentication | Username / Password |

---

## 2. Data Sources to Create

Create **4 separate data sources** in Tableau, each pointing to a Custom SQL query from `sql/queries/tableau_queries.sql`:

| Data Source Name | Custom SQL Query | Primary Use |
|-----------------|-----------------|-------------|
| `SC_Inventory` | Custom SQL 1 | Main dashboard, KPI cards |
| `SC_Sales` | Custom SQL 2 | Demand trend sheets |
| `SC_Suppliers` | Custom SQL 3 | Supplier scorecard |
| `SC_EOQ_Curve` | Custom SQL 4 | EOQ cost curve chart |

---

## 3. Dashboard Pages

### Page 1 – Executive Overview
- **KPI Tiles:** Current Stock vs ROP (5 products), Days of Supply, Alerts count
- **Bar Chart:** Current Stock vs Reorder Point vs Safety Stock (grouped bar)
- **Alert Banner:** Filter `alert_status != 'HEALTHY'`, color by `status_code`

### Page 2 – Demand Trends
- **Line Chart:** `month_year` × `units_sold`, broken by `product_name`
- **Bar Chart:** Monthly revenue by category (stacked)
- **Filter:** Category selector, Year selector

### Page 3 – Inventory Health
- **Table:** All 5 products with conditional row coloring (see Calculated Fields below)
- **Gauge-style bar:** `current_stock / reorder_point` ratio per product
- **Scatter:** `days_of_supply` × `stockout_risk_pct`, sized by `total_inventory_cost`

### Page 4 – Supplier Performance
- **Horizontal bar:** `on_time_delivery_pct` by `supplier_name`
- **Bullet chart:** Agreed vs Actual lead time
- **Scorecard table:** Rating, total orders, total spend

### Page 5 – EOQ Analysis
- **Line chart:** Order Quantity × Total Cost (3 lines: Holding, Ordering, Total)
- Use `SC_EOQ_Curve` data source
- Add reference line at `optimal_eoq`

---

## 4. Calculated Fields

### Alert Color (for conditional formatting)
```
IF [alert_status] = "CRITICAL" THEN "#C0392B"
ELSEIF [alert_status] = "REORDER" THEN "#E67E22"
ELSEIF [alert_status] = "EXCESS" THEN "#D4A017"
ELSE "#1E8449"
END
```

### Stock Health Label
```
IF [alert_status] = "CRITICAL" THEN "🔴 CRITICAL"
ELSEIF [alert_status] = "REORDER" THEN "🟠 REORDER NOW"
ELSEIF [alert_status] = "EXCESS" THEN "🟡 EXCESS"
ELSE "🟢 HEALTHY"
END
```

### Stock vs ROP %
```
[current_stock] / [reorder_point]
```
Format as percentage. Use in reference band (0%–100% = below ROP zone).

### Days of Supply Category
```
IF [days_of_supply] < 7 THEN "< 1 Week"
ELSEIF [days_of_supply] < 14 THEN "1–2 Weeks"
ELSEIF [days_of_supply] < 30 THEN "2–4 Weeks"
ELSE "> 1 Month"
END
```

### Lead Time Status
```
IF [lead_time_variance] <= 0 THEN "On Time / Early"
ELSEIF [lead_time_variance] <= 2 THEN "Slightly Delayed"
ELSE "Significantly Delayed"
END
```

### Rolling 3M Avg (Table Calculation)
Use **Table Calculation → Running Average** on `units_sold`:
- Compute using: `month_year`
- Restarting every: `product_name`
- Set computation to: `Average` over last 3 values

---

## 5. Low-Stock Alert Setup

To create automated alert highlighting:

1. Go to **Sheet → Format → Shading**
2. Add a filter: `alert_status != 'HEALTHY'`
3. Apply the `Alert Color` calculated field as **Background Color**
4. In Dashboard: add a **Text object** referencing the alert count from KPI Summary query

---

## 6. Publishing Notes

- Connect via **Live connection** (not Extract) for real-time SQL updates
- Schedule **Extract Refresh** if using Tableau Server: every 24h at 06:00
- Publish to Tableau Public or Tableau Server after connecting
- All views in `sql/views/vw_inventory_dashboard.sql` are optimised for Tableau's query folding
