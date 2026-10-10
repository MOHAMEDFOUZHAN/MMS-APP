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

cur.execute("""
SELECT proname, pg_get_function_arguments(oid)
FROM pg_proc 
WHERE proname IN ('create_dispatch_fifo', 'update_dispatch', 'delete_dispatch');
""")
for r in cur.fetchall():
    print(r[0], '-->', r[1])

cur.close()
conn.close()
