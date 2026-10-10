import os
import psycopg2

conn = psycopg2.connect(
    host='aws-0-ap-northeast-1.pooler.supabase.com',
    port=5432,
    user='postgres.japxiaxyabhhhclphbqr',
    password=os.environ["SUPABASE_DB_PASSWORD"],
    dbname='postgres',
    connect_timeout=10
)
cur = conn.cursor()
cur.execute("""
    SELECT pid, query, state, wait_event_type, wait_event, query_start
    FROM pg_stat_activity 
    WHERE state != 'idle' AND pid != pg_backend_pid();
""")
for r in cur.fetchall():
    print(r)
conn.close()
