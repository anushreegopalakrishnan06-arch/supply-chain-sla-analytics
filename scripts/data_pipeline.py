"""
Script: data_pipeline.py
Author: Supply Chain Analytics Team
Purpose: Ingests raw logistics transactional datasets, models analytical 
         Star Schema in SQLite/DuckDB, executes SLA breach queries, 
         and exports BI reporting extracts.
"""

import os
import sys
import sqlite3
import pandas as pd

BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(BASE_DIR, "data")
SQL_DIR = os.path.join(BASE_DIR, "sql")
REPORTS_DIR = os.path.join(BASE_DIR, "reports")
DB_PATH = os.path.join(BASE_DIR, "supply_chain.db")

os.makedirs(REPORTS_DIR, exist_ok=True)
os.makedirs(DATA_DIR, exist_ok=True)


def get_connection():
    return sqlite3.connect(DB_PATH)


def load_raw_csv_data():
    """
    Scans the data/ directory and loads Olist CSVs into SQLite database.
    Expected files:
      - olist_orders_dataset.csv
      - olist_order_items_dataset.csv
      - olist_order_reviews_dataset.csv
      - olist_customers_dataset.csv
      - olist_sellers_dataset.csv
    """
    print("\n[INFO] Starting data ingestion into SQLite analytical warehouse...")
    conn = get_connection()
    
    file_table_mapping = {
        "olist_orders_dataset.csv": "fact_orders_fulfillment",
        "olist_order_items_dataset.csv": "fact_order_items",
        "olist_order_reviews_dataset.csv": "fact_order_reviews",
        "olist_customers_dataset.csv": "dim_customers",
        "olist_sellers_dataset.csv": "dim_sellers"
    }
    
    loaded_any = False
    for filename, table_name in file_table_mapping.items():
        filepath = os.path.join(DATA_DIR, filename)
        if os.path.exists(filepath):
            print(f" -> Loading {filename} into table '{table_name}'...")
            df = pd.read_csv(filepath)
            df.to_sql(table_name, conn, if_exists="replace", index=False)
            print(f"    [OK] Loaded {len(df):,} records.")
            loaded_any = True
        else:
            print(f"    [SKIP] File not found: {filename} in {DATA_DIR}")
            
    conn.close()
    if loaded_any:
        print("[SUCCESS] Raw data ingestion complete.")
    else:
        print("\n[NOTE] Place your Olist CSV files into the 'data/' folder:")
        print(f"       Folder path: {DATA_DIR}")
        print("       Files: olist_orders_dataset.csv, olist_order_items_dataset.csv, etc.")


def run_sql_diagnostic(sql_file_path):
    """
    Executes a SQL diagnostic script and displays the analytical result.
    """
    if not os.path.exists(sql_file_path):
        print(f"[ERROR] SQL file not found: {sql_file_path}")
        return

    print(f"\n[EXEC] Running: {os.path.basename(sql_file_path)}")
    conn = get_connection()
    
    with open(sql_file_path, "r", encoding="utf-8") as f:
        sql_content = f.read()

    # Split script by semicolon into individual runnable queries
    queries = [q.strip() for q in sql_content.split(";") if len(q.strip()) > 5]
    
    for idx, q in enumerate(queries, start=1):
        try:
            df = pd.read_sql_query(q, conn)
            print(f"\n--- Output Query {idx} ({len(df)} rows) ---")
            print(df.to_string(index=False))
            
            # Export to reports
            export_name = f"{os.path.splitext(os.path.basename(sql_file_path))[0]}_q{idx}.csv"
            export_path = os.path.join(REPORTS_DIR, export_name)
            df.to_csv(export_path, index=False)
            print(f"[REPORT] Exported result -> {export_path}")
        except Exception as e:
            print(f"    [WARNING] Query {idx} error: {e}")
            
    conn.close()


if __name__ == "__main__":
    print("=" * 70)
    print(" Supply Chain SLA & Customer Concession Analytics Pipeline")
    print("=" * 70)
    
    load_raw_csv_data()
    
    # Execute analytical diagnostics
    diag_files = [
        "02_delivery_sla_breach_analysis.sql",
        "03_bottleneck_decomposition.sql",
        "04_customer_review_concessions.sql"
    ]
    
    for f in diag_files:
        run_sql_diagnostic(os.path.join(SQL_DIR, f))
        
    print("\n" + "=" * 70)
    print(" Diagnostic run complete. Reports ready in 'reports/' folder.")
    print("=" * 70)
