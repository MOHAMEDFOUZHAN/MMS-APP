import psycopg2
import json

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
cur = conn.cursor()

# Get table row counts
tables = ['materials', 'invoices', 'invoice_items', 'transfers', 'stock_adjustments', 'batches', 'dispatches', 'dispatch_batches', 'vendors', 'category_locations', 'system_settings']
print('--- Table Counts ---')
for t in tables:
    try:
        cur.execute(f'SELECT count(*) FROM {t}')
        print(f'{t}: {cur.fetchone()[0]}')
    except Exception as e:
        print(f'{t}: Error {e}')
        conn.rollback()

# Check materials columns
cur.execute("""
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'materials'
ORDER BY ordinal_position;
""")
print('\n--- Materials Columns ---')
for col in cur.fetchall():
    print(col)

# Check duplicate material codes
cur.execute("""
SELECT material_code, count(*) 
FROM materials 
GROUP BY material_code 
HAVING count(*) > 1;
""")
dups = cur.fetchall()
print(f'\n--- Duplicate Material Codes ({len(dups)}) ---')
for d in dups:
    print(d)

# For each duplicate, let's see the details
for d in dups:
    code = d[0]
    cur.execute("SELECT id, material_code, description, category, grade, uom, hsn_sac, reorder_level, quantity, opening_stock FROM materials WHERE material_code = %s", (code,))
    rows = cur.fetchall()
    print(f"\nDetails for duplicate code '{code}':")
    for r in rows:
        print(r)

# Check unique constraints or indexes on materials
cur.execute("""
SELECT conname, contype 
FROM pg_constraint 
WHERE conrelid = 'materials'::regclass;
""")
print('\n--- Materials Constraints ---')
for c in cur.fetchall():
    print(c)

cur.close()
conn.close()
