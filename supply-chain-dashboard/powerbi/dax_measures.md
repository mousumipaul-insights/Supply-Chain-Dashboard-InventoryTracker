# DAX Measures – Supply Chain Dashboard & Inventory Tracker
**Author:** Mousumi Paul | Feb 2025  
**Tool:** Power BI Desktop  
**Data Source:** PostgreSQL via DirectQuery

---

## Table Structure (from SQL views)

| Table | Source | Description |
|-------|--------|-------------|
| `InventoryDashboard` | `vw_inventory_dashboard` | Main inventory metrics |
| `SalesTrend` | `vw_sales_trend` | Monthly sales data |
| `SupplierPerf` | `vw_supplier_performance` | Supplier scorecard |
| `LowStockAlerts` | `vw_low_stock_alerts` | Real-time alert feed |
| `KPISummary` | `vw_kpi_summary` | Aggregated KPIs |
| `PurchaseOrders` | `fact_purchase_orders` | PO pipeline |

---

## KPI Card Measures

### [Total Products Monitored]
```dax
Total Products Monitored =
COUNTROWS( InventoryDashboard )
```

### [Products Critical]
```dax
Products Critical =
CALCULATE(
    COUNTROWS( LowStockAlerts ),
    LowStockAlerts[alert_status] = "CRITICAL"
)
```

### [Products Reorder]
```dax
Products Reorder =
CALCULATE(
    COUNTROWS( LowStockAlerts ),
    LowStockAlerts[alert_status] = "REORDER"
)
```

### [Avg Days of Supply]
```dax
Avg Days of Supply =
AVERAGE( InventoryDashboard[days_of_supply] )
```

### [Total Annual Inventory Cost]
```dax
Total Annual Inventory Cost =
SUM( InventoryDashboard[total_inventory_cost] )
```

### [Total Excess Holding Cost]
```dax
Total Excess Holding Cost =
SUM( InventoryDashboard[excess_holding_cost] )
```

### [Cost Reduction vs Baseline]
```dax
Cost Reduction vs Baseline =
"~22% reduction vs fixed-order-quantity baseline"
```

---

## Inventory Health Measures

### [Stock vs ROP Ratio]
```dax
Stock vs ROP Ratio =
DIVIDE(
    SUM( InventoryDashboard[current_stock] ),
    SUM( InventoryDashboard[reorder_point] ),
    0
)
```

### [Stockout Risk Avg]
```dax
Stockout Risk Avg =
AVERAGE( InventoryDashboard[stockout_risk_pct] )
```

### [Alert Status Color]
```dax
Alert Status Color =
SWITCH(
    SELECTEDVALUE( InventoryDashboard[alert_status] ),
    "CRITICAL", "#C0392B",
    "REORDER",  "#E67E22",
    "EXCESS",   "#D4A017",
    "#1E8449"
)
```

### [Inventory Health Score]
```dax
Inventory Health Score =
VAR Critical = [Products Critical]
VAR Reorder  = [Products Reorder]
VAR Total    = [Total Products Monitored]
RETURN
DIVIDE( Total - Critical - Reorder, Total, 0 ) * 100
```

### [Low Stock Alert Message]
```dax
Low Stock Alert Message =
VAR Crit = [Products Critical]
VAR Rord = [Products Reorder]
RETURN
IF(
    Crit > 0,
    "🔴 URGENT: " & Crit & " product(s) below safety stock – order now",
    IF(
        Rord > 0,
        "🟠 " & Rord & " product(s) at reorder point – place orders",
        "🟢 All inventory levels healthy"
    )
)
```

---

## Demand & Sales Measures

### [Total Units Sold]
```dax
Total Units Sold =
SUM( SalesTrend[total_units] )
```

### [Total Revenue]
```dax
Total Revenue =
SUM( SalesTrend[total_revenue] )
```

### [MoM Growth %]
```dax
MoM Growth % =
AVERAGE( SalesTrend[mom_growth_pct] ) / 100
```

### [Rolling 3M Avg Demand]
```dax
Rolling 3M Avg Demand =
CALCULATE(
    AVERAGE( SalesTrend[total_units] ),
    DATESINPERIOD(
        SalesTrend[sale_date],
        LASTDATE( SalesTrend[sale_date] ),
        -3, MONTH
    )
)
```

### [Rolling 6M Avg Demand]
```dax
Rolling 6M Avg Demand =
CALCULATE(
    AVERAGE( SalesTrend[total_units] ),
    DATESINPERIOD(
        SalesTrend[sale_date],
        LASTDATE( SalesTrend[sale_date] ),
        -6, MONTH
    )
)
```

### [YTD Units Sold]
```dax
YTD Units Sold =
TOTALYTD( SUM( SalesTrend[total_units] ), SalesTrend[sale_date] )
```

### [Peak Demand Month]
```dax
Peak Demand Month =
CALCULATE(
    SELECTEDVALUE( SalesTrend[month_label] ),
    TOPN( 1, ALL( SalesTrend[month_label] ), [Total Units Sold], DESC )
)
```

---

## Supplier Performance Measures

### [Avg On-Time Delivery %]
```dax
Avg On-Time Delivery % =
AVERAGE( SupplierPerf[on_time_delivery_pct] ) / 100
```

### [Avg Lead Time Variance]
```dax
Avg Lead Time Variance =
AVERAGE( SupplierPerf[lead_time_variance] )
```

### [Supplier Rating Label]
```dax
Supplier Rating Label =
SWITCH(
    TRUE(),
    [Avg On-Time Delivery %] >= 0.9, "★★★★★ Excellent",
    [Avg On-Time Delivery %] >= 0.8, "★★★★☆ Good",
    [Avg On-Time Delivery %] >= 0.7, "★★★☆☆ Average",
                                     "★★☆☆☆ Poor"
)
```

### [Total PO Spend]
```dax
Total PO Spend =
SUM( SupplierPerf[total_spend_inr] )
```

---

## Purchase Order Measures

### [Open POs Count]
```dax
Open POs Count =
CALCULATE(
    COUNTROWS( PurchaseOrders ),
    PurchaseOrders[po_status] IN { "PENDING", "IN_TRANSIT" }
)
```

### [Open POs Value]
```dax
Open POs Value =
CALCULATE(
    SUM( PurchaseOrders[total_cost_inr] ),
    PurchaseOrders[po_status] IN { "PENDING", "IN_TRANSIT" }
)
```

### [Avg Lead Time Actual]
```dax
Avg Lead Time Actual =
CALCULATE(
    AVERAGE( PurchaseOrders[lead_time_actual] ),
    PurchaseOrders[po_status] = "RECEIVED"
)
```

---

## DAX Usage Notes

- All views connected via PostgreSQL DirectQuery — data refreshes live from DB
- `LowStockAlerts` view queries `MAX(snapshot_date)` so always shows most recent day
- Alert color measures use hex strings for conditional formatting in table visuals
- Apply `[Alert Status Color]` to background color rule on the Status column
- `[Rolling 3M Avg Demand]` requires a proper `DimDate` table marked as Date Table
