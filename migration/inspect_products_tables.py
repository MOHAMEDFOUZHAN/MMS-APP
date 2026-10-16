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

cur.execute("""
SELECT id, batch_no, material_code, description, available_quantity, uom, department, rack_location 
FROM public.batches 
LIMIT 5;
""")
print("Sample batches:")
for r in cur.fetchall():
    print(r)

cur.execute("""
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' AND (table_name ILIKE '%prod%' OR table_name ILIKE '%storage%');
""")
print("\nRelated tables:")
for r in cur.fetchall():
    print(r)

conn.close()
