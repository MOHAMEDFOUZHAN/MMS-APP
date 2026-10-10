import os
import psycopg2
import sys
sys.stdout.reconfigure(encoding='utf-8')

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

print("Applying storage and dispatch FIFO updates to Supabase...")

# 1. Drop old single-argument overload if it exists to avoid postgREST ambiguity
try:
    cur.execute("DROP FUNCTION IF EXISTS public.create_dispatch_fifo(jsonb);")
    print("Dropped legacy create_dispatch_fifo(jsonb) successfully.")
except Exception as e:
    print(f"Notice on drop: {e}")

# 2. Create updated create_dispatch_fifo
create_dispatch_sql = """
CREATE OR REPLACE FUNCTION public.create_dispatch_fifo(
    p_dispatch JSONB,
    p_idempotency_key TEXT DEFAULT NULL::TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_idempotency_key TEXT;
    v_cached_response JSONB;
    v_dispatch_id BIGINT;
    v_mat_code TEXT;
    v_product_name TEXT;
    v_req_qty NUMERIC(15, 3);
    v_unit TEXT;
    v_location TEXT;
    v_dept TEXT;
    v_date DATE;
    
    v_total_available NUMERIC(15, 3);
    v_remaining_to_dispatch NUMERIC(15, 3);
    v_take NUMERIC(15, 3);
    v_batch RECORD;
    v_allocations JSONB := '[]'::JSONB;
    v_result JSONB;
BEGIN
    v_idempotency_key := COALESCE(p_idempotency_key, p_dispatch->>'idempotency_key');

    -- Idempotency check
    IF v_idempotency_key IS NOT NULL AND TRIM(v_idempotency_key) != '' THEN
        SELECT response INTO v_cached_response 
        FROM idempotency_keys 
        WHERE idempotency_key = v_idempotency_key AND status = 'completed';

        IF v_cached_response IS NOT NULL THEN
            RETURN v_cached_response;
        END IF;
    END IF;

    v_mat_code := TRIM(p_dispatch->>'material_code');
    v_product_name := TRIM(COALESCE(p_dispatch->>'product', v_mat_code));
    v_req_qty := (p_dispatch->>'quantity')::NUMERIC;
    v_unit := TRIM(COALESCE(p_dispatch->>'units', 'kg'));
    v_location := TRIM(COALESCE(p_dispatch->>'location', ''));
    v_dept := TRIM(COALESCE(p_dispatch->>'department', ''));
    v_date := (p_dispatch->>'date')::DATE;

    IF v_req_qty <= 0 THEN
        RAISE EXCEPTION 'Dispatch quantity must be greater than zero.';
    END IF;

    -- Calculate total available stock across active batches with row lock on material
    SELECT COALESCE(SUM(available_quantity), 0)
    INTO v_total_available
    FROM batches
    WHERE (material_code = v_mat_code OR description ILIKE v_product_name)
      AND available_quantity > 0.0001;

    IF v_total_available < v_req_qty THEN
        RAISE EXCEPTION 'Insufficient stock. Requested: % %, Available: % %, Shortage: % %',
            v_req_qty, v_unit, v_total_available, v_unit, (v_req_qty - v_total_available), v_unit;
    END IF;

    -- Insert Dispatches header record
    INSERT INTO dispatches (
        date, material_code, product, quantity, units, location, department
    ) VALUES (
        v_date, v_mat_code, v_product_name, v_req_qty, v_unit, v_location, v_dept
    ) RETURNING id INTO v_dispatch_id;

    -- FIFO Deduction with FOR UPDATE row locking:
    -- Oldest received/created batch first according to factory rule
    v_remaining_to_dispatch := v_req_qty;

    FOR v_batch IN
        SELECT id, batch_no, available_quantity
        FROM batches
        WHERE (material_code = v_mat_code OR description ILIKE v_product_name)
          AND available_quantity > 0.0001
        ORDER BY received_date ASC NULLS LAST, created_at ASC NULLS LAST, id ASC
        FOR UPDATE
    LOOP
        EXIT WHEN v_remaining_to_dispatch <= 0;

        IF v_batch.available_quantity <= v_remaining_to_dispatch THEN
            v_take := v_batch.available_quantity;
            UPDATE batches SET available_quantity = 0 WHERE id = v_batch.id;
            v_remaining_to_dispatch := v_remaining_to_dispatch - v_take;
        ELSE
            v_take := v_remaining_to_dispatch;
            UPDATE batches SET available_quantity = available_quantity - v_take WHERE id = v_batch.id;
            v_remaining_to_dispatch := 0;
        END IF;

        -- Record individual batch allocation
        INSERT INTO dispatch_batches (dispatch_id, batch_no, batch_id, quantity)
        VALUES (v_dispatch_id, v_batch.batch_no, v_batch.id, v_take);

        v_allocations := v_allocations || jsonb_build_object(
            'batch_id', v_batch.id,
            'batch_no', v_batch.batch_no,
            'quantity', v_take
        );
    END LOOP;

    -- Double check no shortage remained
    IF v_remaining_to_dispatch > 0 THEN
        RAISE EXCEPTION 'Insufficient stock. Shortage: % %', v_remaining_to_dispatch, v_unit;
    END IF;

    -- Synchronize Material Master aggregate stock
    UPDATE materials
    SET quantity = GREATEST(0, quantity - v_req_qty),
        last_updated = CURRENT_TIMESTAMP
    WHERE material_code = v_mat_code;

    v_result := jsonb_build_object(
        'success', true,
        'dispatch_id', v_dispatch_id,
        'dispatched_quantity', v_req_qty,
        'allocations', v_allocations
    );

    -- Store idempotency record
    IF v_idempotency_key IS NOT NULL AND TRIM(v_idempotency_key) != '' THEN
        INSERT INTO idempotency_keys (idempotency_key, operation_type, user_id, device_id, status, response)
        VALUES (
            v_idempotency_key, 
            'dispatch_create', 
            auth.uid(), 
            p_dispatch->>'device_id', 
            'completed', 
            v_result
        ) ON CONFLICT (idempotency_key) DO UPDATE SET response = EXCLUDED.response;
    END IF;

    -- Audit log
    INSERT INTO audit_logs (user_id, operation, module, record_id, details)
    VALUES (auth.uid(), 'CREATE', 'dispatches', v_dispatch_id::TEXT, jsonb_build_object('material_code', v_mat_code, 'quantity', v_req_qty));

    -- Recalculate alerts
    PERFORM generate_inventory_alerts();

    RETURN v_result;
END;
$$;
"""
cur.execute(create_dispatch_sql)
print("Updated create_dispatch_fifo function applied.")

