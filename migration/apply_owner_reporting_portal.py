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

    print("1. Creating prevent_owner_operational_writes trigger function...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.prevent_owner_operational_writes()
    RETURNS TRIGGER
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
    AS $$
    BEGIN
        IF public.is_owner() THEN
            RAISE EXCEPTION 'Access Denied: Owner executive role has read-only privileges. Operational records cannot be created, modified, or deleted.' USING ERRCODE = '42501';
        END IF;
        RETURN COALESCE(NEW, OLD);
    END;
    $$;
    """)

    tables = [
        'materials',
        'invoices',
        'invoice_items',
        'transfers',
        'dispatches',
        'dispatch_batches',
        'batches',
        'tea_consumption_ledger',
        'stock_adjustments'
    ]

    print("2. Attaching trg_prevent_owner_writes triggers to operational tables...")
    for t in tables:
        cur.execute(f"DROP TRIGGER IF EXISTS trg_prevent_owner_writes ON public.{t};")
        cur.execute(f"""
        CREATE TRIGGER trg_prevent_owner_writes
        BEFORE INSERT OR UPDATE OR DELETE ON public.{t}
        FOR EACH ROW
        EXECUTE FUNCTION public.prevent_owner_operational_writes();
        """)
        print(f"   Attached trigger to {t}")

    print("3. Updating owner permissions in user_profiles to strictly read-only...")
    cur.execute("""
    UPDATE public.user_profiles
    SET permissions = ARRAY[
        'owner.*',
        'reports.*',
        'materials.view',
        'invoice.view',
        'transfer.view',
        'dispatch.view',
        'storage.view',
        'batches.view',
        'consumption.view',
        'ocr.view'
    ],
    updated_at = NOW()
    WHERE role = 'OWNER' OR username = 'owner';
    """)

    print("4. Creating RPC get_owner_admin_live_stock...")
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
            ROUND(COALESCE(ts.tea_trf, 0)::NUMERIC, 3) as tea_stock,
            ROUND(COALESCE(ts.choc_trf, 0)::NUMERIC, 3) as chocolate_stock,
            ROUND(COALESCE(ts.other_trf, 0)::NUMERIC, 3) as other_stock,
            ROUND(COALESCE(ts.tot_trf, 0)::NUMERIC, 3) as total_transferred,
            ROUND((COALESCE(m.quantity, 0) + COALESCE(ts.tot_trf, 0))::NUMERIC, 3) as total_system_stock,
            GREATEST(m.last_updated, ts.max_trf_at, invs.max_inv_at) as last_transaction_at
        FROM public.materials m
        LEFT JOIN trf_summary ts ON ts.code = m.material_code
        LEFT JOIN inv_summary invs ON invs.code = m.material_code
        WHERE (
            p_search IS NULL OR TRIM(p_search) = '' OR
            m.material_code ILIKE '%' || TRIM(p_search) || '%' OR
            m.description ILIKE '%' || TRIM(p_search) || '%' OR
            m.category ILIKE '%' || TRIM(p_search) || '%'
        )
        ORDER BY 
            (COALESCE(m.quantity, 0) + COALESCE(ts.tot_trf, 0)) DESC,
            m.material_code ASC;
    END;
    $$;
    """)

    print("5. Creating RPC get_chocolate_material_received_ledger...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.get_chocolate_material_received_ledger(
        p_search text DEFAULT NULL::text, 
        p_category text DEFAULT NULL::text
    )
    RETURNS TABLE(
        material_code text, 
        description text, 
        category text, 
        unit text, 
        total_received numeric, 
        total_accounted numeric, 
        current_balance numeric, 
        latest_activity timestamp with time zone, 
        status text, 
        transfer_count integer
    )
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
    AS $$
    BEGIN
        RETURN QUERY
        WITH choc_trf AS (
            SELECT 
                t.code,
                COALESCE(MAX(m.description), MAX(t.description), t.code) as mat_desc,
                COALESCE(MAX(m.category), MAX(t.category), 'CHOCOLATE') as mat_cat,
                COALESCE(MAX(m.unit), MAX(t.units), 'kg') as mat_unit,
                COALESCE(SUM(t.outward), 0)::NUMERIC as sum_rcvd,
                COALESCE(SUM(t.return_units), 0)::NUMERIC as sum_ret,
                MAX(COALESCE(t.created_at, t.date::timestamp with time zone)) as max_trf_at,
                COUNT(CASE WHEN t.outward > 0 THEN 1 END)::INT as trf_cnt
            FROM public.transfers t
            LEFT JOIN public.materials m ON m.material_code = t.code
            WHERE UPPER(TRIM(COALESCE(t.department, ''))) = 'CHOCOLATE'
            GROUP BY t.code
            HAVING COALESCE(SUM(t.outward), 0) > 0
        )
        SELECT 
            trf.code AS material_code,
            trf.mat_desc AS description,
            trf.mat_cat AS category,
            trf.mat_unit AS unit,
            ROUND(trf.sum_rcvd, 3) AS total_received,
            ROUND(trf.sum_ret, 3) AS total_accounted,
            ROUND((trf.sum_rcvd - trf.sum_ret), 3) AS current_balance,
            trf.max_trf_at AS latest_activity,
            CASE 
                WHEN (trf.sum_rcvd - trf.sum_ret) > 0.0001 THEN 'IN_STOCK'
                ELSE 'ZERO_BALANCE'
            END AS status,
            trf.trf_cnt AS transfer_count
        FROM choc_trf trf
        WHERE (
            p_search IS NULL OR TRIM(p_search) = '' OR
            trf.code ILIKE '%' || TRIM(p_search) || '%' OR
            trf.mat_desc ILIKE '%' || TRIM(p_search) || '%'
        )
        AND (
            p_category IS NULL OR TRIM(p_category) = '' OR TRIM(p_category) = 'All' OR
            trf.mat_cat = TRIM(p_category)
        )
        ORDER BY 
            CASE WHEN (trf.sum_rcvd - trf.sum_ret) > 0.0001 THEN 0 ELSE 1 END,
            trf.mat_desc ASC;
    END;
    $$;
    """)

    print("6. Testing get_owner_admin_live_stock RPC...")
    cur.execute("SELECT count(*) FROM public.get_owner_admin_live_stock();")
    print(f"   Admin live stock count: {cur.fetchone()[0]}")

    print("7. Testing get_chocolate_material_received_ledger RPC...")
    cur.execute("SELECT count(*) FROM public.get_chocolate_material_received_ledger();")
    print(f"   Chocolate live materials count: {cur.fetchone()[0]}")

    print("8. Testing get_tea_material_received_ledger RPC...")
    cur.execute("SELECT count(*) FROM public.get_tea_material_received_ledger();")
    print(f"   Tea live materials count: {cur.fetchone()[0]}")

    cur.close()
    conn.close()
    print("Migration completed successfully!")

if __name__ == '__main__':
    main()
