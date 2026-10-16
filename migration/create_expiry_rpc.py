import psycopg2

conn = psycopg2.connect(
    host='aws-0-ap-northeast-1.pooler.supabase.com',
    port=5432,
    user='postgres.japxiaxyabhhhclphbqr',
    password='mapleconnect2307',
    dbname='postgres'
)
cur = conn.cursor()

create_func = """
CREATE OR REPLACE FUNCTION public.get_owner_expiry_report(
    p_days_window integer DEFAULT NULL,
    p_search text DEFAULT NULL
)
RETURNS TABLE(
    material_code text,
    description text,
    batch_or_lot text,
    expiry_date date,
    quantity numeric,
    unit text,
    days_left integer,
    is_expired boolean
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $func$
BEGIN
    RETURN QUERY
    WITH combined_expiries AS (
        -- 1. Lots with individual expiry date
        SELECT 
            ml.material_code,
            COALESCE(m.description, ml.material_code) AS description,
            ml.lot_no AS batch_or_lot,
            ml.expiry_date,
            ml.available_quantity AS quantity,
            COALESCE(ml.uom, m.unit, 'kg') AS unit,
            (ml.expiry_date - CURRENT_DATE)::integer AS days_left,
            (ml.expiry_date < CURRENT_DATE) AS is_expired
        FROM public.material_lots ml
        LEFT JOIN public.materials m ON m.material_code = ml.material_code
        WHERE ml.expiry_date IS NOT NULL
          AND ml.available_quantity > 0.0001

        UNION ALL

        -- 2. Batches with individual expiry date
        SELECT
            b.material_code,
            COALESCE(b.description, b.material_code) AS description,
            b.batch_no AS batch_or_lot,
            b.expiry_date,
            b.available_quantity AS quantity,
            COALESCE(b.uom, 'kg') AS unit,
            (b.expiry_date - CURRENT_DATE)::integer AS days_left,
            (b.expiry_date < CURRENT_DATE) AS is_expired
        FROM public.batches b
        WHERE b.expiry_date IS NOT NULL
          AND b.available_quantity > 0.0001

        UNION ALL

        -- 3. Materials with expiry date (where not broken down by lots/batches)
        SELECT
            m.material_code,
            m.description,
            m.lot_no AS batch_or_lot,
            m.expiry_date,
            m.quantity AS quantity,
            COALESCE(m.unit, 'kg') AS unit,
            (m.expiry_date - CURRENT_DATE)::integer AS days_left,
            (m.expiry_date < CURRENT_DATE) AS is_expired
        FROM public.materials m
        WHERE m.expiry_date IS NOT NULL
          AND m.quantity > 0.0001
          AND m.material_code NOT IN (
              SELECT ml.material_code 
              FROM public.material_lots ml 
              WHERE ml.expiry_date IS NOT NULL 
                AND ml.available_quantity > 0.0001
          )
          AND m.material_code NOT IN (
              SELECT b.material_code 
              FROM public.batches b 
              WHERE b.expiry_date IS NOT NULL 
                AND b.available_quantity > 0.0001
          )
    )
    SELECT 
        ce.material_code,
        ce.description,
        ce.batch_or_lot,
        ce.expiry_date,
        ce.quantity,
        ce.unit,
        ce.days_left,
        ce.is_expired
    FROM combined_expiries ce
    WHERE (
        p_days_window IS NULL 
        OR ce.days_left <= p_days_window
    )
    AND (
        p_search IS NULL 
        OR TRIM(p_search) = '' 
        OR ce.material_code ILIKE '%' || TRIM(p_search) || '%'
        OR ce.description ILIKE '%' || TRIM(p_search) || '%'
        OR COALESCE(ce.batch_or_lot, '') ILIKE '%' || TRIM(p_search) || '%'
    )
    ORDER BY ce.expiry_date ASC, ce.days_left ASC, ce.material_code ASC;
END;
$func$;

GRANT EXECUTE ON FUNCTION public.get_owner_expiry_report(integer, text) TO authenticated, service_role, anon;
"""

cur.execute(create_func)
conn.commit()
print("RPC get_owner_expiry_report successfully deployed!")

cur.execute("SELECT COUNT(*) FROM public.get_owner_expiry_report(NULL, NULL);")
print("Total rows with expiry_date:", cur.fetchone()[0])

cur.execute("SELECT COUNT(*) FROM public.get_owner_expiry_report(360, NULL);")
print("Rows with days_left <= 360:", cur.fetchone()[0])

cur.execute("SELECT COUNT(*) FROM public.get_owner_expiry_report(30, NULL);")
print("Rows with days_left <= 30:", cur.fetchone()[0])

conn.close()
