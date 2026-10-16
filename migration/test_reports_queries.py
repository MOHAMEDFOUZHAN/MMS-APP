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

# Test check if target_stock column exists in materials
cur.execute("""
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'materials' AND column_name = 'target_stock';
""")
if not cur.fetchone():
    print("Column target_stock does not exist. We can safely add target_stock numeric(15, 3) DEFAULT NULL.")

test_sql = """
WITH trf_summary AS (
    SELECT 
        t.code,
        COALESCE(SUM(CASE WHEN UPPER(TRIM(COALESCE(t.department, ''))) = 'TEA' THEN (t.outward - t.return_units) ELSE 0 END), 0)::NUMERIC as tea_trf,
        COALESCE(SUM(CASE WHEN UPPER(TRIM(COALESCE(t.department, ''))) = 'CHOCOLATE' THEN (t.outward - t.return_units) ELSE 0 END), 0)::NUMERIC as choc_trf,
        COALESCE(SUM(CASE WHEN UPPER(TRIM(COALESCE(t.department, ''))) NOT IN ('TEA', 'CHOCOLATE') THEN (t.outward - t.return_units) ELSE 0 END), 0)::NUMERIC as other_trf,
        COALESCE(SUM(t.outward - t.return_units), 0)::NUMERIC as tot_trf,
        MAX(COALESCE(t.created_at, t.date::timestamp with time zone)) as max_trf_at
    FROM public.transfers t
    GROUP BY t.code
),
tea_consumed_summary AS (
    SELECT 
        c.material_code as code,
        COALESCE(SUM(c.consumed_qty), 0)::NUMERIC as tea_consumed,
        MAX(COALESCE(c.created_at, c.date::timestamp with time zone)) as max_consumption_at
    FROM public.tea_consumption_ledger c
    GROUP BY c.material_code
),
inv_summary AS (
    SELECT 
        ii.material as code,
        MAX(COALESCE(i.created_at, i.date::timestamp with time zone)) as max_inv_at
    FROM public.invoice_items ii
    JOIN public.invoices i ON i.id = ii.invoice_id
    GROUP BY ii.material
),
material_stocks AS (
    SELECT 
        m.id,
        m.material_code,
        m.description,
        COALESCE(m.category, 'General') as category,
        COALESCE(m.unit, 'kg') as unit,
        ROUND(COALESCE(m.quantity, 0)::NUMERIC, 3) as admin_stock,
        ROUND(GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0))::NUMERIC, 3) as tea_stock,
        ROUND(COALESCE(ts.choc_trf, 0)::NUMERIC, 3) as chocolate_stock,
        ROUND(COALESCE(ts.other_trf, 0)::NUMERIC, 3) as other_stock,
        ROUND((COALESCE(m.quantity, 0) + GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0)) + COALESCE(ts.choc_trf, 0) + COALESCE(ts.other_trf, 0))::NUMERIC, 3) as total_business_stock,
        COALESCE(m.reorder_level, 0)::NUMERIC as reorder_level,
        GREATEST(m.last_updated, ts.max_trf_at, tc.max_consumption_at, invs.max_inv_at) as last_transaction_at
    FROM public.materials m
    LEFT JOIN trf_summary ts ON ts.code = m.material_code
    LEFT JOIN tea_consumed_summary tc ON tc.code = m.material_code
    LEFT JOIN inv_summary invs ON invs.code = m.material_code
)
SELECT * FROM material_stocks
WHERE total_business_stock <= 0.0001
LIMIT 5;
"""

cur.execute(test_sql)
print("\nSample query execution successful! Out of stock items:")
for r in cur.fetchall():
    print(r)

conn.close()