# 3. Create updated update_dispatch
update_dispatch_sql = """
CREATE OR REPLACE FUNCTION public.update_dispatch(
    p_dispatch_id BIGINT,
    p_dispatch JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_old_alloc RECORD;
    v_old_mat_code TEXT;
    v_old_qty NUMERIC(15, 3);
    
    v_mat_code TEXT;
    v_product_name TEXT;
    v_req_qty NUMERIC(15, 3);
    v_unit TEXT;
    v_location TEXT;
    v_dept TEXT;
    v_date DATE;
    
    v_total_available NUMERIC(15, 3);
    v_remaining_to_dispatch NUMERIC(15, 3);
    v_take NUMERIC(15, 3);
    v_batch RECORD;
    v_allocations JSONB := '[]'::JSONB;
    v_result JSONB;
BEGIN
    SELECT material_code, quantity INTO v_old_mat_code, v_old_qty 
    FROM dispatches WHERE id = p_dispatch_id FOR UPDATE;
    
    IF v_old_mat_code IS NULL THEN
        RAISE EXCEPTION 'Dispatch with ID % not found', p_dispatch_id;
    END IF;

    -- 1. Restore previous allocations to batches
    FOR v_old_alloc IN SELECT batch_id, quantity FROM dispatch_batches WHERE dispatch_id = p_dispatch_id
    LOOP
        UPDATE batches
        SET available_quantity = available_quantity + v_old_alloc.quantity
        WHERE id = v_old_alloc.batch_id;
    END LOOP;

    -- Restore material master stock
    UPDATE materials
    SET quantity = quantity + v_old_qty,
        last_updated = CURRENT_TIMESTAMP
    WHERE material_code = v_old_mat_code;

    -- Delete old batch allocation rows
    DELETE FROM dispatch_batches WHERE dispatch_id = p_dispatch_id;

    -- 2. Prepare new dispatch values
    v_mat_code := TRIM(COALESCE(p_dispatch->>'material_code', v_old_mat_code));
    v_product_name := TRIM(COALESCE(p_dispatch->>'product', v_mat_code));
    v_req_qty := COALESCE((p_dispatch->>'quantity')::NUMERIC, v_old_qty);
    v_unit := TRIM(COALESCE(p_dispatch->>'units', 'kg'));
    v_location := TRIM(COALESCE(p_dispatch->>'location', ''));
    v_dept := TRIM(COALESCE(p_dispatch->>'department', ''));
    v_date := (COALESCE(p_dispatch->>'date', CURRENT_DATE::TEXT))::DATE;

    IF v_req_qty <= 0 THEN
        RAISE EXCEPTION 'Dispatch quantity must be greater than zero.';
    END IF;

    -- Calculate total available stock across active batches
    SELECT COALESCE(SUM(available_quantity), 0)
    INTO v_total_available
    FROM batches
    WHERE (material_code = v_mat_code OR description ILIKE v_product_name)
      AND available_quantity > 0.0001;

    IF v_total_available < v_req_qty THEN
        RAISE EXCEPTION 'Insufficient stock. Requested: % %, Available: % %, Shortage: % %',
            v_req_qty, v_unit, v_total_available, v_unit, (v_req_qty - v_total_available), v_unit;
    END IF;

    -- 3. FIFO Re-allocation with FOR UPDATE row locking:
    -- Oldest received/created batch first
    v_remaining_to_dispatch := v_req_qty;

    FOR v_batch IN
        SELECT id, batch_no, available_quantity
        FROM batches
        WHERE (material_code = v_mat_code OR description ILIKE v_product_name)
          AND available_quantity > 0.0001
        ORDER BY received_date ASC NULLS LAST, created_at ASC NULLS LAST, id ASC
        FOR UPDATE
    LOOP
        EXIT WHEN v_remaining_to_dispatch <= 0;

        IF v_batch.available_quantity <= v_remaining_to_dispatch THEN
            v_take := v_batch.available_quantity;
            UPDATE batches SET available_quantity = 0 WHERE id = v_batch.id;
            v_remaining_to_dispatch := v_remaining_to_dispatch - v_take;
        ELSE
            v_take := v_remaining_to_dispatch;
            UPDATE batches SET available_quantity = available_quantity - v_take WHERE id = v_batch.id;
            v_remaining_to_dispatch := 0;
        END IF;

        INSERT INTO dispatch_batches (dispatch_id, batch_no, batch_id, quantity)
        VALUES (p_dispatch_id, v_batch.batch_no, v_batch.id, v_take);

        v_allocations := v_allocations || jsonb_build_object(
            'batch_id', v_batch.id,
            'batch_no', v_batch.batch_no,
            'quantity', v_take
        );
    END LOOP;

    -- Synchronize material master stock
    UPDATE materials
    SET quantity = GREATEST(0, quantity - v_req_qty),
        last_updated = CURRENT_TIMESTAMP
    WHERE material_code = v_mat_code;

    -- Update dispatch header
    UPDATE dispatches
    SET date = v_date,
        material_code = v_mat_code,
        product = v_product_name,
        quantity = v_req_qty,
        units = v_unit,
        location = v_location,
        department = v_dept
    WHERE id = p_dispatch_id;

    v_result := jsonb_build_object(
        'success', true,
        'dispatch_id', p_dispatch_id,
        'dispatched_quantity', v_req_qty,
        'allocations', v_allocations
    );

    INSERT INTO audit_logs (user_id, operation, module, record_id, details)
    VALUES (auth.uid(), 'UPDATE', 'dispatches', p_dispatch_id::TEXT, v_result);

    PERFORM generate_inventory_alerts();

    RETURN v_result;
END;
$$;
"""
cur.execute(update_dispatch_sql)
print("Updated update_dispatch function applied.")

