import os
import psycopg2

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = os.environ.get("SUPABASE_DB_PASSWORD", "mapleconnect2307")
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(
    host=HOST,
    port=PORT,
    user=USER,
    password=PASSWORD,
    dbname=DBNAME,
    connect_timeout=15
)
cur = conn.cursor()

print("=== 1. COLUMNS IN MATERIALS TABLE ===")
cur.execute("""
SELECT column_name, data_type, is_nullable, column_default
FROM information_schema.columns
WHERE table_name = 'materials' AND table_schema = 'public'
ORDER BY ordinal_position;
""")
for r in cur.fetchall():
    print(r)

print("\n=== 2. TRIGGERS ON MATERIALS ===")
cur.execute("""
SELECT trigger_name, event_manipulation, action_statement, action_timing
FROM information_schema.triggers
WHERE event_object_table = 'materials';
""")
for r in cur.fetchall():
    print(r)

print("\n=== 3. TRIGGERS ON INVOICES & INVOICE_ITEMS ===")
cur.execute("""
SELECT event_object_table, trigger_name, event_manipulation, action_timing
FROM information_schema.triggers
WHERE event_object_table IN ('invoices', 'invoice_items');
""")
for r in cur.fetchall():
    print(r)

print("\n=== 4. TRIGGERS ON TRANSFERS ===")
cur.execute("""
SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers
WHERE event_object_table = 'transfers';
""")
for r in cur.fetchall():
    print(r)

print("\n=== 5. CHECK REORDER COLUMNS OR TABLES IN DB ===")
cur.execute("""
SELECT table_name, column_name, data_type 
FROM information_schema.columns 
WHERE column_name ILIKE '%reorder%' OR column_name ILIKE '%min_stock%' OR column_name ILIKE '%target%'
AND table_schema = 'public';
""")
for r in cur.fetchall():
    print(r)

print("\n=== 6. CHECK INVOICE PROCEDURES / FUNCTIONS ===")
cur.execute("""
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' AND (routine_name ILIKE '%invoice%' OR routine_name ILIKE '%purchase%');
""")
for r in cur.fetchall():
    print(r)

print("\n=== 7. CHECK TRANSFER PROCEDURES / FUNCTIONS ===")
cur.execute("""
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' AND routine_name ILIKE '%transfer%';
""")
for r in cur.fetchall():
    print(r)

print("\n=== 8. CHECK TEA & CHOCOLATE FUNCTIONS ===")
cur.execute("""
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' AND (routine_name ILIKE '%tea%' OR routine_name ILIKE '%choc%' OR routine_name ILIKE '%ocr%');
""")
for r in cur.fetchall():
    print(r)

conn.close()
