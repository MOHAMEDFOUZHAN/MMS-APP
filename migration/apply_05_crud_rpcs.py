import psycopg2
import sys
sys.stdout.reconfigure(encoding='utf-8')

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

print("Connecting to Supabase PostgreSQL...")
conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
conn.autocommit = True
cur = conn.cursor()

print("Applying supabase/05_crud_and_dropdowns.sql...")
with open(r"d:\projects\MMS APP\supabase\05_crud_and_dropdowns.sql", "r", encoding="utf-8") as f:
    sql = f.read()

cur.execute(sql)
print("05_crud_and_dropdowns.sql applied successfully!")

# Verify functions
cur.execute("""
SELECT proname FROM pg_proc p
JOIN pg_namespace n ON p.pronamespace = n.oid
WHERE n.nspname = 'public' 
  AND proname IN ('update_purchase', 'update_transfer', 'update_dispatch', 'safe_delete_batch', 'update_batch_stock')
ORDER BY proname;
""")
funcs = [r[0] for r in cur.fetchall()]
print(f"Verified {len(funcs)} functions:")
for fn in funcs:
    print(f"  • {fn}")

cur.close()
conn.close()
