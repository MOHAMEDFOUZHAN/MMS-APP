import os
import sys
import psycopg2

sys.stdout.reconfigure(encoding='utf-8')

def run_migration(db_url_or_password):
    if db_url_or_password.startswith("postgresql://") or db_url_or_password.startswith("postgres://"):
        conn_str = db_url_or_password
    else:
        # Default host for project japxiaxyabhhhclphbqr
        project_ref = "japxiaxyabhhhclphbqr"
        pwd = db_url_or_password.strip()
        # Direct connection or session pooler
        conn_str = f"postgresql://postgres:{pwd}@db.{project_ref}.supabase.co:5432/postgres"

    print("Connecting to Supabase PostgreSQL database...")
    try:
        conn = psycopg2.connect(conn_str, connect_timeout=15)
    except Exception as e:
        # Fallback to pooler if direct IPv6 fails on IPv4-only networks
        print(f"Direct connection attempt: {e}")
        print("Trying Supabase Connection Pooler (port 6543)...")
        conn_str_pooler = f"postgresql://postgres.{project_ref}:{pwd}@aws-0-ap-south-1.pooler.supabase.com:6543/postgres"
        try:
            conn = psycopg2.connect(conn_str_pooler, connect_timeout=15)
        except Exception as e2:
            print(f"Pooler connection attempt failed: {e2}")
            raise e

    conn.autocommit = True
    cur = conn.cursor()

    migration_file = r"d:\projects\MMS APP\migration\00_master_cloud_migration.sql"
    print(f"Reading master migration script: {migration_file}...")
    with open(migration_file, "r", encoding="utf-8") as f:
        sql = f.read()

    print("Executing complete schema and data migration...")
    cur.execute(sql)
    print("Migration executed successfully!")

    print("\nRunning verification checksum query...")
    verification_query = """
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
        ROUND(SUM(item_total), 2), 
        4570951.10,
        CASE WHEN COUNT(*) = 92 AND ROUND(SUM(item_total), 2) = 4570951.10 THEN 'MATCH' ELSE 'MISMATCH' END
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
        1114.213,
        CASE WHEN COUNT(*) = 219 THEN 'MATCH' ELSE 'MISMATCH' END
    FROM stock_adjustments;
    """
    cur.execute(verification_query)
    results = cur.fetchall()

    print("\n" + "=" * 80)
    print(f"{'Table':<20} | {'Count':>6} | {'Expected':>8} | {'Sum Value':>12} | {'Exp Value':>12} | {'Status':>8}")
    print("-" * 80)
    for row in results:
        tname, cnt, exp_cnt, val_sum, exp_sum, status = row
        print(f"{tname:<20} | {cnt:>6} | {exp_cnt:>8} | {str(val_sum):>12} | {str(exp_sum):>12} | {status:>8}")
    print("=" * 80)

    cur.close()
    conn.close()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python run_cloud_migration.py <db_password_or_connection_uri>")
        sys.exit(1)
    run_migration(sys.argv[1])
