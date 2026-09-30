import psycopg2

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
cur = conn.cursor()

cur.execute("""
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
ORDER BY table_name;
""")
tables = [r[0] for r in cur.fetchall()]
print("All public tables in Supabase:")
for t in tables:
    cur.execute(f"SELECT count(*) FROM {t}")
    cnt = cur.fetchone()[0]
    print(f"  {t}: {cnt} rows")

cur.execute("SELECT sum(opening_stock), sum(quantity) FROM materials;")
print("Sum of opening_stock and quantity in materials:", cur.fetchone())

cur.close()
conn.close()
