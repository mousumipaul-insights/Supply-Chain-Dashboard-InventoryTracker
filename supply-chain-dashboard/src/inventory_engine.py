"""
inventory_engine.py
--------------------
Core inventory optimization engine: EOQ, Safety Stock, Reorder Point,
cost modelling, and SQL integration helpers.
Author: Mousumi Paul | Feb 2025
"""

import math
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.ticker as mticker
import os


PRODUCTS = ["Electronics", "Apparel", "Home & Kitchen", "Sports & Outdoors", "Beauty & Health"]

# Default model parameters
DEFAULT_PARAMS = {
    "working_days":   250,
    "lead_time_days": 14,
    "z_score":        1.65,   # 95% service level
    "ordering_cost":  2500,   # ₹ per order
}


# ── Core Formulas ─────────────────────────────────────────────

def eoq(annual_demand: float, ordering_cost: float, holding_cost_pu: float) -> int:
    """EOQ = sqrt(2DS/H)"""
    if holding_cost_pu <= 0:
        raise ValueError("Holding cost per unit must be > 0")
    return int(round(math.sqrt(2 * annual_demand * ordering_cost / holding_cost_pu)))


def safety_stock(std_dev: float, lead_time_days: float,
                 z_score: float = 1.65, days_per_month: float = 30) -> int:
    """Safety Stock = Z × σ × sqrt(LT_months)"""
    lt_months = lead_time_days / days_per_month
    return int(round(z_score * std_dev * math.sqrt(lt_months)))


def reorder_point(annual_demand: float, working_days: int,
                  lead_time_days: float, ss: int) -> int:
    """ROP = (D/working_days) × LT + SS"""
    daily = annual_demand / working_days
    return int(round(daily * lead_time_days + ss))


def daily_demand(annual_demand: float, working_days: int = 250) -> float:
    return round(annual_demand / working_days, 4)


def annual_holding_cost(eoq_qty: int, ss: int, holding_cost_pu: float) -> float:
    """Annual Holding Cost = (EOQ/2 + SS) × H"""
    return round((eoq_qty / 2 + ss) * holding_cost_pu, 2)


def annual_ordering_cost(annual_demand: float, eoq_qty: int,
                         ordering_cost: float) -> float:
    """Annual Ordering Cost = (D/EOQ) × S"""
    return round((annual_demand / eoq_qty) * ordering_cost, 2) if eoq_qty > 0 else 0.0


def total_inventory_cost(ahc: float, aoc: float) -> float:
    return round(ahc + aoc, 2)


def days_of_supply(current_stock: int, ann_demand: float,
                   working_days: int = 250) -> float:
    dd = ann_demand / working_days
    return round(current_stock / dd, 1) if dd > 0 else 0.0


def stockout_risk(current_stock: int, rop: int) -> float:
    """Proxy: pct gap below ROP"""
    return max(0.0, round((1 - current_stock / rop) * 100, 1)) if rop > 0 else 0.0


def alert_status(current_stock: int, ss: int, rop: int, eoq_qty: int) -> str:
    if current_stock < ss:
        return "🔴 CRITICAL – Below Safety Stock"
    elif current_stock < rop:
        return "🟠 REORDER NOW"
    elif current_stock > (rop + eoq_qty):
        return "🟡 EXCESS STOCK"
    return "🟢 HEALTHY"


# ── Full Optimization Pipeline ────────────────────────────────

