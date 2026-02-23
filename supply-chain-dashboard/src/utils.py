"""
utils.py
---------
Shared helpers: formatting, file I/O, combined reporting.
Author: Mousumi Paul | Feb 2025
"""

import os
import pandas as pd


def fmt_inr(val: float) -> str:
    return f"₹{val:,.2f}"

def fmt_units(val) -> str:
    return f"{int(val):,} units"

def fmt_pct(val: float) -> str:
    return f"{val:.1f}%"

def ensure_dir(path: str):
    os.makedirs(os.path.dirname(path) if os.path.dirname(path) else ".", exist_ok=True)

def save_csv(df: pd.DataFrame, path: str, msg: str = None):
    ensure_dir(path)
    df.to_csv(path, index=False)
    print(f"✅ Saved: {path}" + (f"  ({msg})" if msg else ""))

def combined_report(inv_df: pd.DataFrame, alerts_df: pd.DataFrame,
                    out_path: str = "outputs/reports/supply_chain_summary.csv") -> pd.DataFrame:
    """Merge inventory optimization results with alert statuses."""
    alert_map = alerts_df.set_index("Category")[["Alert_Level","Action_Message"]] \
                if not alerts_df.empty else pd.DataFrame()
    merged = inv_df.copy()
    if not alert_map.empty:
        merged = merged.join(alert_map, on="Category", how="left")
        merged["Alert_Level"]    = merged["Alert_Level"].fillna("HEALTHY")
        merged["Action_Message"] = merged["Action_Message"].fillna("No action needed")
    save_csv(merged, out_path, "combined supply chain summary")
    return merged
