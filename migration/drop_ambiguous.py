import os
import psycopg2

conn = psycopg2.connect(
    host='aws-0-ap-northeast-1.pooler.supabase.com',
    port=5432,
    user='postgres.japxiaxyabhhhclphbqr',
    password=os.environ["SUPABASE_DB_PASSWORD"],
    dbname='postgres'
)
conn.autocommit = True
cur = conn.cursor()

print("Dropping redundant overloads...")
cur.execute("DROP FUNCTION IF EXISTS public.create_purchase(jsonb, jsonb);")
cur.execute("DROP FUNCTION IF EXISTS public.create_transfer(jsonb);")
cur.execute("DROP FUNCTION IF EXISTS public.update_purchase(bigint, jsonb, jsonb, text);")

print("Checking remaining routines...")
cur.execute("""
    SELECT p.oid, p.proname, pg_get_function_identity_arguments(p.oid) 
    FROM pg_proc p 
    JOIN pg_namespace n ON p.pronamespace = n.oid 
    WHERE n.nspname = 'public' AND p.proname IN ('create_purchase', 'create_transfer', 'update_purchase', 'update_transfer');
""")
for r in cur.fetchall():
    print(r)

conn.close()
