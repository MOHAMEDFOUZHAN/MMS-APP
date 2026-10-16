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
SELECT 
    COUNT(*) as total_materials,
    COUNT(CASE WHEN quantity <= 0 THEN 1 END) as zero_or_negative_stock,
    COUNT(CASE WHEN reorder_level > 0 THEN 1 END) as configured_reorder_level,
    COUNT(CASE WHEN reorder_level > 0 AND quantity <= reorder_level THEN 1 END) as below_reorder_level
FROM public.materials;
""")
print("Materials summary:", cur.fetchone())

cur.execute("""
SELECT material_code, description, category, quantity, reorder_level, unit
FROM public.materials
WHERE reorder_level > 0
LIMIT 10;
""")
print("\nMaterials with reorder_level > 0:")
for r in cur.fetchall():
    print(r)

cur.execute("""
SELECT material_code, description, category, quantity, reorder_level, unit
FROM public.materials
WHERE quantity <= 0
LIMIT 10;
""")
print("\nMaterials with quantity <= 0:")
for r in cur.fetchall():
    print(r)

conn.close()
