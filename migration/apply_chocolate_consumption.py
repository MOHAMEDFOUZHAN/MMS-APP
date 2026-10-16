import psycopg2
import sys

def apply_chocolate_consumption_migration():
    print("=== Starting Chocolate Consumption Migration ===")
    conn = psycopg2.connect(
        host='aws-0-ap-northeast-1.pooler.supabase.com',
        port=5432,
        user='postgres.japxiaxyabhhhclphbqr',
        password='mapleconnect2307',
        dbname='postgres',
        connect_timeout=15
    )
    conn.autocommit = True
    cur = conn.cursor()

    # 1. Create table chocolate_consumption_ledger
    print("1. Creating public.chocolate_consumption_ledger table...")
    cur.execute("""
    CREATE TABLE IF NOT EXISTS public.chocolate_consumption_ledger (
        id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
        date DATE NOT NULL DEFAULT CURRENT_DATE,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        material_code TEXT NOT NULL,
        description TEXT NOT NULL,
        category TEXT DEFAULT 'CHOCOLATE',
        department TEXT DEFAULT 'CHOCOLATE',
        unit TEXT DEFAULT 'kg',
        taken_qty NUMERIC(14, 3) NOT NULL DEFAULT 0.000,
        balance_qty NUMERIC(14, 3) NOT NULL DEFAULT 0.000,
        consumed_qty NUMERIC(14, 3) NOT NULL DEFAULT 0.000,
        operator_name TEXT DEFAULT '',
        shift TEXT DEFAULT 'Day Shift',
        status TEXT DEFAULT 'TAKEN',
        notes TEXT DEFAULT ''
    );

    CREATE INDEX IF NOT EXISTS idx_chocolate_consumption_date ON public.chocolate_consumption_ledger(date DESC);
    CREATE INDEX IF NOT EXISTS idx_chocolate_consumption_code ON public.chocolate_consumption_ledger(material_code);
    CREATE INDEX IF NOT EXISTS idx_chocolate_consumption_created_at ON public.chocolate_consumption_ledger(created_at DESC);

    ALTER TABLE public.chocolate_consumption_ledger ENABLE ROW LEVEL SECURITY;

    DROP POLICY IF EXISTS "Allow select all for chocolate_consumption_ledger" ON public.chocolate_consumption_ledger;
    CREATE POLICY "Allow select all for chocolate_consumption_ledger" 
    ON public.chocolate_consumption_ledger FOR SELECT TO authenticated USING (true);

    DROP POLICY IF EXISTS "Allow insert for chocolate_consumption_ledger" ON public.chocolate_consumption_ledger;
    CREATE POLICY "Allow insert for chocolate_consumption_ledger" 
    ON public.chocolate_consumption_ledger FOR INSERT TO authenticated WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow update for chocolate_consumption_ledger" ON public.chocolate_consumption_ledger;
    CREATE POLICY "Allow update for chocolate_consumption_ledger" 
    ON public.chocolate_consumption_ledger FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow delete for chocolate_consumption_ledger" ON public.chocolate_consumption_ledger;
    CREATE POLICY "Allow delete for chocolate_consumption_ledger" 
    ON public.chocolate_consumption_ledger FOR DELETE TO authenticated USING (true);

    DROP POLICY IF EXISTS "Allow anon select for chocolate_consumption_ledger" ON public.chocolate_consumption_ledger;
    CREATE POLICY "Allow anon select for chocolate_consumption_ledger" 
    ON public.chocolate_consumption_ledger FOR SELECT TO anon USING (true);

    DROP POLICY IF EXISTS "Allow anon insert for chocolate_consumption_ledger" ON public.chocolate_consumption_ledger;
    CREATE POLICY "Allow anon insert for chocolate_consumption_ledger" 
    ON public.chocolate_consumption_ledger FOR INSERT TO anon WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow anon update for chocolate_consumption_ledger" ON public.chocolate_consumption_ledger;
    CREATE POLICY "Allow anon update for chocolate_consumption_ledger" 
    ON public.chocolate_consumption_ledger FOR UPDATE TO anon USING (true) WITH CHECK (true);

    DROP POLICY IF EXISTS "Allow anon delete for chocolate_consumption_ledger" ON public.chocolate_consumption_ledger;
    CREATE POLICY "Allow anon delete for chocolate_consumption_ledger" 
    ON public.chocolate_consumption_ledger FOR DELETE TO anon USING (true);
    """)
    print("   Table chocolate_consumption_ledger created/verified with RLS policies.")

    # 2. Attach prevent_owner_operational_writes trigger
    print("2. Attaching trg_prevent_owner_writes trigger...")
    cur.execute("""
    DROP TRIGGER IF EXISTS trg_prevent_owner_writes ON public.chocolate_consumption_ledger;
    CREATE TRIGGER trg_prevent_owner_writes
    BEFORE INSERT OR UPDATE OR DELETE ON public.chocolate_consumption_ledger
    FOR EACH ROW
    EXECUTE FUNCTION public.prevent_owner_operational_writes();
    """)
    print("   Trigger trg_prevent_owner_writes attached.")

    # 3. Create or replace RPC: record_chocolate_consumption with atomic balance validation
    print("3. Creating public.record_chocolate_consumption RPC...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.record_chocolate_consumption(p_entry jsonb)
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
    AS $$
    DECLARE
        v_code TEXT;
        v_desc TEXT;
        v_unit TEXT;
        v_consumed NUMERIC(15, 3);
        v_taken NUMERIC(15, 3);
        v_balance NUMERIC(15, 3);
        v_operator TEXT;
        v_shift TEXT;
        v_notes TEXT;
        v_status TEXT;
        v_date DATE;
        v_idempotency_key TEXT;
        
        v_total_rcvd NUMERIC(15, 3) := 0;
        v_total_ret NUMERIC(15, 3) := 0;
        v_total_consumed NUMERIC(15, 3) := 0;
        v_available NUMERIC(15, 3) := 0;
        
        v_new_id BIGINT;
        v_result JSONB;
    BEGIN
        v_code := TRIM(COALESCE(p_entry->>'material_code', p_entry->>'code', ''));
        IF v_code = '' THEN
            RAISE EXCEPTION 'Material code is required for chocolate consumption.';
        END IF;

        v_consumed := (p_entry->>'consumed_qty')::NUMERIC;
        IF v_consumed IS NULL OR v_consumed <= 0 THEN
            RAISE EXCEPTION 'Consumed quantity must be greater than zero.';
        END IF;

        -- Verify idempotency if key provided
        v_idempotency_key := TRIM(COALESCE(p_entry->>'idempotency_key', ''));
        IF v_idempotency_key != '' THEN
            SELECT response INTO v_result
            FROM public.idempotency_keys
            WHERE idempotency_key = v_idempotency_key AND status = 'completed';
            
            IF v_result IS NOT NULL THEN
                RETURN v_result;
            END IF;
        END IF;

        -- Calculate total received and returned for this material strictly in Chocolate department
        SELECT 
            COALESCE(SUM(outward), 0),
            COALESCE(SUM(return_units), 0)
        INTO v_total_rcvd, v_total_ret
        FROM public.transfers
        WHERE TRIM(code) = v_code 
          AND UPPER(TRIM(COALESCE(department, ''))) = 'CHOCOLATE';

        IF v_total_rcvd <= 0.0001 THEN
            RAISE EXCEPTION 'Material % has not been transferred to Chocolate department.', v_code;
        END IF;

        -- Calculate total already consumed in Chocolate
        SELECT COALESCE(SUM(consumed_qty), 0)
        INTO v_total_consumed
        FROM public.chocolate_consumption_ledger
        WHERE TRIM(material_code) = v_code;

        -- Authoritative available Chocolate balance: Received - Returned - Consumed
        v_available := (v_total_rcvd - v_total_ret - v_total_consumed);

        IF v_available <= 0.0001 THEN
            RAISE EXCEPTION 'Material % has zero available balance in Chocolate department (Transferred: %, Consumed: %, Returned: %).',
                v_code, v_total_rcvd, v_total_consumed, v_total_ret;
        END IF;

        IF v_consumed > (v_available + 0.0001) THEN
            RAISE EXCEPTION 'Insufficient Chocolate balance for material %. Requested: %, Available: %',
                v_code, v_consumed, v_available;
        END IF;

        v_desc := TRIM(COALESCE(p_entry->>'description', ''));
        v_unit := TRIM(COALESCE(p_entry->>'unit', p_entry->>'units', 'kg'));
        v_taken := COALESCE((p_entry->>'taken_qty')::NUMERIC, v_available);
        v_balance := COALESCE((p_entry->>'balance_qty')::NUMERIC, (v_available - v_consumed));
        v_operator := TRIM(COALESCE(p_entry->>'operator_name', 'Chocolate Operator'));
        v_shift := TRIM(COALESCE(p_entry->>'shift', 'Day Shift'));
        v_notes := TRIM(COALESCE(p_entry->>'notes', ''));
        v_status := TRIM(COALESCE(p_entry->>'status', 'CLOSED'));
        
        IF p_entry->>'date' IS NOT NULL AND TRIM(p_entry->>'date') != '' THEN
            v_date := (p_entry->>'date')::DATE;
        ELSE
            v_date := CURRENT_DATE;
        END IF;

        -- Insert into chocolate_consumption_ledger
        INSERT INTO public.chocolate_consumption_ledger (
            date,
            created_at,
            updated_at,
            material_code,
            description,
            category,
            department,
            unit,
            taken_qty,
            balance_qty,
            consumed_qty,
            operator_name,
            shift,
            status,
            notes
        ) VALUES (
            v_date,
            NOW(),
            NOW(),
            v_code,
            v_desc,
            'CHOCOLATE',
            'CHOCOLATE',
            v_unit,
            v_taken,
            v_balance,
            v_consumed,
            v_operator,
            v_shift,
            v_status,
            v_notes
        )
        RETURNING id INTO v_new_id;

        -- Select inserted record as JSONB
        SELECT to_jsonb(r) INTO v_result
        FROM public.chocolate_consumption_ledger r
        WHERE id = v_new_id;

        -- Store idempotency if key was provided
        IF v_idempotency_key != '' THEN
            INSERT INTO public.idempotency_keys (idempotency_key, operation_type, response, status, created_at)
            VALUES (v_idempotency_key, 'chocolate_consumption_record', v_result, 'completed', NOW())
            ON CONFLICT (idempotency_key) DO UPDATE 
            SET response = v_result, status = 'completed';
        END IF;

        RETURN v_result;
    END;
    $$;

    GRANT EXECUTE ON FUNCTION public.record_chocolate_consumption(jsonb) TO authenticated, anon;
    """)
    print("   Created public.record_chocolate_consumption RPC.")

    # 4. Update get_chocolate_material_received_ledger to deduct chocolate consumption
    print("4. Updating public.get_chocolate_material_received_ledger RPC to deduct consumption...")
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
        ),
        choc_consumption AS (
            SELECT 
                c.material_code as code,
                COALESCE(SUM(c.consumed_qty), 0)::NUMERIC as sum_consumed,
                MAX(COALESCE(c.created_at, c.date::timestamp with time zone)) as max_consumed_at
            FROM public.chocolate_consumption_ledger c
            GROUP BY c.material_code
        )
        SELECT 
            trf.code AS material_code,
            trf.mat_desc AS description,
            trf.mat_cat AS category,
            trf.mat_unit AS unit,
            ROUND(trf.sum_rcvd, 3) AS total_received,
            ROUND((trf.sum_ret + COALESCE(cc.sum_consumed, 0)), 3) AS total_accounted,
            ROUND(GREATEST(0, (trf.sum_rcvd - trf.sum_ret - COALESCE(cc.sum_consumed, 0))), 3) AS current_balance,
            GREATEST(trf.max_trf_at, cc.max_consumed_at) AS latest_activity,
            CASE 
                WHEN (trf.sum_rcvd - trf.sum_ret - COALESCE(cc.sum_consumed, 0)) > 0.0001 THEN 'IN_STOCK'
                ELSE 'ZERO_BALANCE'
            END AS status,
            trf.trf_cnt AS transfer_count
        FROM choc_trf trf
        LEFT JOIN choc_consumption cc ON cc.code = trf.code
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
            CASE WHEN (trf.sum_rcvd - trf.sum_ret - COALESCE(cc.sum_consumed, 0)) > 0.0001 THEN 0 ELSE 1 END,
            trf.mat_desc ASC;
    END;
    $$;
    GRANT EXECUTE ON FUNCTION public.get_chocolate_material_received_ledger(text, text) TO authenticated, anon;
    """)
    print("   Updated get_chocolate_material_received_ledger.")

    # 5. Update get_owner_admin_live_stock to subtract chocolate consumption
    print("5. Updating public.get_owner_admin_live_stock RPC...")
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
        choc_consumed_summary AS (
            SELECT 
                c.material_code as code,
                COALESCE(SUM(c.consumed_qty), 0)::NUMERIC as choc_consumed,
                MAX(COALESCE(c.created_at, c.date::timestamp with time zone)) as max_choc_consumption_at
            FROM public.chocolate_consumption_ledger c
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
            ROUND(GREATEST(0, COALESCE(ts.choc_trf, 0) - COALESCE(cc.choc_consumed, 0))::NUMERIC, 3) as chocolate_stock,
            ROUND(COALESCE(ts.other_trf, 0)::NUMERIC, 3) as other_stock,
            ROUND((GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0)) + GREATEST(0, COALESCE(ts.choc_trf, 0) - COALESCE(cc.choc_consumed, 0)) + COALESCE(ts.other_trf, 0))::NUMERIC, 3) as total_transferred,
            ROUND((COALESCE(m.quantity, 0) + GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0)) + GREATEST(0, COALESCE(ts.choc_trf, 0) - COALESCE(cc.choc_consumed, 0)) + COALESCE(ts.other_trf, 0))::NUMERIC, 3) as total_system_stock,
            GREATEST(m.last_updated, ts.max_trf_at, tc.max_consumption_at, cc.max_choc_consumption_at, invs.max_inv_at) as last_transaction_at
        FROM public.materials m
        LEFT JOIN trf_summary ts ON ts.code = m.material_code
        LEFT JOIN tea_consumed_summary tc ON tc.code = m.material_code
        LEFT JOIN choc_consumed_summary cc ON cc.code = m.material_code
        LEFT JOIN inv_summary invs ON invs.code = m.material_code
        WHERE (
            p_search IS NULL OR TRIM(p_search) = '' OR
            m.material_code ILIKE '%' || TRIM(p_search) || '%' OR
            m.description ILIKE '%' || TRIM(p_search) || '%' OR
            m.category ILIKE '%' || TRIM(p_search) || '%'
        )
        ORDER BY 
            (COALESCE(m.quantity, 0) + GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0)) + GREATEST(0, COALESCE(ts.choc_trf, 0) - COALESCE(cc.choc_consumed, 0)) + COALESCE(ts.other_trf, 0)) DESC,
            m.material_code ASC;
    END;
    $$;
    GRANT EXECUTE ON FUNCTION public.get_owner_admin_live_stock(text) TO authenticated, anon;
    """)
    print("   Updated get_owner_admin_live_stock.")

    # 6. Update get_owner_out_of_stock_report to subtract chocolate consumption
    print("6. Updating public.get_owner_out_of_stock_report RPC...")
    cur.execute("DROP FUNCTION IF EXISTS public.get_owner_out_of_stock_report(text, text);")
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
        status text,
        action_needed text
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
        choc_consumed_summary AS (
            SELECT 
                c.material_code as code,
                COALESCE(SUM(c.consumed_qty), 0)::NUMERIC as choc_consumed,
                MAX(COALESCE(c.created_at, c.date::timestamp with time zone)) as max_choc_consumption_at
            FROM public.chocolate_consumption_ledger c
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
                ROUND(GREATEST(0, COALESCE(ts.choc_trf, 0) - COALESCE(cc.choc_consumed, 0))::NUMERIC, 3) as c_stock,
                ROUND(COALESCE(ts.other_trf, 0)::NUMERIC, 3) as o_stock,
                ROUND((COALESCE(m.quantity, 0) + GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0)) + GREATEST(0, COALESCE(ts.choc_trf, 0) - COALESCE(cc.choc_consumed, 0)) + COALESCE(ts.other_trf, 0))::NUMERIC, 3) as tot_stock,
                COALESCE(m.reorder_level, 0)::NUMERIC as r_level,
                GREATEST(m.last_updated, ts.max_trf_at, tc.max_consumption_at, cc.max_choc_consumption_at, invs.max_inv_at) as last_tx,
                COALESCE(ts.tea_trf_count, 0) as tea_count,
                COALESCE(ts.choc_trf_count, 0) as choc_count
            FROM public.materials m
            LEFT JOIN trf_summary ts ON ts.code = m.material_code
            LEFT JOIN tea_consumed_summary tc ON tc.code = m.material_code
            LEFT JOIN choc_consumed_summary cc ON cc.code = m.material_code
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
                ) THEN 'DEPLETED_LOCATION'
                ELSE 'DEPLETED_DEPARTMENT'
            END AS status,
            CASE 
                WHEN b.tot_stock <= 0.0001 THEN 'Create Purchase Order from Supplier'
                WHEN v_dept = 'ADMIN' AND b.adm_stock <= 0.0001 THEN 'Replenish Admin Warehouse from Vendor'
                WHEN v_dept = 'TEA' AND b.t_stock <= 0.0001 AND b.adm_stock > 0 THEN 'Internal Transfer: Admin -> Tea'
                WHEN v_dept = 'CHOCOLATE' AND b.c_stock <= 0.0001 AND b.adm_stock > 0 THEN 'Internal Transfer: Admin -> Chocolate'
                ELSE 'Internal Stock Rebalance'
            END AS action_needed
        FROM base_stocks b
        WHERE (
            -- Department Filter
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
        ORDER BY b.description ASC;
    END;
    $$;
    GRANT EXECUTE ON FUNCTION public.get_owner_out_of_stock_report(text, text) TO authenticated, anon;
    """)
    print("   Updated get_owner_out_of_stock_report.")

    # 7. Update get_owner_reorder_report to subtract chocolate consumption
    print("7. Updating public.get_owner_reorder_report RPC...")
    cur.execute("DROP FUNCTION IF EXISTS public.get_owner_reorder_report(text, text, text);")
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
        department text,
        current_stock numeric,
        admin_stock numeric,
        tea_stock numeric,
        chocolate_stock numeric,
        total_business_stock numeric,
        reorder_level numeric,
        deficit numeric,
        suggested_reorder_qty numeric,
        status text,
        last_transaction_at timestamp with time zone,
        urgency text
    )
    LANGUAGE plpgsql
    SECURITY DEFINER
    SET search_path = public
    AS $$
    DECLARE
        v_dept text;
        v_status text;
    BEGIN
        v_dept := UPPER(TRIM(COALESCE(p_department, 'ALL')));
        v_status := UPPER(TRIM(COALESCE(p_status, 'ALL')));

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
        choc_consumed_summary AS (
            SELECT 
                c.material_code as code,
                COALESCE(SUM(c.consumed_qty), 0)::NUMERIC as choc_consumed,
                MAX(COALESCE(c.created_at, c.date::timestamp with time zone)) as max_choc_consumption_at
            FROM public.chocolate_consumption_ledger c
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
        base_reorders AS (
            SELECT 
                m.material_code,
                m.description,
                COALESCE(m.category, 'General') as category,
                COALESCE(m.unit, 'kg') as unit,
                v_dept AS dept_name,
                ROUND(COALESCE(m.quantity, 0)::NUMERIC, 3) as adm_stock,
                ROUND(GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0))::NUMERIC, 3) as t_stock,
                ROUND(GREATEST(0, COALESCE(ts.choc_trf, 0) - COALESCE(cc.choc_consumed, 0))::NUMERIC, 3) as c_stock,
                ROUND((COALESCE(m.quantity, 0) + GREATEST(0, COALESCE(ts.tea_trf, 0) - COALESCE(tc.tea_consumed, 0)) + GREATEST(0, COALESCE(ts.choc_trf, 0) - COALESCE(cc.choc_consumed, 0)) + COALESCE(ts.other_trf, 0))::NUMERIC, 3) as tot_stock,
                COALESCE(m.reorder_level, 0)::NUMERIC as r_level,
                GREATEST(m.last_updated, ts.max_trf_at, tc.max_consumption_at, cc.max_choc_consumption_at, invs.max_inv_at) as last_tx,
                COALESCE(ts.tea_trf_count, 0) as tea_count,
                COALESCE(ts.choc_trf_count, 0) as choc_count
            FROM public.materials m
            LEFT JOIN trf_summary ts ON ts.code = m.material_code
            LEFT JOIN tea_consumed_summary tc ON tc.code = m.material_code
            LEFT JOIN choc_consumed_summary cc ON cc.code = m.material_code
            LEFT JOIN inv_summary invs ON invs.code = m.material_code
        ),
        calculated AS (
            SELECT 
                b.material_code,
                b.description,
                b.category,
                b.unit,
                CASE 
                    WHEN v_dept = 'ADMIN' THEN 'Admin Warehouse'
                    WHEN v_dept = 'TEA' THEN 'Tea Department'
                    WHEN v_dept = 'CHOCOLATE' THEN 'Chocolate Department'
                    ELSE 'All Operations'
                END AS department,
                CASE 
                    WHEN v_dept = 'ADMIN' THEN b.adm_stock
                    WHEN v_dept = 'TEA' THEN b.t_stock
                    WHEN v_dept = 'CHOCOLATE' THEN b.c_stock
                    ELSE b.tot_stock
                END AS current_stock,
                b.adm_stock AS admin_stock,
                b.t_stock AS tea_stock,
                b.c_stock AS chocolate_stock,
                b.tot_stock AS total_business_stock,
                b.r_level AS reorder_level,
                ROUND(GREATEST(0, b.r_level - (CASE 
                    WHEN v_dept = 'ADMIN' THEN b.adm_stock
                    WHEN v_dept = 'TEA' THEN b.t_stock
                    WHEN v_dept = 'CHOCOLATE' THEN b.c_stock
                    ELSE b.tot_stock
                END))::NUMERIC, 3) AS deficit,
                ROUND(GREATEST(0, (b.r_level * 1.5) - (CASE 
                    WHEN v_dept = 'ADMIN' THEN b.adm_stock
                    WHEN v_dept = 'TEA' THEN b.t_stock
                    WHEN v_dept = 'CHOCOLATE' THEN b.c_stock
                    ELSE b.tot_stock
                END))::NUMERIC, 3) AS suggested_reorder_qty,
                b.last_tx AS last_transaction_at,
                b.tea_count,
                b.choc_count
            FROM base_reorders b
        )
        SELECT 
            c.material_code,
            c.description,
            c.category,
            c.unit,
            c.department,
            c.current_stock,
            c.admin_stock,
            c.tea_stock,
            c.chocolate_stock,
            c.total_business_stock,
            c.reorder_level,
            c.deficit,
            c.suggested_reorder_qty,
            CASE 
                WHEN c.current_stock <= 0.0001 THEN 'OUT_OF_STOCK'
                WHEN c.current_stock < c.reorder_level THEN 'BELOW_REORDER'
                WHEN c.current_stock <= (c.reorder_level * 1.15) THEN 'NEAR_REORDER'
                ELSE 'HEALTHY'
            END AS status,
            c.last_transaction_at,
            CASE 
                WHEN c.current_stock <= 0.0001 THEN 'CRITICAL'
                WHEN c.current_stock < c.reorder_level THEN 'HIGH'
                WHEN c.current_stock <= (c.reorder_level * 1.15) THEN 'MEDIUM'
                ELSE 'LOW'
            END AS urgency
        FROM calculated c
        WHERE (
            v_dept = 'ALL' OR
            v_dept = 'ADMIN' OR
            (v_dept = 'TEA' AND c.tea_count > 0) OR
            (v_dept = 'CHOCOLATE' AND c.choc_count > 0)
        )
        AND (
            p_search IS NULL OR TRIM(p_search) = '' OR
            c.material_code ILIKE '%' || TRIM(p_search) || '%' OR
            c.description ILIKE '%' || TRIM(p_search) || '%' OR
            c.category ILIKE '%' || TRIM(p_search) || '%'
        )
        AND (
            v_status = 'ALL' OR
            (v_status = 'OUT_OF_STOCK' AND c.current_stock <= 0.0001) OR
            (v_status = 'BELOW_REORDER' AND c.current_stock > 0.0001 AND c.current_stock < c.reorder_level) OR
            (v_status = 'NEAR_REORDER' AND c.current_stock >= c.reorder_level AND c.current_stock <= (c.reorder_level * 1.15)) OR
            (v_status = 'HEALTHY' AND c.current_stock > (c.reorder_level * 1.15))
        )
        ORDER BY 
            CASE 
                WHEN c.current_stock <= 0.0001 THEN 1
                WHEN c.current_stock < c.reorder_level THEN 2
                WHEN c.current_stock <= (c.reorder_level * 1.15) THEN 3
                ELSE 4
            END ASC,
            c.deficit DESC,
            c.description ASC;
    END;
    $$;
    GRANT EXECUTE ON FUNCTION public.get_owner_reorder_report(text, text, text) TO authenticated, anon;
    """)
    print("   Updated get_owner_reorder_report.")

    cur.close()
    conn.close()
    print("=== Chocolate Consumption Migration Applied Successfully ===")

if __name__ == '__main__':
    apply_chocolate_consumption_migration()
