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

print("Applying new Storage -> Dispatch Production Architecture RPCs...")

# 1. Batch number generator function
cur.execute("""
CREATE OR REPLACE FUNCTION public.generate_storage_batch_number(p_date DATE DEFAULT CURRENT_DATE)
RETURNS TEXT
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    RETURN to_char(COALESCE(p_date, CURRENT_DATE), 'DDD');
END;
$$;
""")
print("1. Created generate_storage_batch_number.")

# 2. Server-Side FIFO Storage Dispatch Preview RPC
cur.execute("""
CREATE OR REPLACE FUNCTION public.get_storage_dispatch_preview(
    p_material_id BIGINT DEFAULT NULL,
    p_material_code TEXT DEFAULT NULL,
    p_requested_quantity NUMERIC DEFAULT 0
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mat RECORD;
    v_batch RECORD;
    v_total_available NUMERIC(15, 3) := 0;
    v_remaining NUMERIC(15, 3);
    v_take NUMERIC(15, 3);
    v_allocations JSONB := '[]'::JSONB;
    v_batches JSONB := '[]'::JSONB;
    v_shortage NUMERIC(15, 3) := 0;
    v_is_sufficient BOOLEAN := true;
    v_req_qty NUMERIC(15, 3);
BEGIN
    v_req_qty := GREATEST(0, COALESCE(p_requested_quantity, 0));

    -- Locate material from Material Master
    IF p_material_id IS NOT NULL AND p_material_id > 0 THEN
        SELECT * INTO v_mat FROM materials WHERE id = p_material_id;
    ELSIF p_material_code IS NOT NULL AND TRIM(p_material_code) != '' THEN
        SELECT * INTO v_mat FROM materials WHERE material_code = normalize_code(p_material_code);
    END IF;

    IF v_mat.id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'message', 'Material not found in Material Master. Please register material first.'
        );
    END IF;

    -- Query active batches for this material in strict FIFO order:
    -- Oldest batch_date/received_date first, then created_at, then id
    FOR v_batch IN
        SELECT 
            b.id,
            b.batch_no,
            b.batch_date,
            b.received_date,
            b.expiry_date,
            b.available_quantity,
            b.received_quantity,
            b.uom,
            b.department,
            b.grade,
            (b.expiry_date IS NOT NULL AND b.expiry_date < CURRENT_DATE) AS is_expired
        FROM batches b
        WHERE (b.material_id = v_mat.id OR b.product_id = v_mat.id OR b.material_code = v_mat.material_code)
          AND b.available_quantity > 0.0001
        ORDER BY 
            COALESCE(b.batch_date, b.received_date, b.created_at::date) ASC,
            b.created_at ASC,
            b.id ASC
    LOOP
        -- Add to total available only if not expired
        IF NOT v_batch.is_expired THEN
            v_total_available := v_total_available + v_batch.available_quantity;
        END IF;

        v_batches := v_batches || jsonb_build_object(
            'batch_id', v_batch.id,
            'batch_no', v_batch.batch_no,
            'batch_date', COALESCE(v_batch.batch_date, v_batch.received_date),
            'expiry_date', v_batch.expiry_date,
            'available_quantity', v_batch.available_quantity,
            'received_quantity', v_batch.received_quantity,
            'uom', v_batch.uom,
            'department', v_batch.department,
            'grade', v_batch.grade,
            'is_expired', v_batch.is_expired
        );
    END LOOP;

    -- Compute FIFO allocation if requested quantity > 0
    IF v_req_qty > 0 THEN
        IF v_req_qty > v_total_available THEN
            v_shortage := v_req_qty - v_total_available;
            v_is_sufficient := false;
        END IF;

        v_remaining := v_req_qty;
        FOR v_batch IN
            SELECT 
                b.id,
                b.batch_no,
                b.batch_date,
                b.received_date,
                b.available_quantity,
                b.uom
            FROM batches b
            WHERE (b.material_id = v_mat.id OR b.product_id = v_mat.id OR b.material_code = v_mat.material_code)
              AND b.available_quantity > 0.0001
              AND (b.expiry_date IS NULL OR b.expiry_date >= CURRENT_DATE)
            ORDER BY 
                COALESCE(b.batch_date, b.received_date, b.created_at::date) ASC,
                b.created_at ASC,
                b.id ASC
        LOOP
            EXIT WHEN v_remaining <= 0;

            IF v_batch.available_quantity <= v_remaining THEN
                v_take := v_batch.available_quantity;
                v_remaining := v_remaining - v_take;
            ELSE
                v_take := v_remaining;
                v_remaining := 0;
            END IF;

            v_allocations := v_allocations || jsonb_build_object(
                'batch_id', v_batch.id,
                'batch_no', v_batch.batch_no,
                'batch_date', COALESCE(v_batch.batch_date, v_batch.received_date),
                'available_before', v_batch.available_quantity,
                'allocated_quantity', v_take,
                'batch_remaining', (v_batch.available_quantity - v_take),
                'uom', v_batch.uom
            );
        END LOOP;
    END IF;

    RETURN jsonb_build_object(
        'success', true,
        'material_id', v_mat.id,
        'material_code', v_mat.material_code,
        'description', v_mat.description,
        'category', v_mat.category,
        'grade', v_mat.grade,
        'uom', v_mat.unit,
        'total_available', v_total_available,
        'requested_quantity', v_req_qty,
        'shortage', v_shortage,
        'is_sufficient', v_is_sufficient,
        'allocations', v_allocations,
        'batches', v_batches
    );
END;
$$;
""")
print("2. Created get_storage_dispatch_preview.")