def run_optimization(params_df: pd.DataFrame,
                     ordering_cost: float = 2500,
                     z_score: float = 1.65,
                     lead_time_days: int = 14,
                     working_days: int = 250) -> pd.DataFrame:
    """
    Run EOQ/SS/ROP optimization for all products.

    Parameters:
        params_df: DataFrame with columns:
            Category, Unit_Cost_INR, Holding_Cost_Pct,
            Annual_Demand, Demand_StdDev, Current_Stock
    Returns:
        Enriched DataFrame with all computed metrics.
    """
    rows = []
    for _, r in params_df.iterrows():
        hc_pu  = r["Unit_Cost_INR"] * r["Holding_Cost_Pct"]
        eq     = eoq(r["Annual_Demand"], ordering_cost, hc_pu)
        ss     = safety_stock(r["Demand_StdDev"], lead_time_days, z_score)
        rop    = reorder_point(r["Annual_Demand"], working_days, lead_time_days, ss)
        dd     = daily_demand(r["Annual_Demand"], working_days)
        ahc    = annual_holding_cost(eq, ss, hc_pu)
        aoc    = annual_ordering_cost(r["Annual_Demand"], eq, ordering_cost)
        tic    = total_inventory_cost(ahc, aoc)
        cs     = int(r["Current_Stock"])
        excess = max(0, cs - (rop + eq))

        rows.append({
            "Category":                r["Category"],
            "Unit_Cost_INR":           r["Unit_Cost_INR"],
            "Holding_Cost_Per_Unit":   round(hc_pu, 2),
            "Annual_Demand":           r["Annual_Demand"],
            "Demand_StdDev":           r["Demand_StdDev"],
            "Daily_Demand":            dd,
            "EOQ_Units":               eq,
            "Safety_Stock":            ss,
            "Reorder_Point":           rop,
            "Current_Stock":           cs,
            "Days_of_Supply":          days_of_supply(cs, r["Annual_Demand"], working_days),
            "Stockout_Risk_Pct":       stockout_risk(cs, rop),
            "Excess_Stock":            excess,
            "Excess_Holding_Cost_INR": round(excess * hc_pu, 2),
            "Annual_Holding_Cost_INR": ahc,
            "Annual_Ordering_Cost_INR": aoc,
            "Total_Inventory_Cost_INR": tic,
            "Alert_Status":            alert_status(cs, ss, rop, eq),
            "Recommended_Action":      _action(cs, ss, rop, excess),
        })
    return pd.DataFrame(rows)


def _action(cs, ss, rop, excess):
    if cs < ss:       return "Emergency order now"
    if cs < rop:      return "Place replenishment order"
    if excess > 0:    return "Review demand; consider promotion"
    return "No action needed"


def cost_savings_analysis(params_df: pd.DataFrame,
                          baseline_order_qty: int = 1000,
                          ordering_cost: float = 2500,
                          lead_time_days: int = 14,
                          z_score: float = 1.65,
                          working_days: int = 250) -> pd.DataFrame:
    """Compare EOQ-optimized cost vs fixed baseline order quantity."""
    rows = []
    for _, r in params_df.iterrows():
        hc_pu  = r["Unit_Cost_INR"] * r["Holding_Cost_Pct"]
        ss     = safety_stock(r["Demand_StdDev"], lead_time_days, z_score)
        eq     = eoq(r["Annual_Demand"], ordering_cost, hc_pu)

        cost_before = total_inventory_cost(
            annual_holding_cost(baseline_order_qty, ss, hc_pu),
            annual_ordering_cost(r["Annual_Demand"], baseline_order_qty, ordering_cost)
        )
        cost_after = total_inventory_cost(
            annual_holding_cost(eq, ss, hc_pu),
            annual_ordering_cost(r["Annual_Demand"], eq, ordering_cost)
        )
        saving_pct = (cost_before - cost_after) / cost_before * 100 if cost_before > 0 else 0

        rows.append({
            "Category":         r["Category"],
            "Before_Cost_INR":  cost_before,
            "After_Cost_INR":   cost_after,
            "Saving_INR":       round(cost_before - cost_after, 2),
            "Saving_Pct":       round(saving_pct, 1),
        })
    df = pd.DataFrame(rows)
    total_before = df["Before_Cost_INR"].sum()
    total_after  = df["After_Cost_INR"].sum()
    df.loc[len(df)] = {
        "Category": "TOTAL",
        "Before_Cost_INR": total_before,
        "After_Cost_INR":  total_after,
        "Saving_INR":      round(total_before - total_after, 2),
        "Saving_Pct":      round((total_before - total_after) / total_before * 100, 1),
    }
    return df


# ── SQL Integration Helpers ───────────────────────────────────

