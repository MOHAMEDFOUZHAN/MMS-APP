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
cur.execute("""
    SELECT routine_name, routine_definition 
    FROM information_schema.routines 
    WHERE routine_schema = 'public' 
      AND routine_name IN ('get_storage_dispatch_preview', 'create_dispatch_fifo');
""")
for name, defn in cur.fetchall():
    print(f"*** {name} ***")
    for line in defn.split('\n'):
        if any(k in line for k in ['ORDER BY', 'received_at', 'COALESCE(b.received_at', 'id ASC', 'batch_no']):
            print('  ', line.strip())
conn.close()
