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

funcs = [
    'create_purchase',
    'update_purchase',
    'delete_purchase',
    'create_transfer',
    'update_transfer',
    'delete_transfer',
    'record_tea_consumption'
]

for fn in funcs:
    cur.execute("""
    SELECT pg_get_functiondef(p.oid)
    FROM pg_proc p
    JOIN pg_namespace n ON p.pronamespace = n.oid
    WHERE n.nspname = 'public' AND p.proname = %s;
    """, (fn,))
    res = cur.fetchall()
    print(f"\n==================== {fn} ====================")
    for r in res:
        print(r[0])

conn.close()
