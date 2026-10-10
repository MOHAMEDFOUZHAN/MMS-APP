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

for fn in ['trg_invoice_items_normalize', 'create_purchase']:
    cur.execute("""
        SELECT pg_get_functiondef(p.oid)
        FROM pg_proc p
        JOIN pg_namespace n ON p.pronamespace = n.oid
        WHERE n.nspname = 'public' AND p.proname = %s;
    """, (fn,))
    res = cur.fetchall()
    print(f"\n==================== FUNCTION: {fn} ====================")
    for r in res:
        print(r[0])

conn.close()
