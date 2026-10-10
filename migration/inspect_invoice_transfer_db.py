import os
import psycopg2
import json

conn = psycopg2.connect(
    host='aws-0-ap-northeast-1.pooler.supabase.com',
    port=5432,
    user='postgres.japxiaxyabhhhclphbqr',
    password=os.environ["SUPABASE_DB_PASSWORD"],
    dbname='postgres',
    connect_timeout=15
)
cur = conn.cursor()

tables_to_check = ['invoices', 'invoice_items', 'materials', 'transfers', 'transfer_items', 'batches', 'material_lots', 'transfer_lot_allocations']

print("=== TABLE COLUMNS ===")
for tbl in tables_to_check:
    cur.execute("""
        SELECT column_name, data_type, is_nullable, column_default
        FROM information_schema.columns
        WHERE table_schema = 'public' AND table_name = %s
        ORDER BY ordinal_position;
    """, (tbl,))
    cols = cur.fetchall()
    if cols:
        print(f"\nTable: {tbl}")
        for c in cols:
            print(f"  {c[0]}: {c[1]} (nullable: {c[2]}, default: {c[3]})")
    else:
        print(f"\nTable: {tbl} (DOES NOT EXIST)")

print("\n=== TRIGGERS ON INVOICE_ITEMS & INVOICES & TRANSFERS ===")
cur.execute("""
    SELECT event_object_table, trigger_name, action_timing, event_manipulation, action_statement
    FROM information_schema.triggers
    WHERE event_object_schema = 'public' 
      AND event_object_table IN ('invoices', 'invoice_items', 'transfers', 'transfer_items', 'materials')
    ORDER BY event_object_table, trigger_name;
""")
for trig in cur.fetchall():
    print(trig)

print("\n=== FUNCTION DEFINITION: trg_invoice_items_normalize / related trigger functions ===")
cur.execute("""
    SELECT routine_name, routine_definition
    FROM information_schema.routines
    WHERE routine_schema = 'public'
      AND routine_name ILIKE '%invoice%' OR routine_name ILIKE '%transfer%' OR routine_name ILIKE '%purchase%';
""")
routines = cur.fetchall()
for r in routines:
    print(f"Routine: {r[0]}")

conn.close()
