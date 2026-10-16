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

print("--- storage_products ---")
cur.execute("SELECT product_code, product_name, category, uom FROM storage_products ORDER BY product_name;")
for r in cur.fetchall():
    print(r)

print("\n--- chocolate_ocr_ledger distinct products ---")
cur.execute("SELECT DISTINCT description, product_code FROM chocolate_ocr_ledger ORDER BY description;")
for r in cur.fetchall():
    print(r)

print("\n--- All tables in public schema ---")
cur.execute("SELECT table_name FROM information_schema.tables WHERE table_schema='public' ORDER BY table_name;")
for r in cur.fetchall():
    print(r[0])

conn.close()