# 3. New Atomic create_dispatch_fifo RPC
cur.execute("""
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
    v_mat RECORD;
    v_mat_id BIGINT;
    v_mat_code TEXT;
    v_product_name TEXT;
    v_category TEXT;
    v_grade TEXT;
    v_req_qty NUMERIC(15, 3);
    v_unit TEXT;
    v_location TEXT;
    v_dept TEXT;
    v_remarks TEXT;
    v_date DATE;
    v_created_by UUID;
    
    v_total_available NUMERIC(15, 3) := 0;
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

    -- 1. Validate Material Identity from Material Master
    v_mat_id := (p_dispatch->>'material_id')::BIGINT;
    v_mat_code := normalize_code(p_dispatch->>'material_code');

    IF v_mat_id IS NOT NULL AND v_mat_id > 0 THEN
        SELECT * INTO v_mat FROM materials WHERE id = v_mat_id;
    ELSIF v_mat_code IS NOT NULL AND TRIM(v_mat_code) != '' THEN
        SELECT * INTO v_mat FROM materials WHERE material_code = v_mat_code;
    END IF;

    IF v_mat.id IS NULL THEN
        RAISE EXCEPTION 'Material not found in Material Master. Cannot dispatch unregistered material.';
    END IF;

    v_mat_id := v_mat.id;
    v_mat_code := v_mat.material_code;
    v_product_name := COALESCE(NULLIF(TRIM(p_dispatch->>'product'), ''), v_mat.description);
    v_category := COALESCE(NULLIF(TRIM(p_dispatch->>'category'), ''), v_mat.category);
    v_grade := COALESCE(NULLIF(TRIM(p_dispatch->>'grade'), ''), v_mat.grade);
    v_req_qty := (p_dispatch->>'quantity')::NUMERIC;
    v_unit := normalize_business_text(COALESCE(p_dispatch->>'units', v_mat.unit, 'kg'));
    v_location := normalize_business_text(COALESCE(p_dispatch->>'location', ''));
    v_dept := normalize_business_text(COALESCE(p_dispatch->>'department', 'Dispatch'));
    v_remarks := NULLIF(TRIM(COALESCE(p_dispatch->>'remarks', '')), '');
    v_date := (p_dispatch->>'date')::DATE;
    v_created_by := auth.uid();

    IF v_req_qty <= 0 THEN
        RAISE EXCEPTION 'Dispatch quantity must be greater than zero.';
    END IF;

    -- 2. Concurrency-Safe Row Lock on Eligible Storage Batches (Strict FIFO Order)
    -- Exclude expired batches (expiry_date < CURRENT_DATE)
    -- Row lock FOR UPDATE guarantees no two transactions can oversell
    SELECT COALESCE(SUM(available_quantity), 0)
    INTO v_total_available
    FROM batches
    WHERE (material_id = v_mat_id OR product_id = v_mat_id OR material_code = v_mat_code)
      AND available_quantity > 0.0001
      AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE);

    IF v_total_available < v_req_qty THEN
        RAISE EXCEPTION 'Insufficient Storage Stock. Requested: % %, Available: % %, Shortage: % %',
            v_req_qty, v_unit, v_total_available, v_unit, (v_req_qty - v_total_available), v_unit;
    END IF;

    -- 3. Insert Dispatches Header Record
    INSERT INTO dispatches (
        date, material_id, material_code, product, category, grade,
        quantity, units, location, department, remarks, created_by
    ) VALUES (
        v_date, v_mat_id, v_mat_code, v_product_name, v_category, v_grade,
        v_req_qty, v_unit, v_location, v_dept, v_remarks, v_created_by
    ) RETURNING id INTO v_dispatch_id;

    -- 4. FIFO Deduction with Row-Level Locks
    v_remaining_to_dispatch := v_req_qty;

    FOR v_batch IN
        SELECT id, batch_no, batch_date, received_date, available_quantity, uom
        FROM batches
        WHERE (material_id = v_mat_id OR product_id = v_mat_id OR material_code = v_mat_code)
          AND available_quantity > 0.0001
          AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE)
        ORDER BY 
            COALESCE(batch_date, received_date, created_at::date) ASC,
            created_at ASC,
            id ASC
        FOR UPDATE
    LOOP
        EXIT WHEN v_remaining_to_dispatch <= 0;

        IF v_batch.available_quantity <= v_remaining_to_dispatch THEN
            v_take := v_batch.available_quantity;
            UPDATE batches 
            SET available_quantity = 0,
                updated_at = CURRENT_TIMESTAMP 
            WHERE id = v_batch.id;

            v_remaining_to_dispatch := v_remaining_to_dispatch - v_take;
        ELSE
            v_take := v_remaining_to_dispatch;
            UPDATE batches 
            SET available_quantity = available_quantity - v_take,
                updated_at = CURRENT_TIMESTAMP 
            WHERE id = v_batch.id;

            v_remaining_to_dispatch := 0;
        END IF;

        -- Record individual batch allocation permanently
        INSERT INTO dispatch_batches (
            dispatch_id, batch_no, batch_id, quantity, uom, batch_date
        ) VALUES (
            v_dispatch_id, v_batch.batch_no, v_batch.id, v_take, v_unit, COALESCE(v_batch.batch_date, v_batch.received_date)
        );

        v_allocations := v_allocations || jsonb_build_object(
            'batch_id', v_batch.id,
            'batch_no', v_batch.batch_no,
            'batch_date', COALESCE(v_batch.batch_date, v_batch.received_date),
            'quantity', v_take,
            'uom', v_unit
        );
    END LOOP;

    -- Double-check shortage
    IF v_remaining_to_dispatch > 0 THEN
        RAISE EXCEPTION 'Insufficient stock during FIFO execution. Shortage: % %', v_remaining_to_dispatch, v_unit;
    END IF;

    -- NOTE: By business requirement Section 23:
    -- Dispatch MUST NOT modify materials.quantity!
    -- Storage batches (batches.available_quantity) is the source of truth for Dispatch stock.

    v_result := jsonb_build_object(
        'success', true,
        'dispatch_id', v_dispatch_id,
        'material_code', v_mat_code,
        'dispatched_quantity', v_req_qty,
        'units', v_unit,
        'allocations', v_allocations
    );

    -- Store idempotency record
    IF v_idempotency_key IS NOT NULL AND TRIM(v_idempotency_key) != '' THEN
        INSERT INTO idempotency_keys (idempotency_key, operation_type, user_id, device_id, status, response)
        VALUES (
            v_idempotency_key, 
            'dispatch_create', 
            v_created_by, 
            p_dispatch->>'device_id', 
            'completed', 
            v_result
        ) ON CONFLICT (idempotency_key) DO UPDATE SET response = EXCLUDED.response;
    END IF;

    -- Audit log
    INSERT INTO audit_logs (user_id, operation, module, record_id, details)
    VALUES (
        v_created_by, 
        'CREATE', 
        'dispatches', 
        v_dispatch_id::TEXT, 
        jsonb_build_object('material_code', v_mat_code, 'quantity', v_req_qty, 'allocations', v_allocations)
    );

    PERFORM generate_inventory_alerts();

    RETURN v_result;
END;
$$;
""")
print("3. Created create_dispatch_fifo.")

