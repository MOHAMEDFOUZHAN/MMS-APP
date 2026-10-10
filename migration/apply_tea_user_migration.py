import os
import psycopg2

PROJECT_REF = 'japxiaxyabhhhclphbqr'
DB_PASSWORD = os.environ["SUPABASE_DB_PASSWORD"]
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=DB_PASSWORD, dbname=DBNAME, connect_timeout=20)
conn.autocommit = True
cur = conn.cursor()

print("Reading supabase/09_tea_restricted_user.sql...")
with open("d:/projects/MMS APP/supabase/09_tea_restricted_user.sql", "r", encoding="utf-8") as f:
    sql = f.read()

print("Executing migration SQL...")
cur.execute(sql)
print("Migration applied successfully!")

# Verify functions exist
test_fns = [
    'is_tea_user',
    'is_tea_product',
    'get_transfer_available_materials',
    'create_transfer',
    'update_transfer',
    'delete_transfer',
    'get_storage_products',
    'upsert_storage_product',
    'get_dispatch_available_products',
    'create_dispatch_fifo',
    'update_dispatch',
    'delete_dispatch',
    'safe_delete_batch',
    'update_batch_stock'
]

print("\nVerifying routines:")
for fn in test_fns:
    cur.execute("SELECT proname FROM pg_proc WHERE proname = %s;", (fn,))
    r = cur.fetchone()
    print(f"  - {fn}: {'FOUND' if r else 'MISSING'}")

cur.close()
conn.close()
