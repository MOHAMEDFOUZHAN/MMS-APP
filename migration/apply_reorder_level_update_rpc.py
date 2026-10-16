import os
import psycopg2

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = os.environ.get("SUPABASE_DB_PASSWORD", "mapleconnect2307")
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
conn.autocommit = True
cur = conn.cursor()

print("1. Creating update_material_reorder_level RPC...")
cur.execute("""
CREATE OR REPLACE FUNCTION public.update_material_reorder_level(
    p_material_code text,
    p_reorder_level numeric
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_clean_code text;
    v_clean_level numeric;
BEGIN
    v_clean_code := TRIM(COALESCE(p_material_code, ''));
    v_clean_level := GREATEST(0, COALESCE(p_reorder_level, 0));

    IF v_clean_code = '' THEN
        RAISE EXCEPTION 'Material code cannot be empty';
    END IF;

    UPDATE public.materials
    SET 
        reorder_level = v_clean_level,
        last_updated = CURRENT_TIMESTAMP
    WHERE UPPER(TRIM(material_code)) = UPPER(v_clean_code);

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Material with code % not found', v_clean_code;
    END IF;

    RETURN true;
END;
$$;
GRANT EXECUTE ON FUNCTION public.update_material_reorder_level(text, numeric) TO authenticated, anon;
""")
print("RPC created successfully!")

# Test RPC with a transaction and rollback
conn.autocommit = False
cur.execute("SELECT material_code, reorder_level, quantity FROM materials LIMIT 1;")
test_mat = cur.fetchone()
print("Test material before:", test_mat)

cur.execute("SELECT public.update_material_reorder_level(%s, %s);", (test_mat[0], 99.5))
res = cur.fetchone()[0]
print("RPC call result:", res)

cur.execute("SELECT material_code, reorder_level, quantity FROM materials WHERE material_code = %s;", (test_mat[0],))
after = cur.fetchone()
print("Test material after (in tx):", after)
assert float(after[1]) == 99.5, "Reorder level did not update"
assert after[2] == test_mat[2], "Stock quantity was modified! Safety failure!"

conn.rollback()
print("Transaction rolled back cleanly. Production data unchanged.")

cur.close()
conn.close()
