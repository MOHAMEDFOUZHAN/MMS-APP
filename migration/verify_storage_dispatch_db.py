import os
import psycopg2
import sys
sys.stdout.reconfigure(encoding='utf-8')

conn = psycopg2.connect(
    host='aws-0-ap-northeast-1.pooler.supabase.com',
    port=5432,
    user='postgres.japxiaxyabhhhclphbqr',
    password=os.environ["SUPABASE_DB_PASSWORD"],
    dbname='postgres',
    connect_timeout=15
)
cur = conn.cursor()

print("--- Realtime Publication Tables ---")
cur.execute("SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';")
print([r[0] for r in cur.fetchall()])

print("\n--- Inspecting create_dispatch_fifo definition ---")
cur.execute("SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'create_dispatch_fifo';")
rows = cur.fetchall()
if rows:
    print(rows[0][0])
else:
    print("create_dispatch_fifo NOT found!")

print("\n--- Inspecting update_dispatch definition ---")
cur.execute("SELECT pg_get_functiondef(oid) FROM pg_proc WHERE proname = 'update_dispatch';")
rows = cur.fetchall()
if rows:
    print(rows[0][0])
else:
    print("update_dispatch NOT found!")

cur.close()
conn.close()
