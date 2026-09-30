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
cur = conn.cursor()

cur.execute("SELECT id, material_code, description, category, unit FROM materials WHERE category ILIKE '%chocolat%';")
print("--- Chocolat* categories ---")
for r in cur.fetchall():
    if 'chocolater' in r[3].lower():
        print(r)

cur.execute("SELECT id, material_code, description, category, unit FROM materials WHERE description ILIKE '%vennil%';")
print("\n--- Vennil* descriptions ---")
for r in cur.fetchall():
    print(r)

cur.close()
conn.close()
