import os
import psycopg2

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = os.environ.get('SUPABASE_DB_PASSWORD', 'mapleconnect2307')
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

def run_migration():
    print("Connecting to Supabase PostgreSQL...")
    conn = psycopg2.connect(
        host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15
    )
    conn.autocommit = False
    cur = conn.cursor()

    try:
        # 1. Create or replace RPC: record_tea_consumption with atomic balance validation
        print("1. Creating public.record_tea_consumption RPC...")
        cur.execute("""
CREATE OR REPLACE FUNCTION public.record_tea_consumption(p_entry jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
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
        RAISE EXCEPTION 'Material code is required for consumption.';
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

    -- Calculate total received and returned for this material strictly in Tea department
    SELECT 
        COALESCE(SUM(outward), 0),
        COALESCE(SUM(return_units), 0)
    INTO v_total_rcvd, v_total_ret
    FROM public.transfers
    WHERE TRIM(code) = v_code 
      AND UPPER(TRIM(COALESCE(department, ''))) = 'TEA';

    IF v_total_rcvd <= 0.0001 THEN
        RAISE EXCEPTION 'Material % has not been transferred to Tea department.', v_code;
    END IF;

    -- Calculate total already consumed in Tea
    SELECT COALESCE(SUM(consumed_qty), 0)
    INTO v_total_consumed
    FROM public.tea_consumption_ledger
    WHERE TRIM(material_code) = v_code;

    -- Authoritative available Tea balance: Received - Returned - Consumed
    v_available := (v_total_rcvd - v_total_ret - v_total_consumed);

    IF v_available <= 0.0001 THEN
        RAISE EXCEPTION 'Material % has zero available balance in Tea department (Transferred: %, Consumed: %, Returned: %).',
            v_code, v_total_rcvd, v_total_consumed, v_total_ret;
    END IF;

    IF v_consumed > (v_available + 0.0001) THEN
        RAISE EXCEPTION 'Insufficient Tea balance for material %. Requested: %, Available: %',
            v_code, v_consumed, v_available;
    END IF;

    v_desc := TRIM(COALESCE(p_entry->>'description', ''));
    v_unit := TRIM(COALESCE(p_entry->>'unit', p_entry->>'units', 'kg'));
    v_taken := COALESCE((p_entry->>'taken_qty')::NUMERIC, v_available);
    v_balance := COALESCE((p_entry->>'balance_qty')::NUMERIC, (v_available - v_consumed));
    v_operator := TRIM(COALESCE(p_entry->>'operator_name', 'Tea Operator'));
    v_shift := TRIM(COALESCE(p_entry->>'shift', 'Day Shift'));
    v_notes := TRIM(COALESCE(p_entry->>'notes', ''));
    v_status := TRIM(COALESCE(p_entry->>'status', 'CLOSED'));
    
    IF p_entry->>'date' IS NOT NULL AND TRIM(p_entry->>'date') != '' THEN
        v_date := (p_entry->>'date')::DATE;
    ELSE
        v_date := CURRENT_DATE;
    END IF;

    -- Insert into tea_consumption_ledger
    INSERT INTO public.tea_consumption_ledger (
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
        'TEA',
        'TEA',
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
    FROM public.tea_consumption_ledger r
    WHERE id = v_new_id;

    -- Store idempotency if key was provided
    IF v_idempotency_key != '' THEN
        INSERT INTO public.idempotency_keys (idempotency_key, operation_type, response, status, created_at)
        VALUES (v_idempotency_key, 'tea_consumption_record', v_result, 'completed', NOW())
        ON CONFLICT (idempotency_key) DO UPDATE 
        SET response = v_result, status = 'completed';
    END IF;

    RETURN v_result;
END;
$$;
GRANT EXECUTE ON FUNCTION public.record_tea_consumption(jsonb) TO authenticated, anon;
""")

        # 2. Update get_tea_material_received_ledger RPC to remove category leakage
        print("2. Updating public.get_tea_material_received_ledger RPC...")
        cur.execute("""
CREATE OR REPLACE FUNCTION public.get_tea_material_received_ledger(
    p_search text DEFAULT NULL::text, 
    p_category text DEFAULT NULL::text
)
RETURNS TABLE(
    material_code text, 
    description text, 
    category text, 
    unit text, 
    total_received numeric, 
    total_consumed numeric, 
    total_returned numeric, 
    current_balance numeric, 
    latest_activity timestamp with time zone, 
    status text, 
    transfer_count integer, 
    consume_count integer, 
    return_count integer
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $function$
BEGIN
    RETURN QUERY
    WITH tea_trf AS (
        SELECT 
            t.code,
            COALESCE(MAX(m.description), MAX(t.description), t.code) as mat_desc,
            COALESCE(MAX(m.category), MAX(t.category), 'TEA') as mat_cat,
            COALESCE(MAX(m.unit), MAX(t.units), 'kg') as mat_unit,
            COALESCE(SUM(t.outward), 0)::NUMERIC as sum_rcvd,
            COALESCE(SUM(t.return_units), 0)::NUMERIC as sum_ret,
            MAX(COALESCE(t.created_at, t.date::timestamp with time zone)) as max_trf_at,
            COUNT(CASE WHEN t.outward > 0 THEN 1 END)::INT as trf_cnt,
            COUNT(CASE WHEN t.return_units > 0 THEN 1 END)::INT as ret_cnt
        FROM public.transfers t
        LEFT JOIN public.materials m ON m.material_code = t.code
        WHERE UPPER(TRIM(COALESCE(t.department, ''))) = 'TEA'
        GROUP BY t.code
        HAVING COALESCE(SUM(t.outward), 0) > 0
    ),
    tea_con AS (
        SELECT 
            c.material_code,
            COALESCE(SUM(c.consumed_qty), 0)::NUMERIC as sum_con,
            MAX(COALESCE(c.created_at, c.date::timestamp with time zone)) as max_con_at,
            COUNT(*)::INT as con_cnt
        FROM public.tea_consumption_ledger c
        GROUP BY c.material_code
    )
    SELECT 
        trf.code AS material_code,
        trf.mat_desc AS description,
        trf.mat_cat AS category,
        trf.mat_unit AS unit,
        ROUND(trf.sum_rcvd, 3) AS total_received,
        ROUND(COALESCE(con.sum_con, 0), 3) AS total_consumed,
        ROUND(trf.sum_ret, 3) AS total_returned,
        ROUND((trf.sum_rcvd - COALESCE(con.sum_con, 0) - trf.sum_ret), 3) AS current_balance,
        GREATEST(trf.max_trf_at, con.max_con_at) AS latest_activity,
        CASE 
            WHEN (trf.sum_rcvd - COALESCE(con.sum_con, 0) - trf.sum_ret) > 0.0001 THEN 'IN_STOCK'
            ELSE 'DEPLETED'
        END AS status,
        trf.trf_cnt AS transfer_count,
        COALESCE(con.con_cnt, 0) AS consume_count,
        trf.ret_cnt AS return_count
    FROM tea_trf trf
    LEFT JOIN tea_con con ON con.material_code = trf.code
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
        CASE WHEN (trf.sum_rcvd - COALESCE(con.sum_con, 0) - trf.sum_ret) > 0.0001 THEN 0 ELSE 1 END,
        trf.mat_desc ASC;
END;
$function$;
""")

        # 3. Create Restrictive RLS Policies on transfers for Tea Users
        print("3. Setting up restrictive RLS policies for Tea users on public.transfers...")
        cur.execute("""
DROP POLICY IF EXISTS "tea_user_transfers_restrict_select" ON public.transfers;
CREATE POLICY "tea_user_transfers_restrict_select" ON public.transfers
AS RESTRICTIVE FOR SELECT TO authenticated
USING (
    NOT public.is_tea_user() OR UPPER(TRIM(COALESCE(department, ''))) = 'TEA'
);

DROP POLICY IF EXISTS "tea_user_transfers_restrict_insert" ON public.transfers;
CREATE POLICY "tea_user_transfers_restrict_insert" ON public.transfers
AS RESTRICTIVE FOR INSERT TO authenticated
WITH CHECK (
    NOT public.is_tea_user()
);

DROP POLICY IF EXISTS "tea_user_transfers_restrict_update" ON public.transfers;
CREATE POLICY "tea_user_transfers_restrict_update" ON public.transfers
AS RESTRICTIVE FOR UPDATE TO authenticated
USING (
    NOT public.is_tea_user()
);

DROP POLICY IF EXISTS "tea_user_transfers_restrict_delete" ON public.transfers;
CREATE POLICY "tea_user_transfers_restrict_delete" ON public.transfers
AS RESTRICTIVE FOR DELETE TO authenticated
USING (
    NOT public.is_tea_user()
);
""")

        # 4. Update create_transfer to forbid outward transfers by Tea users
        print("4. Updating create_transfer to enforce no outward transfers by Tea users...")
        cur.execute("""
CREATE OR REPLACE FUNCTION public.create_transfer(p_transfer jsonb, p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
    v_idempotency_key TEXT;
    v_cached_response JSONB;
    v_transfer_id BIGINT;
    v_code TEXT;
    v_desc TEXT;
    v_dept TEXT;
    v_person TEXT;
    v_units TEXT;
    v_date DATE;
    v_created_at TIMESTAMP WITH TIME ZONE;
    v_outward NUMERIC(15, 3);
    v_return_units NUMERIC(15, 3);
    v_net_change NUMERIC(15, 3);
    
    v_current_stock NUMERIC(15, 3);
    v_total_lot_stock NUMERIC(15, 3);
    v_remaining_balance NUMERIC(15, 3);
    v_mat_id BIGINT;
    v_mat_category TEXT;
    
    v_needed NUMERIC(15, 3);
    v_lot RECORD;
    v_take NUMERIC(15, 3);
    v_lots_allocated TEXT := '';
    v_result JSONB;
BEGIN
    v_idempotency_key := COALESCE(p_idempotency_key, p_transfer->>'idempotency_key');

    -- Idempotency check
    IF v_idempotency_key IS NOT NULL AND TRIM(v_idempotency_key) != '' THEN
        SELECT response INTO v_cached_response 
        FROM public.idempotency_keys 
        WHERE idempotency_key = v_idempotency_key AND status = 'completed';

        IF v_cached_response IS NOT NULL THEN
            RETURN v_cached_response;
        END IF;
    END IF;

    v_code := TRIM(p_transfer->>'code');
    IF v_code IS NULL OR v_code = '' THEN
        RAISE EXCEPTION 'Material code is required.';
    END IF;

    -- Lookup material in materials table
    SELECT id, description, quantity, unit, category 
    INTO v_mat_id, v_desc, v_current_stock, v_units, v_mat_category
    FROM public.materials 
    WHERE material_code = v_code 
    FOR UPDATE;

    IF v_mat_id IS NULL THEN
        RAISE EXCEPTION 'Material code "%" not found in Material Master.', v_code;
    END IF;

    v_dept := TRIM(COALESCE(p_transfer->>'department', ''));
    v_person := TRIM(COALESCE(p_transfer->>'person', ''));
    v_units := COALESCE(NULLIF(TRIM(p_transfer->>'units'), ''), v_units, 'kg');
    
    IF p_transfer->>'date' IS NOT NULL AND TRIM(p_transfer->>'date') != '' THEN
        v_date := (p_transfer->>'date')::DATE;
    ELSE
        v_date := CURRENT_DATE;
    END IF;

    v_created_at := CURRENT_TIMESTAMP;

    v_outward := ROUND(COALESCE((p_transfer->>'outward')::NUMERIC, 0), 3);
    v_return_units := ROUND(COALESCE((p_transfer->>'return_units')::NUMERIC, 0), 3);

    IF v_outward < 0 THEN
        RAISE EXCEPTION 'Outward quantity cannot be negative.';
    END IF;
    IF v_return_units < 0 THEN
        RAISE EXCEPTION 'Return quantity cannot be negative.';
    END IF;
    IF v_outward = 0 AND v_return_units = 0 THEN
        RAISE EXCEPTION 'Either Outward Quantity or Return Quantity must be greater than zero.';
    END IF;

    -- Backend Permission Check: Tea user cannot create outward transfers from Admin
    IF public.is_tea_user() AND v_outward > 0 THEN
        RAISE EXCEPTION 'Access Denied: Tea users cannot create outward transfers. Only Admin can transfer materials to departments.';
    END IF;

    -- Calculate total active stock in lots
    SELECT COALESCE(SUM(available_quantity), 0) INTO v_total_lot_stock
    FROM public.material_lots
    WHERE material_code = v_code AND available_quantity > 0;

    -- Outward validation
    IF v_outward > 0 AND v_outward > v_total_lot_stock THEN
        RAISE EXCEPTION 'Insufficient stock in active lots. Requested outward: %, Total available: %',
            v_outward, v_total_lot_stock;
    END IF;

    v_net_change := v_return_units - v_outward;
    v_remaining_balance := v_current_stock + v_net_change;

    IF v_remaining_balance < 0 THEN
        RAISE EXCEPTION 'Transfer would result in negative material stock balance (% + % = %).',
            v_current_stock, v_net_change, v_remaining_balance;
    END IF;

    -- Update Material Master stock
    UPDATE public.materials
    SET quantity = v_remaining_balance,
        last_updated = v_created_at
    WHERE id = v_mat_id;

    -- Insert record into transfers table (including category)
    INSERT INTO public.transfers (
        date, code, description, outward, return_units, units, department, person, availability, created_at, category
    ) VALUES (
        v_date, v_code, v_desc, v_outward, v_return_units, v_units, v_dept, v_person, v_remaining_balance, v_created_at, v_mat_category
    ) RETURNING id INTO v_transfer_id;

    -- FIFO Lot Deductions
    IF v_outward > 0 THEN
        v_needed := v_outward;
        FOR v_lot IN 
            SELECT id, lot_no, available_quantity 
            FROM public.material_lots 
            WHERE material_code = v_code AND available_quantity > 0 
            ORDER BY COALESCE(lot_date, created_at::date) ASC, id ASC 
            FOR UPDATE 
        LOOP
            EXIT WHEN v_needed <= 0;
            v_take := LEAST(v_lot.available_quantity, v_needed);

            UPDATE public.material_lots
            SET available_quantity = available_quantity - v_take
            WHERE id = v_lot.id;

            INSERT INTO public.transfer_lot_allocations (
                transfer_id, lot_id, lot_no, quantity
            ) VALUES (
                v_transfer_id, v_lot.id, v_lot.lot_no, v_take
            );

            IF v_lots_allocated = '' THEN
                v_lots_allocated := v_lot.lot_no;
            ELSE
                v_lots_allocated := v_lots_allocated || ', ' || v_lot.lot_no;
            END IF;

            v_needed := v_needed - v_take;
        END LOOP;

        IF v_needed > 0 THEN
            RAISE EXCEPTION 'FIFO lot deduction failure: % could not be allocated across lots.', v_needed;
        END IF;

        UPDATE public.transfers 
        SET lot_no = v_lots_allocated 
        WHERE id = v_transfer_id;
    END IF;

    v_result := jsonb_build_object(
        'success', TRUE,
        'transfer_id', v_transfer_id,
        'code', v_code,
        'description', v_desc,
        'department', v_dept,
        'person', v_person,
        'outward', v_outward,
        'return_units', v_return_units,
        'net_change', v_net_change,
        'available_balance', v_remaining_balance,
        'lots_allocated', v_lots_allocated,
        'message', 'Transfer recorded successfully'
    );

    IF v_idempotency_key IS NOT NULL AND TRIM(v_idempotency_key) != '' THEN
        INSERT INTO public.idempotency_keys (idempotency_key, operation_type, response, status, created_at)
        VALUES (v_idempotency_key, 'transfer_create', v_result, 'completed', CURRENT_TIMESTAMP)
        ON CONFLICT (idempotency_key) DO UPDATE
        SET response = v_result, status = 'completed';
    END IF;

    RETURN v_result;
END;
$function$;
""")

        conn.commit()
        print("Migration completed successfully!")

    except Exception as e:
        conn.rollback()
        print(f"Error during migration: {e}")
        raise
    finally:
        cur.close()
        conn.close()

if __name__ == '__main__':
    run_migration()
