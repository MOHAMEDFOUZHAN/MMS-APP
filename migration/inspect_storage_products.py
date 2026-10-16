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
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'storage_products' AND table_schema = 'public';
""")
print("storage_products columns:", cur.fetchall())

cur.execute("SELECT * FROM storage_products LIMIT 5;")
print("storage_products rows:", cur.fetchall())

conn.close()
