# Methodology & Technical Documentation
**Author:** Mousumi Paul | Feb 2025

---

## 1. Inventory Optimization Formulas

### Economic Order Quantity (EOQ)
```
EOQ = √(2 × D × S / H)
```
| Variable | Definition | Value |
|----------|-----------|-------|
| D | Annual demand (units) | Per product |
| S | Ordering cost per order | ₹2,500 |
| H | Holding cost per unit/year = Unit Cost × Holding % | Per product |

EOQ minimizes total inventory cost by balancing the trade-off between ordering frequency and stock holding.

### Safety Stock
```
Safety Stock = Z × σ_d × √(LT / 30)
```
| Variable | Definition | Value |
|----------|-----------|-------|
| Z | Service level z-score | 1.65 (95% service level) |
| σ_d | Monthly demand standard deviation | Per product |
| LT | Supplier lead time | 14 days |

### Reorder Point (ROP)
```
ROP = (Annual Demand / Working Days) × Lead Time + Safety Stock
```

### Annual Cost Model
```
Annual Holding Cost  = (EOQ/2 + Safety Stock) × H
Annual Ordering Cost = (D / EOQ) × S
Total Inventory Cost = Holding Cost + Ordering Cost
```

### Days of Supply
```
Days of Supply = Current Stock / Daily Demand
```

### Stockout Risk %
```
Stockout Risk % = MAX(0, 1 − Current Stock / ROP) × 100
```

---

## 2. Model Assumptions

| Parameter | Value | Rationale |
|-----------|-------|-----------|
| Working days/year | 250 | Standard business calendar |
| Ordering cost (S) | ₹2,500/order | Covers admin + logistics |
| Lead time (LT) | 14 days | Supplier SLA average |
| Service level | 95% (Z = 1.65) | Business risk tolerance |
| Holding cost % | 18–28% | Varies by product type |

---

## 3. Alert Classification Logic

| Status | Condition | Action |
|--------|-----------|--------|
| 🔴 CRITICAL | Current Stock < Safety Stock | Emergency order immediately |
| 🟠 REORDER NOW | Safety Stock ≤ Stock < ROP | Place replenishment order |
| 🟡 EXCESS STOCK | Stock > ROP + EOQ | Review demand; run promotion |
| 🟢 HEALTHY | ROP ≤ Stock ≤ ROP + EOQ | No action needed |

---

## 4. Database Architecture

### Star Schema
```
         dim_products
              │
fact_sales ──┤
              │
fact_inventory┤── dim_suppliers
              │
fact_purchase_orders
```

### Key Tables
- **dim_products** — Master product data (cost, holding %, demand)
- **dim_suppliers** — Supplier info, lead times, OTD %
- **fact_inventory** — Daily stock snapshots with computed EOQ/SS/ROP
- **fact_sales** — Monthly unit sales and revenue
- **fact_purchase_orders** — PO pipeline with status tracking

### Key Views (sql/views/)
| View | Purpose |
|------|---------|
| `vw_inventory_dashboard` | Main dashboard table (Power BI, Tableau) |
| `vw_sales_trend` | Monthly demand + MoM growth |
| `vw_supplier_performance` | OTD %, lead time variance, spend |
| `vw_low_stock_alerts` | Real-time alert feed with priority |
| `vw_kpi_summary` | Aggregated KPI row for cards |

---

## 5. Excel Workbook – Sheet Guide

| Sheet | Description |
|-------|-------------|
| `Inventory_Tracker` | Live stock levels — update Column L (Current Stock) daily |
| `EOQ_Solver_Model` | Excel Solver optimization + 3-scenario Scenario Manager |
| `Demand_Trends` | 12-month sales, MoM growth, peak detection, trend chart |
| `Supplier_LeadTime` | Agreed vs actual lead times, OTD %, supplier ratings |
| `SQL_Export_Preview` | Sample output from `vw_inventory_dashboard` query |
| `KPI_Dashboard` | Live KPI cards pulling from Inventory_Tracker |
| `Guide` | Color legend, formula reference, SQL connection notes |

### Excel Solver Setup (EOQ_Solver_Model sheet)
1. **Set Objective:** Minimize cell in Total Inv Cost row
2. **Variable Cells:** Order Qty column (Col H, rows 10–14)
3. **Constraints:** Order Qty ≥ Safety Stock; Order Qty ≥ 1
4. **Method:** GRG Nonlinear

### Scenario Manager (3 scenarios)
| Scenario | Ordering Cost | Lead Time | Z-Score |
|----------|--------------|-----------|---------|
| Base Case | ₹2,500 | 14 days | 1.65 |
| High Demand (+20%) | ₹2,500 | 10 days | 1.65 |
| Cost Optimized | ₹2,000 | 14 days | 1.28 |

---

## 6. Power BI Connection Setup

1. Open Power BI Desktop → **Get Data → PostgreSQL**
2. Server: `localhost:5432`, Database: `supply_chain_db`
3. Use **DirectQuery** for live data
4. Import each query from `sql/queries/powerbi_queries.sql`
5. Add all DAX measures from `powerbi/dax_measures.md`
6. Apply `[Alert Status Color]` as background color on Status column

---

## 7. Tableau Connection Setup

See `tableau/tableau_connection_guide.md` for full setup instructions.

- Connect via **Live** (not Extract) for real-time updates
- Use 4 Custom SQL queries from `sql/queries/tableau_queries.sql`
- Apply calculated fields for alert coloring and health labels

---

## 8. Results Summary

| Metric | Result |
|--------|--------|
| Excess holding cost reduction | **~22%** vs fixed-order baseline |
| Stockout incidents eliminated | **0** (after ROP alerts deployed) |
| Products monitored | **5 categories** |
| SQL views built | **5 views** |
| Stored procedures | **5 procedures** |
| Excel live formulas | **129** |
| Power BI DAX measures | **20+** |