# 4. Verify delete_dispatch
delete_dispatch_sql = """
CREATE OR REPLACE FUNCTION public.delete_dispatch(p_dispatch_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_alloc RECORD;
    v_mat_code TEXT;
    v_qty NUMERIC(15, 3);
BEGIN
    SELECT material_code, quantity INTO v_mat_code, v_qty FROM dispatches WHERE id = p_dispatch_id;

    -- Restore exact quantities back to original batches
    FOR v_alloc IN SELECT batch_id, quantity FROM dispatch_batches WHERE dispatch_id = p_dispatch_id
    LOOP
        UPDATE batches
        SET available_quantity = available_quantity + v_alloc.quantity
        WHERE id = v_alloc.batch_id;
    END LOOP;

    -- Restore Material Master aggregate stock
    IF v_mat_code IS NOT NULL AND v_qty IS NOT NULL THEN
        UPDATE materials
        SET quantity = quantity + v_qty,
            last_updated = CURRENT_TIMESTAMP
        WHERE material_code = v_mat_code;
    END IF;

    -- Delete dispatch_batches and dispatch
    DELETE FROM dispatch_batches WHERE dispatch_id = p_dispatch_id;
    DELETE FROM dispatches WHERE id = p_dispatch_id;

    INSERT INTO audit_logs (user_id, operation, module, record_id, details)
    VALUES (auth.uid(), 'DELETE', 'dispatches', p_dispatch_id::TEXT, jsonb_build_object('material_code', v_mat_code, 'quantity', v_qty));

    PERFORM generate_inventory_alerts();

    RETURN true;
END;
$$;
"""
cur.execute(delete_dispatch_sql)
print("Updated delete_dispatch function applied.")

print("\n--- Verifying active routines ---")
cur.execute("""
SELECT proname, pg_get_function_arguments(oid)
FROM pg_proc 
WHERE proname IN ('create_dispatch_fifo', 'update_dispatch', 'delete_dispatch');
""")
for r in cur.fetchall():
    print(f"  â€¢ {r[0]}({r[1]})")

cur.close()
conn.close()
print("\nDatabase update completed successfully!")