# 4. New Atomic update_dispatch RPC
cur.execute("""
CREATE OR REPLACE FUNCTION public.update_dispatch(
    p_dispatch_id BIGINT,
    p_dispatch JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_old_dispatch RECORD;
    v_old_alloc RECORD;
    v_mat RECORD;
    v_mat_id BIGINT;
    v_mat_code TEXT;
    v_product_name TEXT;
    v_category TEXT;
    v_grade TEXT;
    v_req_qty NUMERIC(15, 3);
    v_unit TEXT;
    v_location TEXT;
    v_dept TEXT;
    v_remarks TEXT;
    v_date DATE;
    
    v_total_available NUMERIC(15, 3) := 0;
    v_remaining_to_dispatch NUMERIC(15, 3);
    v_take NUMERIC(15, 3);
    v_batch RECORD;
    v_allocations JSONB := '[]'::JSONB;
    v_result JSONB;
BEGIN
    -- 1. Lock existing dispatch header
    SELECT * INTO v_old_dispatch FROM dispatches WHERE id = p_dispatch_id FOR UPDATE;
    
    IF v_old_dispatch.id IS NULL THEN
        RAISE EXCEPTION 'Dispatch with ID % not found', p_dispatch_id;
    END IF;

    -- 2. Reverse previous allocations: restore quantities back to batches
    FOR v_old_alloc IN 
        SELECT batch_id, quantity 
        FROM dispatch_batches 
        WHERE dispatch_id = p_dispatch_id 
        FOR UPDATE
    LOOP
        UPDATE batches
        SET available_quantity = available_quantity + v_old_alloc.quantity,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_old_alloc.batch_id;
    END LOOP;

    -- Delete old allocation rows
    DELETE FROM dispatch_batches WHERE dispatch_id = p_dispatch_id;

    -- 3. Resolve target material
    v_mat_id := (COALESCE(p_dispatch->>'material_id', v_old_dispatch.material_id::TEXT))::BIGINT;
    v_mat_code := normalize_code(COALESCE(p_dispatch->>'material_code', v_old_dispatch.material_code));

    IF v_mat_id IS NOT NULL AND v_mat_id > 0 THEN
        SELECT * INTO v_mat FROM materials WHERE id = v_mat_id;
    ELSIF v_mat_code IS NOT NULL AND TRIM(v_mat_code) != '' THEN
        SELECT * INTO v_mat FROM materials WHERE material_code = v_mat_code;
    END IF;

    IF v_mat.id IS NULL THEN
        RAISE EXCEPTION 'Material not found in Material Master.';
    END IF;

    v_mat_id := v_mat.id;
    v_mat_code := v_mat.material_code;
    v_product_name := COALESCE(NULLIF(TRIM(p_dispatch->>'product'), ''), v_old_dispatch.product, v_mat.description);
    v_category := COALESCE(NULLIF(TRIM(p_dispatch->>'category'), ''), v_old_dispatch.category, v_mat.category);
    v_grade := COALESCE(NULLIF(TRIM(p_dispatch->>'grade'), ''), v_old_dispatch.grade, v_mat.grade);
    v_req_qty := COALESCE((p_dispatch->>'quantity')::NUMERIC, v_old_dispatch.quantity);
    v_unit := normalize_business_text(COALESCE(p_dispatch->>'units', v_old_dispatch.units, 'kg'));
    v_location := normalize_business_text(COALESCE(p_dispatch->>'location', v_old_dispatch.location, ''));
    v_dept := normalize_business_text(COALESCE(p_dispatch->>'department', v_old_dispatch.department, 'Dispatch'));
    v_remarks := COALESCE(NULLIF(TRIM(p_dispatch->>'remarks'), ''), v_old_dispatch.remarks);
    v_date := (COALESCE(p_dispatch->>'date', v_old_dispatch.date::TEXT))::DATE;

    IF v_req_qty <= 0 THEN
        RAISE EXCEPTION 'Dispatch quantity must be greater than zero.';
    END IF;

    -- 4. Calculate total available stock across active batches
    SELECT COALESCE(SUM(available_quantity), 0)
    INTO v_total_available
    FROM batches
    WHERE (material_id = v_mat_id OR product_id = v_mat_id OR material_code = v_mat_code)
      AND available_quantity > 0.0001
      AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE);

    IF v_total_available < v_req_qty THEN
        RAISE EXCEPTION 'Insufficient Storage Stock. Requested: % %, Available: % %, Shortage: % %',
            v_req_qty, v_unit, v_total_available, v_unit, (v_req_qty - v_total_available), v_unit;
    END IF;

    -- 5. FIFO Re-allocation with FOR UPDATE row locking
    v_remaining_to_dispatch := v_req_qty;

    FOR v_batch IN
        SELECT id, batch_no, batch_date, received_date, available_quantity
        FROM batches
        WHERE (material_id = v_mat_id OR product_id = v_mat_id OR material_code = v_mat_code)
          AND available_quantity > 0.0001
          AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE)
        ORDER BY 
            COALESCE(batch_date, received_date, created_at::date) ASC,
            created_at ASC,
            id ASC
        FOR UPDATE
    LOOP
        EXIT WHEN v_remaining_to_dispatch <= 0;

        IF v_batch.available_quantity <= v_remaining_to_dispatch THEN
            v_take := v_batch.available_quantity;
            UPDATE batches 
            SET available_quantity = 0,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_batch.id;

            v_remaining_to_dispatch := v_remaining_to_dispatch - v_take;
        ELSE
            v_take := v_remaining_to_dispatch;
            UPDATE batches 
            SET available_quantity = available_quantity - v_take,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_batch.id;

            v_remaining_to_dispatch := 0;
        END IF;

        INSERT INTO dispatch_batches (
            dispatch_id, batch_no, batch_id, quantity, uom, batch_date
        ) VALUES (
            p_dispatch_id, v_batch.batch_no, v_batch.id, v_take, v_unit, COALESCE(v_batch.batch_date, v_batch.received_date)
        );

        v_allocations := v_allocations || jsonb_build_object(
            'batch_id', v_batch.id,
            'batch_no', v_batch.batch_no,
            'batch_date', COALESCE(v_batch.batch_date, v_batch.received_date),
            'quantity', v_take,
            'uom', v_unit
        );
    END LOOP;

    -- 6. Update dispatch header
    UPDATE dispatches
    SET date = v_date,
        material_id = v_mat_id,
        material_code = v_mat_code,
        product = v_product_name,
        category = v_category,
        grade = v_grade,
        quantity = v_req_qty,
        units = v_unit,
        location = v_location,
        department = v_dept,
        remarks = v_remarks,
        updated_at = CURRENT_TIMESTAMP
    WHERE id = p_dispatch_id;

    v_result := jsonb_build_object(
        'success', true,
        'dispatch_id', p_dispatch_id,
        'material_code', v_mat_code,
        'dispatched_quantity', v_req_qty,
        'allocations', v_allocations
    );

    INSERT INTO audit_logs (user_id, operation, module, record_id, details)
    VALUES (auth.uid(), 'UPDATE', 'dispatches', p_dispatch_id::TEXT, v_result);

    PERFORM generate_inventory_alerts();

    RETURN v_result;
END;
$$;
""")
print("4. Created update_dispatch.")

