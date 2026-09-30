import os
import sys
import psycopg2

sys.stdout.reconfigure(encoding='utf-8')

PROJECT_REF = "japxiaxyabhhhclphbqr"
PASSWORD = "mapleconnect2307"
HOST = "aws-0-ap-northeast-1.pooler.supabase.com"
PORT = 5432
USER = f"postgres.{PROJECT_REF}"
DBNAME = "postgres"

def run():
    print("=" * 80)
    print("BENCHMARK MMS — DIRECT SUPABASE PRODUCTION DATA MIGRATION")
    print(f"Connecting to {HOST}:{PORT} (Project: {PROJECT_REF})...")
    print("=" * 80)

    conn = psycopg2.connect(
        host=HOST,
        port=PORT,
        user=USER,
        password=PASSWORD,
        dbname=DBNAME,
        connect_timeout=15
    )
    conn.autocommit = True
    cur = conn.cursor()
    print("Connected successfully to Supabase PostgreSQL (v17.6)!\n")

    base_dir = r"d:\projects\MMS APP"

    # Step 0: Clean Reset of Tables
    print(">>> [0/5] Resetting tables to ensure fresh schema...")
    cur.execute("""
    DROP TABLE IF EXISTS 
        system_settings, 
        category_locations, 
        stock_adjustments, 
        transfers, 
        dispatch_batches, 
        dispatches, 
        batches, 
        invoice_items, 
        invoices, 
        vendors, 
        materials 
    CASCADE;
    """)
    print("    Tables reset.")

    # Step 1: Schema
    print(">>> [1/5] Applying Schema & Indexes (supabase/schema.sql)...")
    with open(os.path.join(base_dir, "supabase", "schema.sql"), "r", encoding="utf-8") as f:
        schema_sql = f.read()
    cur.execute(schema_sql)
    print("    Schema and indexes applied successfully.")

    # Step 2: Functions / Stored Procedures
    print(">>> [2/5] Creating Stored Procedures & Functions (supabase/functions.sql)...")
    with open(os.path.join(base_dir, "supabase", "functions.sql"), "r", encoding="utf-8") as f:
        functions_sql = f.read()
    cur.execute(functions_sql)
    print("    Functions & stored procedures registered successfully.")

    # Step 3: RLS & Realtime
    print(">>> [3/5] Applying Row Level Security & Realtime (supabase/rls.sql)...")
    with open(os.path.join(base_dir, "supabase", "rls.sql"), "r", encoding="utf-8") as f:
        rls_sql = f.read()
    cur.execute(rls_sql)
    print("    Row Level Security & Realtime publications configured.")

    # Step 4: Production Data Ingestion (740 records)
    print(">>> [4/5] Ingesting Production Data (migration/production_data_migration.sql)...")
    with open(os.path.join(base_dir, "migration", "production_data_migration.sql"), "r", encoding="utf-8") as f:
        data_sql = f.read()
    cur.execute(data_sql)
    print("    740 Production records ingested and identity sequences synchronized!")

    # Step 5: Verification Checksum Query
    print("\n>>> [5/5] Running Post-Migration Validation Checksum Query...")
    verify_sql = """
    SELECT 
        'materials' AS table_name, 
        COUNT(*) AS row_count, 
        192 AS expected_count, 
        ROUND(SUM(quantity), 3) AS current_stock_sum, 
        13687.920 AS expected_stock_sum,
        CASE WHEN COUNT(*) = 192 AND ROUND(SUM(quantity), 3) = 13687.920 THEN 'MATCH' ELSE 'MISMATCH' END AS status
    FROM materials
    UNION ALL
    SELECT 
        'invoices', 
        COUNT(*), 
        57, 
        ROUND(SUM(final_total), 2), 
        4571051.46,
        CASE WHEN COUNT(*) = 57 AND ROUND(SUM(final_total), 2) = 4571051.46 THEN 'MATCH' ELSE 'MISMATCH' END
    FROM invoices
    UNION ALL
    SELECT 
        'invoice_items', 
        COUNT(*), 
        92, 
        ROUND(SUM(item_total), 3), 
        4570951.105,
        CASE WHEN COUNT(*) = 92 AND ROUND(SUM(item_total), 3) = 4570951.105 THEN 'MATCH' ELSE 'MISMATCH' END
    FROM invoice_items
    UNION ALL
    SELECT 
        'transfers', 
        COUNT(*), 
        180, 
        ROUND(SUM(outward), 3), 
        579.140,
        CASE WHEN COUNT(*) = 180 AND ROUND(SUM(outward), 3) = 579.140 THEN 'MATCH' ELSE 'MISMATCH' END
    FROM transfers
    UNION ALL
    SELECT 
        'stock_adjustments', 
        COUNT(*), 
        219, 
        ROUND(SUM(amount), 3), 
        4529.747,
        CASE WHEN COUNT(*) = 219 AND ROUND(SUM(amount), 3) = 4529.747 THEN 'MATCH' ELSE 'MISMATCH' END
    FROM stock_adjustments;
    """
    cur.execute(verify_sql)
    rows = cur.fetchall()

    print("\n" + "=" * 84)
    print(f"{'Table Name':<20} | {'Actual Count':>12} | {'Expected':>8} | {'Checksum':>14} | {'Expected Sum':>14} | {'Status':>8}")
    print("-" * 84)
    all_matched = True
    for r in rows:
        tname, act_cnt, exp_cnt, chksum, exp_sum, status = r
        if status != "MATCH":
            all_matched = False
        print(f"{tname:<20} | {act_cnt:>12} | {exp_cnt:>8} | {str(chksum):>14} | {str(exp_sum):>14} | {status:>8}")
    print("=" * 84)

    # Empty structural tables verification
    empty_tables = ["batches", "dispatches", "dispatch_batches", "category_locations", "vendors"]
    print("\nVerifying Empty Structural Tables:")
    for et in empty_tables:
        cur.execute(f"SELECT COUNT(*) FROM {et}")
        cnt = cur.fetchone()[0]
        st = "MATCH" if cnt == 0 else "MISMATCH"
        if st != "MATCH":
            all_matched = False
        print(f"  • {et:<20} : {cnt} rows (Expected: 0) -> [{st}]")

    print("\n" + "=" * 84)
    if all_matched:
        print("🎉 MIGRATION COMPLETED SUCCESSFULLY WITH 100% PRODUCTION PARITY!")
    else:
        print("⚠️ Some discrepancies detected. Check the log output above.")
    print("=" * 84)

    cur.close()
    conn.close()

if __name__ == "__main__":
    run()
