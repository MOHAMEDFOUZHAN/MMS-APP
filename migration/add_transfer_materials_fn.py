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

print("Creating get_transfer_available_materials function...")
cur.execute("""
    CREATE OR REPLACE FUNCTION public.get_transfer_available_materials()
    RETURNS SETOF public.materials
    LANGUAGE sql
    STABLE
    AS $$
        SELECT DISTINCT m.*
        FROM public.materials m
        JOIN public.material_lots ml ON ml.material_code = m.material_code
        WHERE ml.available_quantity > 0 AND m.quantity > 0
        ORDER BY m.material_code ASC;
    $$;
    GRANT EXECUTE ON FUNCTION public.get_transfer_available_materials() TO anon, authenticated, service_role;
""")

print("Testing get_transfer_available_materials...")
cur.execute("SELECT material_code, description, quantity FROM get_transfer_available_materials();")
rows = cur.fetchall()
print(f"Found {len(rows)} materials with active lot stock:")
for r in rows[:5]:
    print(r)

conn.close()
