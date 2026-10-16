import os
import psycopg2

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = os.environ.get("SUPABASE_DB_PASSWORD", "mapleconnect2307")
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(
    host=HOST,
    port=PORT,
    user=USER,
    password=PASSWORD,
    dbname=DBNAME,
    connect_timeout=15
)
cur = conn.cursor()

print("=== OUT OF STOCK SAMPLE (ADMIN FILTER) ===")
cur.execute("SELECT material_code, description, location, location_stock, total_business_stock, stock_status, status_message FROM public.get_owner_out_of_stock_report('ADMIN') WHERE total_business_stock > 0 LIMIT 5;")
for r in cur.fetchall():
    print(r)

print("\n=== REORDER REPORT SAMPLE (REORDER_REQUIRED) ===")
cur.execute("SELECT material_code, description, location, available_stock, reorder_level, target_stock, suggested_replenishment, status, status_message FROM public.get_owner_reorder_report('ALL', NULL, 'REORDER_REQUIRED') LIMIT 5;")
for r in cur.fetchall():
    print(r)

conn.close()
