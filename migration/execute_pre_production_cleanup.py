import sys
import os
import json
import psycopg2

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = os.environ["SUPABASE_DB_PASSWORD"]
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'
BACKUP_PATH = r'migration/pre_production_cleanup_backup_20261004.json'

def main():
    print("=" * 80)
    print("MMS BENCHMARK â€” PRE-PRODUCTION TEST DATA CLEANUP")
    print("=" * 80)

    # 1. Check backup file exists
    if not os.path.exists(BACKUP_PATH):
        raise FileNotFoundError(f"Safety backup file not found at {BACKUP_PATH}!")
    
    file_size = os.path.getsize(BACKUP_PATH)
    print(f"Verified safety backup exists: {BACKUP_PATH} ({file_size} bytes)")

    # 2. Connect to Supabase
    conn = psycopg2.connect(
        host=HOST,
        port=PORT,
        user=USER,
        password=PASSWORD,
        dbname=DBNAME,
        connect_timeout=15
    )
    conn.autocommit = False
    cur = conn.cursor()

    try:
        # Step A: Truncate test transaction and logging tables
        print("\n[1/4] Truncating operational test transactions and logs...")
        cur.execute("""
            TRUNCATE TABLE 
                dispatch_batches,
                dispatches,
                transfer_lot_allocations,
                transfers,
                invoice_items,
                batches,
                invoices,
                material_lots,
                storage_products,
                stock_adjustments,
                notifications,
                audit_logs,
                idempotency_keys
            CASCADE;
        """)
        print("  -> Truncated: dispatch_batches, dispatches, transfer_lot_allocations, transfers,")
        print("                invoice_items, batches, invoices, material_lots, storage_products,")
        print("                stock_adjustments, notifications, audit_logs, idempotency_keys")

        # Step B: Remove automated test item 'CARD-TEA-01'
        print("\n[2/4] Removing automated test material 'CARD-TEA-01'...")
        cur.execute("DELETE FROM materials WHERE material_code = 'CARD-TEA-01';")
        print(f"  -> Deleted {cur.rowcount} test material row(s).")

        # Step C: Reset operational inventory quantities on master materials
        print("\n[3/4] Resetting inventory quantities on master materials (keeping code, description, category, unit)...")
        cur.execute("""
            UPDATE materials
            SET quantity = 0.000,
                opening_stock = 0.000,
                lot_no = NULL,
                purchase_date = NULL,
                expiry_date = NULL,
                unit_price = 0.00,
                last_updated = CURRENT_TIMESTAMP;
        """)
        print(f"  -> Updated {cur.rowcount} master materials.")

        # Commit transaction
        conn.commit()
        print("\n>>> All changes committed successfully!")

        # Step D: Verification
        print("\n[4/4] Verifying post-cleanup state...")
        
        # Verify materials
        cur.execute("SELECT count(*), sum(quantity), sum(opening_stock) FROM materials;")
        mat_count, mat_qty, mat_open = cur.fetchone()
        print(f"  â€¢ Master Materials Count: {mat_count} (Expected: 151)")
        print(f"  â€¢ Total Quantity:         {mat_qty} (Expected: 0.000)")
        print(f"  â€¢ Total Opening Stock:    {mat_open} (Expected: 0.000)")

        # Verify sample materials (code, description, category intact)
        cur.execute("SELECT material_code, description, category, unit FROM materials ORDER BY material_code LIMIT 5;")
        print("  â€¢ Sample preserved materials:")
        for r in cur.fetchall():
            print(f"      Code: {r[0]:<12} | Desc: {r[1]:<30} | Cat: {r[2]:<12} | Unit: {r[3]}")

        # Verify operational tables are completely empty
        tables_to_verify = [
            'invoices', 'invoice_items', 'transfers', 'transfer_lot_allocations',
            'material_lots', 'batches', 'dispatches', 'dispatch_batches',
            'storage_products', 'stock_adjustments', 'notifications',
            'audit_logs', 'idempotency_keys'
        ]
        print("\n  â€¢ Operational table row counts (must all be 0):")
        all_zero = True
        for tbl in tables_to_verify:
            cur.execute(f"SELECT count(*) FROM {tbl};")
            cnt = cur.fetchone()[0]
            print(f"      {tbl:<26}: {cnt} rows")
            if cnt != 0:
                all_zero = False

        # Verify master system tables are untouched
        cur.execute("SELECT count(*) FROM user_profiles;")
        usr_cnt = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM system_settings;")
        sys_cnt = cur.fetchone()[0]
        cur.execute("SELECT count(*) FROM app_versions;")
        ver_cnt = cur.fetchone()[0]
        print(f"\n  â€¢ System Master Tables (Untouched):")
        print(f"      user_profiles : {usr_cnt} rows (Expected: 3)")
        print(f"      system_settings: {sys_cnt} rows (Expected: 2)")
        print(f"      app_versions   : {ver_cnt} rows (Expected: 6)")

        assert mat_count == 151, f"Expected 151 materials, got {mat_count}"
        assert float(mat_qty) == 0.0, f"Expected 0 quantity, got {mat_qty}"
        assert all_zero, "Some operational tables were not empty!"
        assert usr_cnt == 3, f"Expected 3 users, got {usr_cnt}"
        assert sys_cnt == 2, f"Expected 2 settings, got {sys_cnt}"

        print("\n" + "=" * 80)
        print("DATABASE IS 100% CLEAN AND READY FOR PRODUCTION LAUNCH TOMORROW!")
        print("=" * 80)

    except Exception as e:
        conn.rollback()
        print(f"\n[ERROR] An error occurred: {e}")
        raise
    finally:
        cur.close()
        conn.close()

if __name__ == '__main__':
    main()
