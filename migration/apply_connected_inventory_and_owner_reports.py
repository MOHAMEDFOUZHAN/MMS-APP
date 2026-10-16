import os
import psycopg2

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = os.environ.get("SUPABASE_DB_PASSWORD", "mapleconnect2307")
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

def main():
    print("Connecting to Supabase PostgreSQL...")
    conn = psycopg2.connect(
        host=HOST,
        port=PORT,
        user=USER,
        password=PASSWORD,
        dbname=DBNAME,
        connect_timeout=15
    )
    conn.autocommit = True
    cur = conn.cursor()

    print("1. Adding target_stock column to materials if not exists...")
    cur.execute("""
    ALTER TABLE public.materials 
    ADD COLUMN IF NOT EXISTS target_stock NUMERIC(15, 3) DEFAULT NULL;
    """)
    print("   Column target_stock verified.")

    print("2. Updating get_owner_admin_live_stock to unify tea consumption accounting...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.get_owner_admin_live_stock(p_search text DEFAULT NULL::text)
    RETURNS TABLE(
        material_code text,
        description text,
        category text,
        unit text,
        admin_stock numeric,
        tea_stock numeric,
        chocolate_stock numeric,
        other_stock numeric,
        total_transferred numeric,
        total_system_stock numeric,
        last_transaction_at timestamp with time zone
    )
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
    AS $$
    BEGIN
        RETURN QUERY
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
        )
        SELECT 
            m.material_code,
            m.description,
            COALESCE(m.category, 'General') as category,
            COALESCE(m.unit, 'kg') as unit,
            ROUND(COALESCE(m.quantity, 0)::NUMERIC, 3) as admin_stock,
            ROUND(GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0))::NUMERIC, 3) as tea_stock,
            ROUND(COALESCE(ts.choc_trf, 0)::NUMERIC, 3) as chocolate_stock,
            ROUND(COALESCE(ts.other_trf, 0)::NUMERIC, 3) as other_stock,
            ROUND((GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0)) + COALESCE(ts.choc_trf, 0) + COALESCE(ts.other_trf, 0))::NUMERIC, 3) as total_transferred,
            ROUND((COALESCE(m.quantity, 0) + GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0)) + COALESCE(ts.choc_trf, 0) + COALESCE(ts.other_trf, 0))::NUMERIC, 3) as total_system_stock,
            GREATEST(m.last_updated, ts.max_trf_at, tc.max_consumption_at, invs.max_inv_at) as last_transaction_at
        FROM public.materials m
        LEFT JOIN trf_summary ts ON ts.code = m.material_code
        LEFT JOIN tea_consumed_summary tc ON tc.code = m.material_code
        LEFT JOIN inv_summary invs ON invs.code = m.material_code
        WHERE (
            p_search IS NULL OR TRIM(p_search) = '' OR
            m.material_code ILIKE '%' || TRIM(p_search) || '%' OR
            m.description ILIKE '%' || TRIM(p_search) || '%' OR
            m.category ILIKE '%' || TRIM(p_search) || '%'
        )
        ORDER BY 
            (COALESCE(m.quantity, 0) + GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0)) + COALESCE(ts.choc_trf, 0) + COALESCE(ts.other_trf, 0)) DESC,
            m.material_code ASC;
    END;
    $$;
    """)
    print("   Updated get_owner_admin_live_stock.")

    print("3. Creating RPC get_owner_out_of_stock_report...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.get_owner_out_of_stock_report(
        p_department text DEFAULT NULL::text,
        p_search text DEFAULT NULL::text
    )
    RETURNS TABLE(
        material_code text,
        description text,
        category text,
        unit text,
        location text,
        location_stock numeric,
        admin_stock numeric,
        tea_stock numeric,
        chocolate_stock numeric,
        total_business_stock numeric,
        reorder_level numeric,
        last_transaction_at timestamp with time zone,
        stock_status text,
        status_message text
    )
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
    AS $$
    DECLARE
        v_dept text;
    BEGIN
        v_dept := UPPER(TRIM(COALESCE(p_department, 'ALL')));

        RETURN QUERY
        WITH trf_summary AS (
            SELECT 
                t.code,
                COALESCE(SUM(CASE WHEN UPPER(TRIM(COALESCE(t.department, ''))) = 'TEA' THEN (t.outward - t.return_units) ELSE 0 END), 0)::NUMERIC as tea_trf,
                COALESCE(SUM(CASE WHEN UPPER(TRIM(COALESCE(t.department, ''))) = 'CHOCOLATE' THEN (t.outward - t.return_units) ELSE 0 END), 0)::NUMERIC as choc_trf,
                COALESCE(SUM(CASE WHEN UPPER(TRIM(COALESCE(t.department, ''))) NOT IN ('TEA', 'CHOCOLATE') THEN (t.outward - t.return_units) ELSE 0 END), 0)::NUMERIC as other_trf,
                MAX(COALESCE(t.created_at, t.date::timestamp with time zone)) as max_trf_at,
                COUNT(CASE WHEN UPPER(TRIM(COALESCE(t.department, ''))) = 'TEA' THEN 1 END) as tea_trf_count,
                COUNT(CASE WHEN UPPER(TRIM(COALESCE(t.department, ''))) = 'CHOCOLATE' THEN 1 END) as choc_trf_count
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
        base_stocks AS (
            SELECT 
                m.material_code,
                m.description,
                COALESCE(m.category, 'General') as category,
                COALESCE(m.unit, 'kg') as unit,
                ROUND(COALESCE(m.quantity, 0)::NUMERIC, 3) as adm_stock,
                ROUND(GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0))::NUMERIC, 3) as t_stock,
                ROUND(COALESCE(ts.choc_trf, 0)::NUMERIC, 3) as c_stock,
                ROUND(COALESCE(ts.other_trf, 0)::NUMERIC, 3) as o_stock,
                ROUND((COALESCE(m.quantity, 0) + GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0)) + COALESCE(ts.choc_trf, 0) + COALESCE(ts.other_trf, 0))::NUMERIC, 3) as tot_stock,
                COALESCE(m.reorder_level, 0)::NUMERIC as r_level,
                GREATEST(m.last_updated, ts.max_trf_at, tc.max_consumption_at, invs.max_inv_at) as last_tx,
                COALESCE(ts.tea_trf_count, 0) as tea_count,
                COALESCE(ts.choc_trf_count, 0) as choc_count
            FROM public.materials m
            LEFT JOIN trf_summary ts ON ts.code = m.material_code
            LEFT JOIN tea_consumed_summary tc ON tc.code = m.material_code
            LEFT JOIN inv_summary invs ON invs.code = m.material_code
        )
        SELECT 
            b.material_code,
            b.description,
            b.category,
            b.unit,
            CASE 
                WHEN v_dept = 'ADMIN' THEN 'Admin Warehouse'
                WHEN v_dept = 'TEA' THEN 'Tea Department'
                WHEN v_dept = 'CHOCOLATE' THEN 'Chocolate Department'
                ELSE 'Business-Wide'
            END AS location,
            CASE 
                WHEN v_dept = 'ADMIN' THEN b.adm_stock
                WHEN v_dept = 'TEA' THEN b.t_stock
                WHEN v_dept = 'CHOCOLATE' THEN b.c_stock
                ELSE b.tot_stock
            END AS location_stock,
            b.adm_stock AS admin_stock,
            b.t_stock AS tea_stock,
            b.c_stock AS chocolate_stock,
            b.tot_stock AS total_business_stock,
            b.r_level AS reorder_level,
            b.last_tx AS last_transaction_at,
            CASE 
                WHEN b.tot_stock <= 0.0001 THEN 'OUT_OF_STOCK_BUSINESS'
                WHEN (
                    (v_dept = 'ADMIN' AND b.adm_stock <= 0.0001) OR
                    (v_dept = 'TEA' AND b.t_stock <= 0.0001) OR
                    (v_dept = 'CHOCOLATE' AND b.c_stock <= 0.0001)
                ) THEN 'OUT_OF_STOCK_LOCATION'
                ELSE 'IN_STOCK'
            END AS stock_status,
            CASE 
                WHEN b.tot_stock <= 0.0001 THEN 'Out of Stock Across Business (0 in all departments)'
                WHEN v_dept = 'ADMIN' AND b.adm_stock <= 0.0001 THEN 
                    'Depleted in Admin | Available in: ' || 
                    TRIM(BOTH ' , ' FROM 
                        (CASE WHEN b.t_stock > 0 THEN b.t_stock || ' ' || b.unit || ' in Tea, ' ELSE '' END) ||
                        (CASE WHEN b.c_stock > 0 THEN b.c_stock || ' ' || b.unit || ' in Chocolate' ELSE '' END)
                    )
                WHEN v_dept = 'TEA' AND b.t_stock <= 0.0001 THEN
                    'Depleted in Tea | Available in: ' ||
                    TRIM(BOTH ' , ' FROM 
                        (CASE WHEN b.adm_stock > 0 THEN b.adm_stock || ' ' || b.unit || ' in Admin, ' ELSE '' END) ||
                        (CASE WHEN b.c_stock > 0 THEN b.c_stock || ' ' || b.unit || ' in Chocolate' ELSE '' END)
                    )
                WHEN v_dept = 'CHOCOLATE' AND b.c_stock <= 0.0001 THEN
                    'Depleted in Chocolate | Available in: ' ||
                    TRIM(BOTH ' , ' FROM 
                        (CASE WHEN b.adm_stock > 0 THEN b.adm_stock || ' ' || b.unit || ' in Admin, ' ELSE '' END) ||
                        (CASE WHEN b.t_stock > 0 THEN b.t_stock || ' ' || b.unit || ' in Tea' ELSE '' END)
                    )
                ELSE 'In Stock (' || b.tot_stock || ' ' || b.unit || ' total)'
            END AS status_message
        FROM base_stocks b
        WHERE (
            -- Department stock filter condition
            (v_dept = 'ALL' AND b.tot_stock <= 0.0001) OR
            (v_dept = 'ADMIN' AND b.adm_stock <= 0.0001) OR
            (v_dept = 'TEA' AND b.tea_count > 0 AND b.t_stock <= 0.0001) OR
            (v_dept = 'CHOCOLATE' AND b.choc_count > 0 AND b.c_stock <= 0.0001)
        )
        AND (
            p_search IS NULL OR TRIM(p_search) = '' OR
            b.material_code ILIKE '%' || TRIM(p_search) || '%' OR
            b.description ILIKE '%' || TRIM(p_search) || '%' OR
            b.category ILIKE '%' || TRIM(p_search) || '%'
        )
        ORDER BY b.material_code ASC;
    END;
    $$;
    """)
    print("   Created get_owner_out_of_stock_report.")

    print("4. Creating RPC get_owner_reorder_report...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.get_owner_reorder_report(
        p_department text DEFAULT NULL::text,
        p_search text DEFAULT NULL::text,
        p_status text DEFAULT NULL::text
    )
    RETURNS TABLE(
        material_code text,
        description text,
        category text,
        unit text,
        location text,
        available_stock numeric,
        total_business_stock numeric,
        admin_stock numeric,
        tea_stock numeric,
        chocolate_stock numeric,
        reorder_level numeric,
        target_stock numeric,
        suggested_replenishment numeric,
        status text,
        status_message text,
        last_updated timestamp with time zone
    )
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
    AS $$
    DECLARE
        v_dept text;
        v_filter_status text;
    BEGIN
        v_dept := UPPER(TRIM(COALESCE(p_department, 'ALL')));
        v_filter_status := UPPER(TRIM(COALESCE(p_status, 'ALL')));

        RETURN QUERY
        WITH trf_summary AS (
            SELECT 
                t.code,
                COALESCE(SUM(CASE WHEN UPPER(TRIM(COALESCE(t.department, ''))) = 'TEA' THEN (t.outward - t.return_units) ELSE 0 END), 0)::NUMERIC as tea_trf,
                COALESCE(SUM(CASE WHEN UPPER(TRIM(COALESCE(t.department, ''))) = 'CHOCOLATE' THEN (t.outward - t.return_units) ELSE 0 END), 0)::NUMERIC as choc_trf,
                COALESCE(SUM(CASE WHEN UPPER(TRIM(COALESCE(t.department, ''))) NOT IN ('TEA', 'CHOCOLATE') THEN (t.outward - t.return_units) ELSE 0 END), 0)::NUMERIC as other_trf,
                MAX(COALESCE(t.created_at, t.date::timestamp with time zone)) as max_trf_at,
                COUNT(CASE WHEN UPPER(TRIM(COALESCE(t.department, ''))) = 'TEA' THEN 1 END) as tea_trf_count,
                COUNT(CASE WHEN UPPER(TRIM(COALESCE(t.department, ''))) = 'CHOCOLATE' THEN 1 END) as choc_trf_count
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
        base_stocks AS (
            SELECT 
                m.material_code,
                m.description,
                COALESCE(m.category, 'General') as category,
                COALESCE(m.unit, 'kg') as unit,
                ROUND(COALESCE(m.quantity, 0)::NUMERIC, 3) as adm_stock,
                ROUND(GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0))::NUMERIC, 3) as t_stock,
                ROUND(COALESCE(ts.choc_trf, 0)::NUMERIC, 3) as c_stock,
                ROUND(COALESCE(ts.other_trf, 0)::NUMERIC, 3) as o_stock,
                ROUND((COALESCE(m.quantity, 0) + GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0)) + COALESCE(ts.choc_trf, 0) + COALESCE(ts.other_trf, 0))::NUMERIC, 3) as tot_stock,
                ROUND(COALESCE(m.reorder_level, 0)::NUMERIC, 3) as r_level,
                m.target_stock as t_stock_target,
                GREATEST(m.last_updated, ts.max_trf_at, tc.max_consumption_at, invs.max_inv_at) as last_tx,
                COALESCE(ts.tea_trf_count, 0) as tea_count,
                COALESCE(ts.choc_trf_count, 0) as choc_count
            FROM public.materials m
            LEFT JOIN trf_summary ts ON ts.code = m.material_code
            LEFT JOIN tea_consumed_summary tc ON tc.code = m.material_code
            LEFT JOIN inv_summary invs ON invs.code = m.material_code
        ),
        evaluated_reorder AS (
            SELECT 
                b.material_code,
                b.description,
                b.category,
                b.unit,
                CASE 
                    WHEN v_dept = 'ADMIN' THEN 'Admin Warehouse'
                    WHEN v_dept = 'TEA' THEN 'Tea Department'
                    WHEN v_dept = 'CHOCOLATE' THEN 'Chocolate Department'
                    ELSE 'Business-Wide'
                END AS location,
                CASE 
                    WHEN v_dept = 'ADMIN' THEN b.adm_stock
                    WHEN v_dept = 'TEA' THEN b.t_stock
                    WHEN v_dept = 'CHOCOLATE' THEN b.c_stock
                    ELSE b.tot_stock
                END AS available_stock,
                b.tot_stock AS total_business_stock,
                b.adm_stock AS admin_stock,
                b.t_stock AS tea_stock,
                b.c_stock AS chocolate_stock,
                b.r_level AS reorder_level,
                b.t_stock_target AS target_stock,
                CASE 
                    WHEN b.t_stock_target IS NOT NULL AND b.t_stock_target > 0 THEN
                        ROUND(GREATEST(0, b.t_stock_target - (
                            CASE 
                                WHEN v_dept = 'ADMIN' THEN b.adm_stock
                                WHEN v_dept = 'TEA' THEN b.t_stock
                                WHEN v_dept = 'CHOCOLATE' THEN b.c_stock
                                ELSE b.tot_stock
                            END
                        ))::NUMERIC, 3)
                    ELSE NULL
                END AS suggested_replenishment,
                CASE 
                    WHEN b.r_level <= 0 THEN 'NOT_CONFIGURED'
                    WHEN (
                        CASE 
                            WHEN v_dept = 'ADMIN' THEN b.adm_stock
                            WHEN v_dept = 'TEA' THEN b.t_stock
                            WHEN v_dept = 'CHOCOLATE' THEN b.c_stock
                            ELSE b.tot_stock
                        END
                    ) <= b.r_level THEN 'REORDER_REQUIRED'
                    ELSE 'NORMAL'
                END AS status,
                CASE 
                    WHEN b.r_level <= 0 THEN 'Reorder Level Not Configured'
                    WHEN (
                        CASE 
                            WHEN v_dept = 'ADMIN' THEN b.adm_stock
                            WHEN v_dept = 'TEA' THEN b.t_stock
                            WHEN v_dept = 'CHOCOLATE' THEN b.c_stock
                            ELSE b.tot_stock
                        END
                    ) <= b.r_level THEN 'Reorder Required (Stock <= ' || b.r_level || ' ' || b.unit || ')'
                    ELSE 'Normal Stock Level'
                END AS status_message,
                b.last_tx AS last_updated,
                b.tea_count,
                b.choc_count
            FROM base_stocks b
        )
        SELECT 
            er.material_code,
            er.description,
            er.category,
            er.unit,
            er.location,
            er.available_stock,
            er.total_business_stock,
            er.admin_stock,
            er.tea_stock,
            er.chocolate_stock,
            er.reorder_level,
            er.target_stock,
            er.suggested_replenishment,
            er.status,
            er.status_message,
            er.last_updated
        FROM evaluated_reorder er
        WHERE (
            -- Department relevance filter
            v_dept = 'ALL' OR
            v_dept = 'ADMIN' OR
            (v_dept = 'TEA' AND er.tea_count > 0) OR
            (v_dept = 'CHOCOLATE' AND er.choc_count > 0)
        )
        AND (
            -- Status filter
            v_filter_status = 'ALL' OR
            (v_filter_status = 'REORDER_REQUIRED' AND er.status = 'REORDER_REQUIRED') OR
            (v_filter_status = 'NORMAL' AND er.status = 'NORMAL') OR
            (v_filter_status = 'NOT_CONFIGURED' AND er.status = 'NOT_CONFIGURED')
        )
        AND (
            p_search IS NULL OR TRIM(p_search) = '' OR
            er.material_code ILIKE '%' || TRIM(p_search) || '%' OR
            er.description ILIKE '%' || TRIM(p_search) || '%' OR
            er.category ILIKE '%' || TRIM(p_search) || '%'
        )
        ORDER BY 
            CASE WHEN er.status = 'REORDER_REQUIRED' THEN 1 WHEN er.status = 'NORMAL' THEN 2 ELSE 3 END ASC,
            (er.reorder_level - er.available_stock) DESC,
            er.material_code ASC;
    END;
    $$;
    """)
    print("   Created get_owner_reorder_report.")

    print("5. Testing both new RPCs...")
    cur.execute("SELECT count(*) FROM public.get_owner_out_of_stock_report('ALL');")
    print(f"   get_owner_out_of_stock_report('ALL') returned {cur.fetchone()[0]} rows.")
    
    cur.execute("SELECT count(*) FROM public.get_owner_out_of_stock_report('ADMIN');")
    print(f"   get_owner_out_of_stock_report('ADMIN') returned {cur.fetchone()[0]} rows.")

    cur.execute("SELECT count(*) FROM public.get_owner_reorder_report('ALL', NULL, 'REORDER_REQUIRED');")
    print(f"   get_owner_reorder_report('ALL', NULL, 'REORDER_REQUIRED') returned {cur.fetchone()[0]} rows.")

    cur.execute("SELECT count(*) FROM public.get_owner_reorder_report('ALL', NULL, 'ALL');")
    print(f"   get_owner_reorder_report('ALL', NULL, 'ALL') returned {cur.fetchone()[0]} rows.")

    conn.close()
    print("Migration finished successfully!")

if __name__ == '__main__':
    main()
