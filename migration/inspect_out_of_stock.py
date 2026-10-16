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

cur.execute("""
WITH trf AS (
    SELECT 
        code,
        SUM(CASE WHEN UPPER(TRIM(COALESCE(department, ''))) = 'TEA' THEN (outward - return_units) ELSE 0 END) as tea_trf,
        SUM(CASE WHEN UPPER(TRIM(COALESCE(department, ''))) = 'CHOCOLATE' THEN (outward - return_units) ELSE 0 END) as choc_trf,
        SUM(CASE WHEN UPPER(TRIM(COALESCE(department, ''))) NOT IN ('TEA', 'CHOCOLATE') THEN (outward - return_units) ELSE 0 END) as other_trf
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
    m.category,
    m.unit,
    m.quantity as admin_stock,
    GREATEST(0, COALESCE(t.tea_trf, 0) - COALESCE(c.tea_consumed, 0)) as tea_available,
    COALESCE(t.choc_trf, 0) as choc_available,
    COALESCE(t.other_trf, 0) as other_dept,
    (m.quantity + GREATEST(0, COALESCE(t.tea_trf, 0) - COALESCE(c.tea_consumed, 0)) + COALESCE(t.choc_trf, 0) + COALESCE(t.other_trf, 0)) as total_business_stock,
    m.reorder_level,
    m.last_updated
FROM public.materials m
LEFT JOIN trf t ON t.code = m.material_code
LEFT JOIN tea_c c ON c.material_code = m.material_code
WHERE (m.quantity + GREATEST(0, COALESCE(t.tea_trf, 0) - COALESCE(c.tea_consumed, 0)) + COALESCE(t.choc_trf, 0) + COALESCE(t.other_trf, 0)) <= 0.0001
ORDER BY m.material_code ASC;
""")
res = cur.fetchall()
print(f"Total materials out of stock business-wide: {len(res)}")
print("\nFirst 10 completely out of stock materials:")
for r in res[:10]:
    print(r)

conn.close()
