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

print("=== TRANSFERS SUMMARY BY DEPARTMENT ===")
cur.execute("""
SELECT 
    UPPER(TRIM(COALESCE(department, ''))) as dept,
    COUNT(*) as transfer_count,
    COUNT(DISTINCT code) as unique_materials,
    SUM(outward) as total_outward,
    SUM(return_units) as total_returned,
    SUM(outward - return_units) as net_transferred
FROM public.transfers
GROUP BY UPPER(TRIM(COALESCE(department, '')));
""")
for r in cur.fetchall():
    print(r)

print("\n=== TEA CONSUMPTION SUMMARY ===")
cur.execute("""
SELECT 
    COUNT(*) as total_records,
    COUNT(DISTINCT material_code) as unique_materials,
    SUM(consumed_qty) as total_consumed
FROM public.tea_consumption_ledger;
""")
print(cur.fetchone())

print("\n=== MATERIALS STOCK OVERVIEW ===")
cur.execute("""
SELECT 
    COUNT(*) as total_materials,
    SUM(quantity) as total_admin_stock,
    COUNT(CASE WHEN quantity = 0 THEN 1 END) as zero_admin_stock,
    COUNT(CASE WHEN quantity > 0 THEN 1 END) as positive_admin_stock
FROM public.materials;
""")
print(cur.fetchone())

print("\n=== MATERIALS WITH TRANSFERS AND ADMIN STOCK ===")
cur.execute("""
WITH trf AS (
    SELECT 
        code,
        SUM(CASE WHEN UPPER(TRIM(COALESCE(department, ''))) = 'TEA' THEN (outward - return_units) ELSE 0 END) as tea_trf,
        SUM(CASE WHEN UPPER(TRIM(COALESCE(department, ''))) = 'CHOCOLATE' THEN (outward - return_units) ELSE 0 END) as choc_trf
    FROM public.transfers
    GROUP BY code
),
tea_c AS (
    SELECT 
        material_code,
        SUM(consumed_qty) as tea_consumed
    FROM public.tea_consumption_ledger
    GROUP BY material_code
)
SELECT 
    m.material_code,
    m.description,
    m.quantity as admin_stock,
    COALESCE(t.tea_trf, 0) as tea_net_trf,
    COALESCE(c.tea_consumed, 0) as tea_consumed,
    GREATEST(0, COALESCE(t.tea_trf, 0) - COALESCE(c.tea_consumed, 0)) as tea_available,
    COALESCE(t.choc_trf, 0) as choc_available,
    (m.quantity + GREATEST(0, COALESCE(t.tea_trf, 0) - COALESCE(c.tea_consumed, 0)) + COALESCE(t.choc_trf, 0)) as total_business_stock,
    m.reorder_level
FROM public.materials m
LEFT JOIN trf t ON t.code = m.material_code
LEFT JOIN tea_c c ON c.material_code = m.material_code
WHERE m.quantity > 0 OR COALESCE(t.tea_trf, 0) > 0 OR COALESCE(t.choc_trf, 0) > 0
ORDER BY total_business_stock DESC
LIMIT 15;
""")
print("Top materials by total business stock:")
for r in cur.fetchall():
    print(r)

conn.close()
