import psycopg2
import sys
sys.stdout.reconfigure(encoding='utf-8')

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
conn.autocommit = True
cur = conn.cursor()

print("Applying updated supabase/functions.sql to Supabase PostgreSQL...")
with open(r"d:\projects\MMS APP\supabase\functions.sql", "r", encoding="utf-8") as f:
    sql = f.read()

cur.execute(sql)
print("Functions & Stored Procedures applied successfully!")

# Verify functions in pg_proc
cur.execute("""
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
ORDER BY routine_name;
""")
routines = [r[0] for r in cur.fetchall()]
print(f"\nVerified {len(routines)} active routines in Supabase:")
for r in routines:
    print(f"  • {r}")

cur.close()
conn.close()