def to_sql_insert(inv_df: pd.DataFrame, snapshot_date: str = "2025-02-01") -> str:
    """Generate SQL INSERT statements for fact_inventory from optimization results."""
    lines = [
        "-- Auto-generated by inventory_engine.py",
        f"-- Snapshot: {snapshot_date}",
        "INSERT INTO fact_inventory",
        "    (snapshot_date, product_id, current_stock, eoq_qty,",
        "     safety_stock, reorder_point, daily_demand, lead_time_days)",
        "VALUES"
    ]
    for i, row in inv_df.iterrows():
        pid = i + 1
        comma = "," if i < len(inv_df) - 1 else ";"
        lines.append(
            f"    ('{snapshot_date}', {pid}, {row['Current_Stock']}, "
            f"{row['EOQ_Units']}, {row['Safety_Stock']}, {row['Reorder_Point']}, "
            f"{row['Daily_Demand']:.4f}, 14){comma}"
        )
    return "\n".join(lines)


# ── Charts ────────────────────────────────────────────────────

def plot_stock_health(inv_df: pd.DataFrame, save_path: str = None):
    cats = inv_df["Category"].tolist()
    x = np.arange(len(cats)); w = 0.25
    fig, ax = plt.subplots(figsize=(12, 6))
    ax.bar(x - w, inv_df["Current_Stock"],   w, label="Current Stock",  color="#2E75B6", alpha=0.9)
    ax.bar(x,     inv_df["Reorder_Point"],    w, label="Reorder Point",  color="#C0392B", alpha=0.9)
    ax.bar(x + w, inv_df["Safety_Stock"],     w, label="Safety Stock",   color="#1E8449", alpha=0.9)
    ax.set_xticks(x); ax.set_xticklabels(cats, rotation=15, ha="right")
    ax.set_ylabel("Units"); ax.set_title("Inventory Health: Current vs ROP vs Safety Stock",
                                          fontsize=12, fontweight="bold")
    ax.legend(); ax.grid(axis="y", alpha=0.3)
    plt.tight_layout()
    _save_or_show(fig, save_path)


def plot_cost_breakdown(inv_df: pd.DataFrame, save_path: str = None):
    cats = inv_df["Category"].tolist()
    x = np.arange(len(cats))
    fig, ax = plt.subplots(figsize=(11, 5))
    ax.bar(x, inv_df["Annual_Holding_Cost_INR"],
           label="Holding Cost", color="#2E75B6", alpha=0.9)
    ax.bar(x, inv_df["Annual_Ordering_Cost_INR"],
           bottom=inv_df["Annual_Holding_Cost_INR"],
           label="Ordering Cost", color="#1A7A6E", alpha=0.9)
    ax.set_xticks(x); ax.set_xticklabels(cats, rotation=15, ha="right")
    ax.set_ylabel("Annual Cost (₹)")
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"₹{v:,.0f}"))
    ax.set_title("Annual Inventory Cost Breakdown", fontsize=12, fontweight="bold")
    ax.legend(); ax.grid(axis="y", alpha=0.3)
    plt.tight_layout()
    _save_or_show(fig, save_path)


def plot_cost_savings(savings_df: pd.DataFrame, save_path: str = None):
    df = savings_df[savings_df["Category"] != "TOTAL"].copy()
    x = np.arange(len(df)); w = 0.35
    fig, ax = plt.subplots(figsize=(11, 5))
    ax.bar(x - w/2, df["Before_Cost_INR"], w, label="Before (Fixed Qty)", color="#C0392B", alpha=0.85)
    ax.bar(x + w/2, df["After_Cost_INR"],  w, label="After (EOQ)",        color="#1E8449", alpha=0.85)
    for i, row in df.iterrows():
        ax.text(i, max(row["Before_Cost_INR"], row["After_Cost_INR"]) * 1.02,
                f"−{row['Saving_Pct']:.0f}%", ha="center", va="bottom", fontsize=9,
                color="#1E8449", fontweight="bold")
    ax.set_xticks(x); ax.set_xticklabels(df["Category"].tolist(), rotation=15, ha="right")
    ax.set_ylabel("Annual Inventory Cost (₹)")
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"₹{v:,.0f}"))
    ax.set_title("Cost Savings: Fixed Order Qty vs EOQ Optimization", fontsize=12, fontweight="bold")
    ax.legend(); ax.grid(axis="y", alpha=0.3)
    total_row = savings_df[savings_df["Category"] == "TOTAL"].iloc[0]
    ax.text(0.98, 0.97, f"Total Saving: ₹{total_row['Saving_INR']:,.0f}  ({total_row['Saving_Pct']:.1f}%)",
            transform=ax.transAxes, ha="right", va="top", fontsize=10,
            bbox=dict(boxstyle="round,pad=0.3", facecolor="#D5F5E3", alpha=0.9))
    plt.tight_layout()
    _save_or_show(fig, save_path)


