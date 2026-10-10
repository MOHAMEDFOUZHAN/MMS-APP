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

print("--- Triggers on relevant tables ---")
cur.execute("""
SELECT 
    event_object_table, 
    trigger_name, 
    action_timing,
    event_manipulation, 
    action_statement
FROM information_schema.triggers
WHERE event_object_table IN ('invoices', 'invoice_items', 'materials', 'transfers', 'stock_adjustments', 'batches', 'dispatches')
ORDER BY event_object_table, trigger_name;
""")
for r in cur.fetchall():
    print(r)

print("\n--- Search function definitions for 'lot_no' ---")
cur.execute("""
SELECT proname, prosrc
FROM pg_proc
WHERE prosrc ILIKE '%lot_no%';
""")
for r in cur.fetchall():
    print(f"Function: {r[0]}")
    # print snippet
    for line in r[1].split('\n'):
        if 'lot_no' in line.lower() or 'trigger' in line.lower() or 'new.' in line.lower():
            print(f"   {line}")
    print()

print("\n--- Check columns of relevant tables ---")
for t in ['invoices', 'invoice_items', 'materials', 'transfers']:
    cur.execute("""
    SELECT column_name, data_type, is_nullable
    FROM information_schema.columns
    WHERE table_name = %s
    ORDER BY ordinal_position;
    """, (t,))
    print(f"Columns in {t}:")
    for col in cur.fetchall():
        print(f"   {col}")
