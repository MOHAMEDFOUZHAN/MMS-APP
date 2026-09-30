import psycopg2

conn = psycopg2.connect(
    host='aws-0-ap-northeast-1.pooler.supabase.com',
    port=5432,
    user='postgres.japxiaxyabhhhclphbqr',
    password='mapleconnect2307',
    dbname='postgres'
)
conn.autocommit = True
cur = conn.cursor()

tables = [
    'materials', 'invoices', 'invoice_items', 'batches', 
    'dispatches', 'dispatch_batches', 'transfers', 
    'stock_adjustments', 'category_locations', 'vendors', 'system_settings'
]

print("Dropping existing policies...")
for t in tables:
    cur.execute(f"""
        DO $$
        DECLARE r RECORD;
        BEGIN
            FOR r IN (SELECT policyname FROM pg_policies WHERE tablename = '{t}') LOOP
                EXECUTE format('DROP POLICY IF EXISTS %I ON %I', r.policyname, '{t}');
            END LOOP;
        END $$;
    """)

print("Applying updated policies from supabase/rls.sql...")
with open(r'd:\projects\MMS APP\supabase\rls.sql', 'r', encoding='utf-8') as f:
    sql = f.read()
cur.execute(sql)

print("RLS policies updated successfully!")
cur.close()
conn.close()
