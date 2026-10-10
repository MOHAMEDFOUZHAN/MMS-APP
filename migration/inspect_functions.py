import os
import psycopg2

conn = psycopg2.connect(
    host='aws-0-ap-northeast-1.pooler.supabase.com',
    port=5432,
    user='postgres.japxiaxyabhhhclphbqr',
    password=os.environ["SUPABASE_DB_PASSWORD"],
    dbname='postgres',
    connect_timeout=15
)
cur = conn.cursor()

for fname in ['create_purchase', 'update_purchase', 'delete_purchase', 'create_transfer', 'update_transfer', 'delete_transfer']:
    print(f"==================== {fname} ====================")
    cur.execute("SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = %s;", (fname,))
    rows = cur.fetchall()
    for r in rows:
        print(r[0])
    print()
