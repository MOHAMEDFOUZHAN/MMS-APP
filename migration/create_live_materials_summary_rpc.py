import os
import psycopg2

conn = psycopg2.connect(
    host='aws-0-ap-northeast-1.pooler.supabase.com',
    port=5432,
    user='postgres.japxiaxyabhhhclphbqr',
    password=os.environ["SUPABASE_DB_PASSWORD"],
    dbname='postgres',
    connect_timeout=15
)
conn.autocommit = True
cur = conn.cursor()

# Ensure expiry_date and grade columns exist on material_lots
cur.execute("ALTER TABLE material_lots ADD COLUMN IF NOT EXISTS expiry_date DATE;")
cur.execute("ALTER TABLE material_lots ADD COLUMN IF NOT EXISTS grade TEXT;")

rpc_sql = """
CREATE OR REPLACE FUNCTION get_live_materials_summary(
    p_search TEXT DEFAULT NULL,
    p_category TEXT DEFAULT NULL,
    p_grade TEXT DEFAULT NULL,
    p_status TEXT DEFAULT 'all',
    p_from_date DATE DEFAULT NULL,
    p_to_date DATE DEFAULT NULL,
    p_limit INT DEFAULT 100,
    p_offset INT DEFAULT 0
)
RETURNS TABLE (
    id BIGINT,
    material_code TEXT,
    description TEXT,
    category TEXT,
    grade TEXT,
    opening_stock NUMERIC,
    purchased NUMERIC,
    transfer_out NUMERIC,
    return_in NUMERIC,
    closing_stock NUMERIC,
    shelves_bin TEXT,
    reorder_level NUMERIC,
    unit TEXT,
    lot_count INT,
    earliest_expiry DATE
) 
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH locs AS (
        SELECT cl.category, cl.location FROM category_locations cl
    ),
    lots_summary AS (
        SELECT 
            ml.material_code,
            COUNT(*)::INT as lot_cnt,
            MIN(ml.expiry_date) as min_exp,
            STRING_AGG(DISTINCT ml.grade, ', ') FILTER (WHERE ml.grade IS NOT NULL AND ml.grade != '') as lot_grds
        FROM material_lots ml
        GROUP BY ml.material_code
    ),
    purchases AS (
        SELECT 
            ii.material as mat_code,
            COALESCE(SUM(ii.quantity), 0) as total_purchased
        FROM invoice_items ii
        JOIN invoices i ON i.id = ii.invoice_id
        WHERE (p_from_date IS NULL OR i.date >= p_from_date)
          AND (p_to_date IS NULL OR i.date <= p_to_date)
        GROUP BY ii.material
    ),
    transfers_summary AS (
        SELECT 
            t.code as mat_code,
            COALESCE(SUM(t.outward), 0) as total_out,
            COALESCE(SUM(t.return_units), 0) as total_ret
        FROM transfers t
        WHERE (p_from_date IS NULL OR t.date >= p_from_date)
          AND (p_to_date IS NULL OR t.date <= p_to_date)
        GROUP BY t.code
    )
    SELECT 
        m.id,
        m.material_code,
        m.description,
        COALESCE(m.category, 'General') as category,
        COALESCE(NULLIF(m.grade, ''), ls.lot_grds, '-') as grade,
        m.opening_stock,
        COALESCE(p.total_purchased, 0)::NUMERIC as purchased,
        COALESCE(ts.total_out, 0)::NUMERIC as transfer_out,
        COALESCE(ts.total_ret, 0)::NUMERIC as return_in,
        m.quantity as closing_stock,
        COALESCE(l.location, 'â€”') as shelves_bin,
        m.reorder_level,
        m.unit,
        COALESCE(ls.lot_cnt, CASE WHEN m.lot_no IS NOT NULL AND m.lot_no != '' THEN 1 ELSE 0 END)::INT as lot_count,
        COALESCE(ls.min_exp, m.expiry_date) as earliest_expiry
    FROM materials m
    LEFT JOIN locs l ON l.category = m.category
    LEFT JOIN lots_summary ls ON ls.material_code = m.material_code
    LEFT JOIN purchases p ON p.mat_code = m.material_code
    LEFT JOIN transfers_summary ts ON ts.mat_code = m.material_code
    WHERE (
        p_search IS NULL OR TRIM(p_search) = '' OR
        m.material_code ILIKE '%' || TRIM(p_search) || '%' OR
        m.description ILIKE '%' || TRIM(p_search) || '%' OR
        EXISTS (
            SELECT 1 FROM material_lots ml_s 
            WHERE ml_s.material_code = m.material_code 
              AND ml_s.lot_no ILIKE '%' || TRIM(p_search) || '%'
        )
    )
    AND (
        p_category IS NULL OR TRIM(p_category) = '' OR p_category = 'All' OR 
        m.category = TRIM(p_category)
    )
    AND (
        p_grade IS NULL OR TRIM(p_grade) = '' OR p_grade = 'All' OR 
        m.grade ILIKE TRIM(p_grade) OR 
        EXISTS (SELECT 1 FROM material_lots ml_g WHERE ml_g.material_code = m.material_code AND ml_g.grade ILIKE TRIM(p_grade))
    )
    AND (
        p_status IS NULL OR p_status = 'all' OR
        (p_status = 'reorder' AND m.quantity <= m.reorder_level AND m.quantity > 0) OR
        (p_status = 'out_of_stock' AND m.quantity <= 0.0001) OR
        (p_status = 'expiring' AND (
            (m.expiry_date IS NOT NULL AND m.expiry_date <= CURRENT_DATE + INTERVAL '30 days' AND m.expiry_date >= CURRENT_DATE) OR
            EXISTS (
                SELECT 1 FROM material_lots ml_e 
                WHERE ml_e.material_code = m.material_code 
                  AND ml_e.expiry_date IS NOT NULL 
                  AND ml_e.expiry_date <= CURRENT_DATE + INTERVAL '30 days' 
                  AND ml_e.expiry_date >= CURRENT_DATE
            )
        ))
    )
    ORDER BY m.material_code ASC
    LIMIT p_limit OFFSET p_offset;
END;
$$;
"""

cur.execute(rpc_sql)
print("get_live_materials_summary created successfully!")

# Test search by code
cur.execute("SELECT material_code, description, opening_stock, purchased, transfer_out, return_in, closing_stock, shelves_bin, lot_count FROM get_live_materials_summary(p_search => '100');")
print("\nSearch '100':")
for r in cur.fetchall():
    print(r)

# Test search by lot
cur.execute("SELECT material_code, description, opening_stock, purchased, transfer_out, return_in, closing_stock, shelves_bin, lot_count FROM get_live_materials_summary(p_search => 'BATCH-202610');")
print("\nSearch by lot 'BATCH-202610':")
for r in cur.fetchall():
    print(r)

conn.close()