def plot_eoq_curve(category: str, annual_demand: float,
                   ordering_cost: float, holding_cost_pu: float,
                   save_path: str = None):
    opt = eoq(annual_demand, ordering_cost, holding_cost_pu)
    q   = np.linspace(max(1, opt * 0.2), opt * 3.5, 400)
    hc  = (q / 2) * holding_cost_pu
    oc  = (annual_demand / q) * ordering_cost
    tc  = hc + oc
    fig, ax = plt.subplots(figsize=(9, 5))
    ax.plot(q, hc, "--", color="#2E75B6", lw=1.8, label="Holding Cost")
    ax.plot(q, oc, "--", color="#C0392B", lw=1.8, label="Ordering Cost")
    ax.plot(q, tc, "-",  color="#1B2A4A", lw=2.5, label="Total Cost")
    ax.axvline(opt, color="#1E8449", lw=2, linestyle=":", label=f"EOQ = {opt} units")
    min_cost = (opt/2)*holding_cost_pu + (annual_demand/opt)*ordering_cost
    ax.annotate(f"Min ₹{min_cost:,.0f}", xy=(opt, min_cost),
                xytext=(opt*1.35, min_cost*1.2),
                arrowprops=dict(arrowstyle="->", color="#1E8449"), fontsize=9, color="#1E8449")
    ax.set_title(f"EOQ Cost Curve – {category}", fontsize=12, fontweight="bold")
    ax.set_xlabel("Order Quantity (Units)"); ax.set_ylabel("Annual Cost (₹)")
    ax.yaxis.set_major_formatter(mticker.FuncFormatter(lambda v, _: f"₹{v:,.0f}"))
    ax.legend(); ax.grid(alpha=0.3)
    plt.tight_layout()
    _save_or_show(fig, save_path)


def _save_or_show(fig, save_path):
    if save_path:
        os.makedirs(os.path.dirname(save_path), exist_ok=True)
        fig.savefig(save_path, dpi=150, bbox_inches="tight")
        plt.close(fig)
    else:
        plt.show()


if __name__ == "__main__":
    params = pd.read_csv("data/raw/inventory_params.csv")
    inv_df = run_optimization(params)
    print("\n📦 INVENTORY OPTIMIZATION RESULTS")
    print(inv_df[["Category","EOQ_Units","Safety_Stock","Reorder_Point",
                  "Days_of_Supply","Total_Inventory_Cost_INR","Alert_Status"]].to_string(index=False))

    savings = cost_savings_analysis(params)
    print("\n💰 COST SAVINGS ANALYSIS")
    print(savings.to_string(index=False))

    os.makedirs("data/processed", exist_ok=True)
    inv_df.to_csv("data/processed/inventory_results.csv", index=False)
    savings.to_csv("data/processed/cost_savings.csv", index=False)

    # Generate SQL INSERT
    sql_out = to_sql_insert(inv_df)
    with open("data/processed/insert_inventory_snapshot.sql", "w") as f:
        f.write(sql_out)
    print("\n✅ Outputs saved to data/processed/")

    os.makedirs("outputs/charts", exist_ok=True)
    plot_stock_health(inv_df,   save_path="outputs/charts/stock_health.png")
    plot_cost_breakdown(inv_df, save_path="outputs/charts/cost_breakdown.png")
    plot_cost_savings(savings,  save_path="outputs/charts/cost_savings.png")
    electronics = params[params["Category"] == "Electronics"].iloc[0]
    hc_pu = electronics["Unit_Cost_INR"] * electronics["Holding_Cost_Pct"]
    plot_eoq_curve("Electronics", electronics["Annual_Demand"], 2500, hc_pu,
                   save_path="outputs/charts/eoq_curve_electronics.png")
    print("✅ Charts saved to outputs/charts/")
