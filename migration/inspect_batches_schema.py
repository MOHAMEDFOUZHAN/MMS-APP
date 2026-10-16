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

print("=== COLUMNS IN BATCHES TABLE ===")
cur.execute("""
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'batches' AND table_schema = 'public'
ORDER BY ordinal_position;
""")
for r in cur.fetchall():
    print(r)

print("\n=== SAMPLE BATCHES ===")
cur.execute("""
SELECT id, batch_no, product_name, department, quantity, available_quantity, unit, rack_location, storage_room
FROM public.batches
LIMIT 5;
""")
for r in cur.fetchall():
    print(r)

conn.close()
