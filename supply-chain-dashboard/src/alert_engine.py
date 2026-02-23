"""
alert_engine.py
----------------
Automated low-stock alert generation and reporting.
Mirrors the SQL vw_low_stock_alerts logic in Python.
Author: Mousumi Paul | Feb 2025
"""

import pandas as pd
from datetime import datetime


ALERT_THRESHOLDS = {
    "CRITICAL":   1,
    "REORDER":    2,
    "EXCESS":     3,
    "HEALTHY":    4,
}


def classify_alert(row: pd.Series) -> str:
    if row["Current_Stock"] < row["Safety_Stock"]:
        return "CRITICAL"
    elif row["Current_Stock"] < row["Reorder_Point"]:
        return "REORDER"
    elif row["Excess_Stock"] > 0:
        return "EXCESS"
    return "HEALTHY"


def generate_alerts(inv_df: pd.DataFrame) -> pd.DataFrame:
    """
    Generate alert report from inventory DataFrame.
    Input: output of inventory_engine.run_optimization()
    """
    df = inv_df.copy()
    df["Alert_Level"]  = df.apply(classify_alert, axis=1)
    df["Priority"]     = df["Alert_Level"].map(ALERT_THRESHOLDS)
    df["Generated_At"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    df["Action_Message"] = df.apply(_action_message, axis=1)

    alert_df = df[df["Alert_Level"] != "HEALTHY"].sort_values("Priority")
    return alert_df[["Generated_At","Category","Current_Stock","Safety_Stock",
                      "Reorder_Point","EOQ_Units","Days_of_Supply","Stockout_Risk_Pct",
                      "Alert_Level","Priority","Action_Message"]]


def _action_message(row: pd.Series) -> str:
    level = row["Alert_Level"]
    eoq   = row["EOQ_Units"]
    if level == "CRITICAL":
        return f"🔴 Place EMERGENCY order of {eoq} units immediately"
    elif level == "REORDER":
        return f"🟠 Place standard replenishment order of {eoq} units within 2 days"
    elif level == "EXCESS":
        return f"🟡 Review {row['Excess_Stock']} excess units — consider promotion or markdown"
    return "🟢 No action required"


def print_alert_console(alert_df: pd.DataFrame):
    """Pretty-print alert report to console."""
    print("\n" + "="*70)
    print(f"🚨  INVENTORY ALERT REPORT  |  {datetime.now().strftime('%Y-%m-%d %H:%M')}")
    print("="*70)
    if alert_df.empty:
        print("  ✅ All inventory levels healthy — no alerts.")
    else:
        for _, row in alert_df.iterrows():
            print(f"\n  [{row['Alert_Level']:8}]  {row['Category']}")
            print(f"    Current Stock: {row['Current_Stock']:>5} units  |  "
                  f"ROP: {row['Reorder_Point']:>5}  |  "
                  f"Safety Stock: {row['Safety_Stock']:>5}")
            print(f"    Days of Supply: {row['Days_of_Supply']:>5}  |  "
                  f"Stockout Risk: {row['Stockout_Risk_Pct']:.1f}%")
            print(f"    👉 {row['Action_Message']}")
    print("="*70)


def alert_summary_stats(inv_df: pd.DataFrame) -> dict:
    """Return dict of KPI counts."""
    total    = len(inv_df)
    critical = (inv_df["Current_Stock"] < inv_df["Safety_Stock"]).sum()
    reorder  = ((inv_df["Current_Stock"] >= inv_df["Safety_Stock"]) &
                (inv_df["Current_Stock"] <  inv_df["Reorder_Point"])).sum()
    excess   = (inv_df["Excess_Stock"] > 0).sum()
    healthy  = total - critical - reorder - excess

    return {
        "total_products":    int(total),
        "critical":          int(critical),
        "reorder":           int(reorder),
        "excess":            int(excess),
        "healthy":           int(healthy),
        "avg_days_supply":   round(inv_df["Days_of_Supply"].mean(), 1),
        "total_excess_cost": round(inv_df["Excess_Holding_Cost_INR"].sum(), 2),
    }


if __name__ == "__main__":
    import sys
    sys.path.append(".")
    import pandas as pd
    from src.inventory_engine import run_optimization

    params = pd.read_csv("data/raw/inventory_params.csv")
    inv_df = run_optimization(params)
    alerts = generate_alerts(inv_df)
    print_alert_console(alerts)

    stats = alert_summary_stats(inv_df)
    print("\n📊 ALERT SUMMARY STATS")
    for k, v in stats.items():
        print(f"  {k:<25}: {v}")