# 5. New Atomic delete_dispatch RPC
cur.execute("""
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
    SELECT material_code, quantity INTO v_mat_code, v_qty 
    FROM dispatches 
    WHERE id = p_dispatch_id 
    FOR UPDATE;

    IF v_mat_code IS NULL THEN
        RAISE EXCEPTION 'Dispatch with ID % not found', p_dispatch_id;
    END IF;

    -- Restore exact quantities back to original storage batches
    FOR v_alloc IN 
        SELECT batch_id, quantity 
        FROM dispatch_batches 
        WHERE dispatch_id = p_dispatch_id 
        FOR UPDATE
    LOOP
        UPDATE batches
        SET available_quantity = available_quantity + v_alloc.quantity,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = v_alloc.batch_id;
    END LOOP;

    -- NOTE: materials.quantity is NOT modified

    -- Delete dispatch_batches and dispatch
    DELETE FROM dispatch_batches WHERE dispatch_id = p_dispatch_id;
    DELETE FROM dispatches WHERE id = p_dispatch_id;

    INSERT INTO audit_logs (user_id, operation, module, record_id, details)
    VALUES (
        auth.uid(), 
        'DELETE', 
        'dispatches', 
        p_dispatch_id::TEXT, 
        jsonb_build_object('material_code', v_mat_code, 'quantity', v_qty)
    );

    PERFORM generate_inventory_alerts();

    RETURN true;
END;
$$;
""")
print("5. Created delete_dispatch.")

cur.close()
conn.close()
print("All RPCs applied and verified in Supabase successfully!")
