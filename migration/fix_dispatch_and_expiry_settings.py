import os
import psycopg2

def run_migration():
    print("Connecting to Supabase PostgreSQL...")
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

    # 1. Create type mms_dispatch_alloc_item if not exists
    print("1. Creating composite type mms_dispatch_alloc_item...")
    cur.execute("""
        DO $do$
        BEGIN
            IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'mms_dispatch_alloc_item') THEN
                CREATE TYPE public.mms_dispatch_alloc_item AS (
                    ord INT,
                    batch_id BIGINT,
                    batch_no TEXT,
                    batch_date DATE,
                    avail_before NUMERIC(15, 3),
                    take_qty NUMERIC(15, 3),
                    ret_qty NUMERIC(15, 3),
                    net_take NUMERIC(15, 3),
                    uom TEXT
                );
            END IF;
        END $do$;
    """)

    # 2. Update get_storage_dispatch_preview without temporary tables or unconditioned DELETE
    print("2. Updating get_storage_dispatch_preview...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.get_storage_dispatch_preview(
        p_material_code text,
        p_requested_quantity numeric DEFAULT 0.0,
        p_return_quantity numeric DEFAULT 0.0
    )
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $func$
    DECLARE
        v_clean_code TEXT;
        v_clean_name TEXT;
        v_uom TEXT := 'kg';
        v_grade TEXT := 'STANDARD';
        v_category TEXT := 'Finished Goods';
        v_req_qty NUMERIC(15, 3);
        v_ret_qty NUMERIC(15, 3);
        v_net_dispatch NUMERIC(15, 3);
        v_total_available NUMERIC(15, 3) := 0;
        v_shortage NUMERIC(15, 3) := 0;
        v_is_sufficient BOOLEAN := true;
        v_batches JSONB := '[]'::jsonb;
        v_allocations JSONB := '[]'::jsonb;
        v_batch RECORD;
        v_rem_to_alloc NUMERIC(15, 3);
        v_take NUMERIC(15, 3);
        v_alloc_items public.mms_dispatch_alloc_item[];
        v_item public.mms_dispatch_alloc_item;
        v_idx INT := 0;
        v_rem_return NUMERIC(15, 3);
        v_ret_take NUMERIC(15, 3);
        i INT;
    BEGIN
        v_clean_code := TRIM(p_material_code);
        v_req_qty := GREATEST(0, ROUND(COALESCE(p_requested_quantity, 0), 3));
        v_ret_qty := GREATEST(0, ROUND(COALESCE(p_return_quantity, 0), 3));
        
        IF v_ret_qty > v_req_qty THEN
            RETURN jsonb_build_object(
                'success', false,
                'message', 'Return Quantity cannot exceed Dispatch Quantity.'
            );
        END IF;

        v_net_dispatch := v_req_qty - v_ret_qty;

        -- Find product metadata from storage_products or batches
        SELECT product_name, uom, grade, category
        INTO v_clean_name, v_uom, v_grade, v_category
        FROM public.storage_products
        WHERE LOWER(TRIM(product_code)) = LOWER(v_clean_code);

        IF v_clean_name IS NULL OR v_clean_name = '' THEN
            SELECT description, uom, grade, category
            INTO v_clean_name, v_uom, v_grade, v_category
            FROM public.batches
            WHERE LOWER(TRIM(material_code)) = LOWER(v_clean_code)
            ORDER BY id DESC LIMIT 1;
        END IF;

        -- Gather all eligible active batches in FIFO order
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
            FROM public.batches b
            WHERE LOWER(TRIM(b.material_code)) = LOWER(v_clean_code)
              AND b.available_quantity > 0.0001
            ORDER BY 
                COALESCE(b.batch_date, b.received_date, b.created_at::date) ASC,
                b.created_at ASC,
                b.id ASC
        LOOP
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

        -- Compute FIFO allocation simulation in memory
        IF v_req_qty > 0 THEN
            IF v_req_qty > v_total_available THEN
                v_shortage := v_req_qty - v_total_available;
                v_is_sufficient := false;
            END IF;

            v_rem_to_alloc := v_req_qty;

            FOR v_batch IN
                SELECT b.id, b.batch_no, COALESCE(b.batch_date, b.received_date) AS b_date, b.available_quantity, b.uom
                FROM public.batches b
                WHERE LOWER(TRIM(b.material_code)) = LOWER(v_clean_code)
                  AND b.available_quantity > 0.0001
                  AND (b.expiry_date IS NULL OR b.expiry_date >= CURRENT_DATE)
                ORDER BY 
                    COALESCE(b.batch_date, b.received_date, b.created_at::date) ASC,
                    b.created_at ASC,
                    b.id ASC
            LOOP
                EXIT WHEN v_rem_to_alloc <= 0;

                IF v_batch.available_quantity <= v_rem_to_alloc THEN
                    v_take := v_batch.available_quantity;
                    v_rem_to_alloc := v_rem_to_alloc - v_take;
                ELSE
                    v_take := v_rem_to_alloc;
                    v_rem_to_alloc := 0;
                END IF;

                v_idx := v_idx + 1;
                v_item.ord := v_idx;
                v_item.batch_id := v_batch.id;
                v_item.batch_no := v_batch.batch_no;
                v_item.batch_date := v_batch.b_date;
                v_item.avail_before := v_batch.available_quantity;
                v_item.take_qty := v_take;
                v_item.ret_qty := 0;
                v_item.net_take := v_take;
                v_item.uom := v_batch.uom;

                v_alloc_items := array_append(v_alloc_items, v_item);
            END LOOP;

            -- Apply return quantity in reverse order (LIFO of allocation)
            IF v_ret_qty > 0 AND v_alloc_items IS NOT NULL THEN
                v_rem_return := v_ret_qty;
                FOR i IN REVERSE array_length(v_alloc_items, 1)..1 LOOP
                    EXIT WHEN v_rem_return <= 0;
                    v_ret_take := LEAST(v_alloc_items[i].take_qty, v_rem_return);
                    v_alloc_items[i].ret_qty := v_ret_take;
                    v_alloc_items[i].net_take := v_alloc_items[i].take_qty - v_ret_take;
                    v_rem_return := v_rem_return - v_ret_take;
                END LOOP;
            END IF;

            -- Build allocations jsonb
            IF v_alloc_items IS NOT NULL THEN
                FOR i IN 1..array_length(v_alloc_items, 1) LOOP
                    v_allocations := v_allocations || jsonb_build_object(
                        'batch_id', v_alloc_items[i].batch_id,
                        'batch_no', v_alloc_items[i].batch_no,
                        'batch_date', v_alloc_items[i].batch_date,
                        'available_before', v_alloc_items[i].avail_before,
                        'allocated_quantity', v_alloc_items[i].take_qty,
                        'returned_quantity', v_alloc_items[i].ret_qty,
                        'net_deduction', v_alloc_items[i].net_take,
                        'batch_remaining', (v_alloc_items[i].avail_before - v_alloc_items[i].net_take),
                        'uom', v_alloc_items[i].uom
                    );
                END LOOP;
            END IF;
        END IF;

        RETURN jsonb_build_object(
            'success', true,
            'product_code', v_clean_code,
            'product_name', COALESCE(v_clean_name, v_clean_code),
            'category', COALESCE(v_category, 'Finished Goods'),
            'grade', COALESCE(v_grade, 'STANDARD'),
            'uom', COALESCE(v_uom, 'kg'),
            'total_available', v_total_available,
            'requested_quantity', v_req_qty,
            'return_quantity', v_ret_qty,
            'net_dispatch', v_net_dispatch,
            'remaining_storage', GREATEST(0, v_total_available - v_net_dispatch),
            'shortage', v_shortage,
            'is_sufficient', v_is_sufficient,
            'allocations', v_allocations,
            'batches', v_batches
        );
    END;
    $func$;
    """)

    # 3. Update create_dispatch_fifo without temporary tables or unconditioned DELETE
    print("3. Updating create_dispatch_fifo...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.create_dispatch_fifo(
        p_dispatch jsonb,
        p_idempotency_key text DEFAULT NULL::text
    )
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $func$
    DECLARE
        v_existing_response JSONB;
        v_idempotency_key TEXT;
        v_dispatch_id BIGINT;
        v_storage_prod_id BIGINT;
        v_prod_code TEXT;
        v_prod_name TEXT;
        v_category TEXT;
        v_grade TEXT;
        v_location TEXT;
        v_dept TEXT;
        v_remarks TEXT;
        v_date DATE;
        v_unit TEXT;
        v_req_qty NUMERIC(15, 3);
        v_ret_qty NUMERIC(15, 3);
        v_net_qty NUMERIC(15, 3);
        v_total_available NUMERIC(15, 3) := 0;
        v_rem_to_alloc NUMERIC(15, 3);
        v_take NUMERIC(15, 3);
        v_alloc_items public.mms_dispatch_alloc_item[];
        v_item public.mms_dispatch_alloc_item;
        v_idx INT := 0;
        v_rem_return NUMERIC(15, 3);
        v_ret_take NUMERIC(15, 3);
        v_allocations JSONB := '[]'::jsonb;
        v_result JSONB;
        v_created_by UUID;
        v_batch RECORD;
        i INT;
    BEGIN
        v_idempotency_key := NULLIF(TRIM(p_idempotency_key), '');

        -- Check idempotency
        IF v_idempotency_key IS NOT NULL THEN
            SELECT response INTO v_existing_response
            FROM public.idempotency_keys
            WHERE idempotency_key = v_idempotency_key;

            IF v_existing_response IS NOT NULL THEN
                RETURN v_existing_response;
            END IF;
        END IF;

        -- Extract and sanitize payload
        v_prod_code := TRIM(COALESCE(p_dispatch->>'material_code', ''));
        IF v_prod_code = '' THEN
            RAISE EXCEPTION 'Product code is required for Dispatch.';
        END IF;

        v_req_qty := ROUND(COALESCE((p_dispatch->>'quantity')::NUMERIC, 0), 3);
        v_ret_qty := ROUND(COALESCE((p_dispatch->>'return_quantity')::NUMERIC, 0), 3);

        IF v_req_qty <= 0 THEN
            RAISE EXCEPTION 'Dispatch quantity must be greater than zero.';
        END IF;

        IF v_ret_qty < 0 THEN
            RAISE EXCEPTION 'Return quantity cannot be negative.';
        END IF;

        IF v_ret_qty > v_req_qty THEN
            RAISE EXCEPTION 'Return quantity (%) cannot exceed Dispatch quantity (%).', v_ret_qty, v_req_qty;
        END IF;

        v_net_qty := v_req_qty - v_ret_qty;

        -- Resolve storage product identity
        SELECT id, product_name, uom, grade, category 
        INTO v_storage_prod_id, v_prod_name, v_unit, v_grade, v_category
        FROM public.storage_products
        WHERE LOWER(TRIM(product_code)) = LOWER(v_prod_code);

        v_prod_name := COALESCE(NULLIF(TRIM(p_dispatch->>'product'), ''), v_prod_name, v_prod_code);
        v_unit := COALESCE(NULLIF(TRIM(p_dispatch->>'units'), ''), v_unit, 'kg');
        v_category := COALESCE(NULLIF(TRIM(p_dispatch->>'category'), ''), v_category, 'Finished Goods');
        v_grade := COALESCE(NULLIF(TRIM(p_dispatch->>'grade'), ''), v_grade, 'STANDARD');
        v_location := COALESCE(NULLIF(TRIM(p_dispatch->>'location'), ''), '');
        v_dept := COALESCE(NULLIF(TRIM(p_dispatch->>'department'), ''), 'Dispatch');
        v_remarks := NULLIF(TRIM(COALESCE(p_dispatch->>'remarks', '')), '');
        v_date := COALESCE((p_dispatch->>'date')::DATE, CURRENT_DATE);
        v_created_by := auth.uid();

        -- 1. Concurrency-Safe Row Lock on Eligible Storage Batches in strict FIFO Order
        SELECT COALESCE(SUM(available_quantity), 0)
        INTO v_total_available
        FROM public.batches
        WHERE LOWER(TRIM(material_code)) = LOWER(v_prod_code)
          AND available_quantity > 0.0001
          AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE);

        IF v_total_available < v_req_qty THEN
            RAISE EXCEPTION 'Insufficient Storage Stock. Requested: % %, Available: % %, Shortage: % %',
                v_req_qty, v_unit, v_total_available, v_unit, (v_req_qty - v_total_available), v_unit;
        END IF;

        -- 2. Insert Dispatches Header Record
        INSERT INTO public.dispatches (
            date, storage_product_id, material_code, product, category, grade,
            quantity, return_quantity, net_quantity, units, location, department, remarks, created_by, created_at, updated_at
        ) VALUES (
            v_date, v_storage_prod_id, v_prod_code, v_prod_name, v_category, v_grade,
            v_req_qty, v_ret_qty, v_net_qty, v_unit, v_location, v_dept, v_remarks, v_created_by, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        ) RETURNING id INTO v_dispatch_id;

        -- 3. Calculate FIFO Allocation in Memory (No Temp Tables!)
        v_rem_to_alloc := v_req_qty;

        FOR v_batch IN
            SELECT id, batch_no, COALESCE(batch_date, received_date) AS b_date, available_quantity, uom
            FROM public.batches
            WHERE LOWER(TRIM(material_code)) = LOWER(v_prod_code)
              AND available_quantity > 0.0001
              AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE)
            ORDER BY 
                COALESCE(batch_date, received_date, created_at::date) ASC,
                created_at ASC,
                id ASC
            FOR UPDATE
        LOOP
            EXIT WHEN v_rem_to_alloc <= 0;

            IF v_batch.available_quantity <= v_rem_to_alloc THEN
                v_take := v_batch.available_quantity;
                v_rem_to_alloc := v_rem_to_alloc - v_take;
            ELSE
                v_take := v_rem_to_alloc;
                v_rem_to_alloc := 0;
            END IF;

            v_idx := v_idx + 1;
            v_item.ord := v_idx;
            v_item.batch_id := v_batch.id;
            v_item.batch_no := v_batch.batch_no;
            v_item.batch_date := v_batch.b_date;
            v_item.avail_before := v_batch.available_quantity;
            v_item.take_qty := v_take;
            v_item.ret_qty := 0;
            v_item.net_take := v_take;
            v_item.uom := v_batch.uom;

            v_alloc_items := array_append(v_alloc_items, v_item);
        END LOOP;

        IF v_rem_to_alloc > 0 THEN
            RAISE EXCEPTION 'Insufficient stock during FIFO execution. Shortage: % %', v_rem_to_alloc, v_unit;
        END IF;

        -- 4. Apply Return Quantity in Reverse Order (LIFO of allocation)
        IF v_ret_qty > 0 AND v_alloc_items IS NOT NULL THEN
            v_rem_return := v_ret_qty;
            FOR i IN REVERSE array_length(v_alloc_items, 1)..1 LOOP
                EXIT WHEN v_rem_return <= 0;
                v_ret_take := LEAST(v_alloc_items[i].take_qty, v_rem_return);
                v_alloc_items[i].ret_qty := v_ret_take;
                v_alloc_items[i].net_take := v_alloc_items[i].take_qty - v_ret_take;
                v_rem_return := v_rem_return - v_ret_take;
            END LOOP;
        END IF;

        -- 5. Commit Batch Deductions and Record dispatch_batches
        -- NOTE: Batches are NEVER deleted when available_quantity reaches 0!
        -- They remain in history with available_quantity = 0.
        IF v_alloc_items IS NOT NULL THEN
            FOR i IN 1..array_length(v_alloc_items, 1) LOOP
                UPDATE public.batches
                SET available_quantity = available_quantity - v_alloc_items[i].net_take,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = v_alloc_items[i].batch_id;

                INSERT INTO public.dispatch_batches (
                    dispatch_id, batch_no, batch_id, quantity, returned_quantity, net_quantity, uom, batch_date
                ) VALUES (
                    v_dispatch_id, 
                    v_alloc_items[i].batch_no, 
                    v_alloc_items[i].batch_id, 
                    v_alloc_items[i].take_qty, 
                    v_alloc_items[i].ret_qty, 
                    v_alloc_items[i].net_take, 
                    v_alloc_items[i].uom, 
                    v_alloc_items[i].batch_date
                );

                v_allocations := v_allocations || jsonb_build_object(
                    'batch_id', v_alloc_items[i].batch_id,
                    'batch_no', v_alloc_items[i].batch_no,
                    'batch_date', v_alloc_items[i].batch_date,
                    'quantity', v_alloc_items[i].take_qty,
                    'returned_quantity', v_alloc_items[i].ret_qty,
                    'net_quantity', v_alloc_items[i].net_take,
                    'uom', v_alloc_items[i].uom
                );
            END LOOP;
        END IF;

        v_result := jsonb_build_object(
            'success', true,
            'dispatch_id', v_dispatch_id,
            'material_code', v_prod_code,
            'dispatched_quantity', v_req_qty,
            'return_quantity', v_ret_qty,
            'net_quantity', v_net_qty,
            'units', v_unit,
            'allocations', v_allocations
        );

        -- Store idempotency record
        IF v_idempotency_key IS NOT NULL AND TRIM(v_idempotency_key) != '' THEN
            INSERT INTO public.idempotency_keys (idempotency_key, operation_type, user_id, device_id, status, response)
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
        INSERT INTO public.audit_logs (user_id, operation, module, record_id, details)
        VALUES (
            v_created_by, 
            'CREATE', 
            'dispatches', 
            v_dispatch_id::TEXT, 
            jsonb_build_object('product_code', v_prod_code, 'quantity', v_req_qty, 'return', v_ret_qty, 'net', v_net_qty)
        );

        RETURN v_result;
    END;
    $func$;
    """)

    # 4. Update update_dispatch without temporary tables or unconditioned DELETE
    print("4. Updating update_dispatch...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.update_dispatch(
        p_dispatch_id bigint,
        p_dispatch jsonb
    )
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $func$
    DECLARE
        v_old_dispatch RECORD;
        v_alloc RECORD;
        v_storage_prod_id BIGINT;
        v_prod_code TEXT;
        v_prod_name TEXT;
        v_category TEXT;
        v_grade TEXT;
        v_location TEXT;
        v_dept TEXT;
        v_remarks TEXT;
        v_date DATE;
        v_unit TEXT;
        v_req_qty NUMERIC(15, 3);
        v_ret_qty NUMERIC(15, 3);
        v_net_qty NUMERIC(15, 3);
        v_total_available NUMERIC(15, 3) := 0;
        v_rem_to_alloc NUMERIC(15, 3);
        v_take NUMERIC(15, 3);
        v_alloc_items public.mms_dispatch_alloc_item[];
        v_item public.mms_dispatch_alloc_item;
        v_idx INT := 0;
        v_rem_return NUMERIC(15, 3);
        v_ret_take NUMERIC(15, 3);
        v_allocations JSONB := '[]'::jsonb;
        v_result JSONB;
        v_batch RECORD;
        i INT;
    BEGIN
        -- 1. Lock existing dispatch
        SELECT * INTO v_old_dispatch 
        FROM public.dispatches 
        WHERE id = p_dispatch_id 
        FOR UPDATE;

        IF v_old_dispatch.id IS NULL THEN
            RAISE EXCEPTION 'Dispatch record % not found.', p_dispatch_id;
        END IF;

        -- 2. Reverse previous batch deductions
        FOR v_alloc IN 
            SELECT batch_id, net_quantity, quantity, returned_quantity 
            FROM public.dispatch_batches 
            WHERE dispatch_id = p_dispatch_id 
            FOR UPDATE
        LOOP
            UPDATE public.batches
            SET available_quantity = available_quantity + COALESCE(v_alloc.net_quantity, v_alloc.quantity - COALESCE(v_alloc.returned_quantity, 0)),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_alloc.batch_id;
        END LOOP;

        -- 3. Delete old allocation rows scoped ONLY to this specific dispatch
        DELETE FROM public.dispatch_batches WHERE dispatch_id = p_dispatch_id;

        -- Parse update payload
        v_prod_code := TRIM(COALESCE(p_dispatch->>'material_code', v_old_dispatch.material_code));
        v_req_qty := ROUND(COALESCE((p_dispatch->>'quantity')::NUMERIC, v_old_dispatch.quantity), 3);
        v_ret_qty := ROUND(COALESCE((p_dispatch->>'return_quantity')::NUMERIC, v_old_dispatch.return_quantity), 3);

        IF v_req_qty <= 0 THEN
            RAISE EXCEPTION 'Dispatch quantity must be greater than zero.';
        END IF;

        IF v_ret_qty < 0 THEN
            RAISE EXCEPTION 'Return quantity cannot be negative.';
        END IF;

        IF v_ret_qty > v_req_qty THEN
            RAISE EXCEPTION 'Return quantity (%) cannot exceed Dispatch quantity (%).', v_ret_qty, v_req_qty;
        END IF;

        v_net_qty := v_req_qty - v_ret_qty;

        SELECT id, product_name, uom, grade, category 
        INTO v_storage_prod_id, v_prod_name, v_unit, v_grade, v_category
        FROM public.storage_products
        WHERE LOWER(TRIM(product_code)) = LOWER(v_prod_code);

        v_prod_name := COALESCE(NULLIF(TRIM(p_dispatch->>'product'), ''), v_prod_name, v_old_dispatch.product);
        v_unit := COALESCE(NULLIF(TRIM(p_dispatch->>'units'), ''), v_unit, v_old_dispatch.units, 'kg');
        v_category := COALESCE(NULLIF(TRIM(p_dispatch->>'category'), ''), v_category, v_old_dispatch.category, 'Finished Goods');
        v_grade := COALESCE(NULLIF(TRIM(p_dispatch->>'grade'), ''), v_grade, v_old_dispatch.grade, 'STANDARD');
        v_location := COALESCE(NULLIF(TRIM(p_dispatch->>'location'), ''), v_old_dispatch.location, '');
        v_dept := COALESCE(NULLIF(TRIM(p_dispatch->>'department'), ''), v_old_dispatch.department, 'Dispatch');
        v_remarks := COALESCE(NULLIF(TRIM(p_dispatch->>'remarks'), ''), v_old_dispatch.remarks);
        v_date := COALESCE((p_dispatch->>'date')::DATE, v_old_dispatch.date);

        -- 4. Check available stock across active batches
        SELECT COALESCE(SUM(available_quantity), 0)
        INTO v_total_available
        FROM public.batches
        WHERE LOWER(TRIM(material_code)) = LOWER(v_prod_code)
          AND available_quantity > 0.0001
          AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE);

        IF v_total_available < v_req_qty THEN
            RAISE EXCEPTION 'Insufficient Storage Stock. Requested: % %, Available: % %, Shortage: % %',
                v_req_qty, v_unit, v_total_available, v_unit, (v_req_qty - v_total_available), v_unit;
        END IF;

        -- 5. FIFO Allocation in Memory (No Temp Tables!)
        v_rem_to_alloc := v_req_qty;

        FOR v_batch IN
            SELECT id, batch_no, COALESCE(batch_date, received_date) AS b_date, available_quantity, uom
            FROM public.batches
            WHERE LOWER(TRIM(material_code)) = LOWER(v_prod_code)
              AND available_quantity > 0.0001
              AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE)
            ORDER BY 
                COALESCE(batch_date, received_date, created_at::date) ASC,
                created_at ASC,
                id ASC
            FOR UPDATE
        LOOP
            EXIT WHEN v_rem_to_alloc <= 0;

            IF v_batch.available_quantity <= v_rem_to_alloc THEN
                v_take := v_batch.available_quantity;
                v_rem_to_alloc := v_rem_to_alloc - v_take;
            ELSE
                v_take := v_rem_to_alloc;
                v_rem_to_alloc := 0;
            END IF;

            v_idx := v_idx + 1;
            v_item.ord := v_idx;
            v_item.batch_id := v_batch.id;
            v_item.batch_no := v_batch.batch_no;
            v_item.batch_date := v_batch.b_date;
            v_item.avail_before := v_batch.available_quantity;
            v_item.take_qty := v_take;
            v_item.ret_qty := 0;
            v_item.net_take := v_take;
            v_item.uom := v_batch.uom;

            v_alloc_items := array_append(v_alloc_items, v_item);
        END LOOP;

        IF v_rem_to_alloc > 0 THEN
            RAISE EXCEPTION 'Insufficient stock during FIFO execution. Shortage: % %', v_rem_to_alloc, v_unit;
        END IF;

        -- Apply Return Quantity in reverse order
        IF v_ret_qty > 0 AND v_alloc_items IS NOT NULL THEN
            v_rem_return := v_ret_qty;
            FOR i IN REVERSE array_length(v_alloc_items, 1)..1 LOOP
                EXIT WHEN v_rem_return <= 0;
                v_ret_take := LEAST(v_alloc_items[i].take_qty, v_rem_return);
                v_alloc_items[i].ret_qty := v_ret_take;
                v_alloc_items[i].net_take := v_alloc_items[i].take_qty - v_ret_take;
                v_rem_return := v_rem_return - v_ret_take;
            END LOOP;
        END IF;

        -- Commit deductions
        IF v_alloc_items IS NOT NULL THEN
            FOR i IN 1..array_length(v_alloc_items, 1) LOOP
                UPDATE public.batches
                SET available_quantity = available_quantity - v_alloc_items[i].net_take,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = v_alloc_items[i].batch_id;

                INSERT INTO public.dispatch_batches (
                    dispatch_id, batch_no, batch_id, quantity, returned_quantity, net_quantity, uom, batch_date
                ) VALUES (
                    p_dispatch_id, 
                    v_alloc_items[i].batch_no, 
                    v_alloc_items[i].batch_id, 
                    v_alloc_items[i].take_qty, 
                    v_alloc_items[i].ret_qty, 
                    v_alloc_items[i].net_take, 
                    v_alloc_items[i].uom, 
                    v_alloc_items[i].batch_date
                );

                v_allocations := v_allocations || jsonb_build_object(
                    'batch_id', v_alloc_items[i].batch_id,
                    'batch_no', v_alloc_items[i].batch_no,
                    'batch_date', v_alloc_items[i].batch_date,
                    'quantity', v_alloc_items[i].take_qty,
                    'returned_quantity', v_alloc_items[i].ret_qty,
                    'net_quantity', v_alloc_items[i].net_take,
                    'uom', v_alloc_items[i].uom
                );
            END LOOP;
        END IF;

        -- 6. Update dispatch header
        UPDATE public.dispatches
        SET date = v_date,
            storage_product_id = v_storage_prod_id,
            material_code = v_prod_code,
            product = v_prod_name,
            category = v_category,
            grade = v_grade,
            quantity = v_req_qty,
            return_quantity = v_ret_qty,
            net_quantity = v_net_qty,
            units = v_unit,
            location = v_location,
            department = v_dept,
            remarks = v_remarks,
            updated_at = CURRENT_TIMESTAMP
        WHERE id = p_dispatch_id;

        v_result := jsonb_build_object(
            'success', true,
            'dispatch_id', p_dispatch_id,
            'material_code', v_prod_code,
            'dispatched_quantity', v_req_qty,
            'return_quantity', v_ret_qty,
            'net_quantity', v_net_qty,
            'allocations', v_allocations
        );

        INSERT INTO public.audit_logs (user_id, operation, module, record_id, details)
        VALUES (auth.uid(), 'UPDATE', 'dispatches', p_dispatch_id::TEXT, v_result);

        RETURN v_result;
    END;
    $func$;
    """)

    # 5. Verify delete_dispatch
    print("5. Verifying delete_dispatch...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.delete_dispatch(p_dispatch_id bigint)
    RETURNS boolean
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $func$
    DECLARE
        v_alloc RECORD;
        v_mat_code TEXT;
        v_qty NUMERIC(15, 3);
    BEGIN
        SELECT material_code, quantity INTO v_mat_code, v_qty 
        FROM public.dispatches 
        WHERE id = p_dispatch_id 
        FOR UPDATE;

        IF v_mat_code IS NULL THEN
            RAISE EXCEPTION 'Dispatch with ID % not found', p_dispatch_id;
        END IF;

        -- Restore exact net quantities back to original storage batches
        FOR v_alloc IN 
            SELECT batch_id, COALESCE(net_quantity, quantity - COALESCE(returned_quantity, 0)) AS net_restoration
            FROM public.dispatch_batches 
            WHERE dispatch_id = p_dispatch_id 
            FOR UPDATE
        LOOP
            UPDATE public.batches
            SET available_quantity = available_quantity + v_alloc.net_restoration,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_alloc.batch_id;
        END LOOP;

        -- Strictly conditioned deletes:
        DELETE FROM public.dispatch_batches WHERE dispatch_id = p_dispatch_id;
        DELETE FROM public.dispatches WHERE id = p_dispatch_id;

        INSERT INTO public.audit_logs (user_id, operation, module, record_id, details)
        VALUES (
            auth.uid(), 
            'DELETE', 
            'dispatches', 
            p_dispatch_id::TEXT, 
            jsonb_build_object('material_code', v_mat_code, 'quantity', v_qty)
        );

        RETURN true;
    END;
    $func$;
    """)

    # 6. Initialize Expiry Settings in system_settings
    print("6. Setting up inventory expiry settings in system_settings...")
    cur.execute("""
        INSERT INTO public.system_settings (key, value, updated_at)
        VALUES 
            ('invoice_material_expiry_alert_days', '30'::jsonb, CURRENT_TIMESTAMP),
            ('storage_product_expiry_alert_days', '30'::jsonb, CURRENT_TIMESTAMP)
        ON CONFLICT (key) DO NOTHING;
    """)

    # 7. Helper RPCs for Settings
    print("7. Creating get_inventory_settings and update_inventory_settings RPCs...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.get_inventory_settings()
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $func$
    DECLARE
        v_inv_days INT := 30;
        v_stor_days INT := 30;
        v_val JSONB;
    BEGIN
        SELECT value INTO v_val FROM public.system_settings WHERE key = 'invoice_material_expiry_alert_days';
        IF v_val IS NOT NULL THEN
            v_inv_days := COALESCE((v_val#>>'{}')::INT, 30);
        END IF;

        SELECT value INTO v_val FROM public.system_settings WHERE key = 'storage_product_expiry_alert_days';
        IF v_val IS NOT NULL THEN
            v_stor_days := COALESCE((v_val#>>'{}')::INT, 30);
        END IF;

        RETURN jsonb_build_object(
            'invoice_material_expiry_alert_days', v_inv_days,
            'storage_product_expiry_alert_days', v_stor_days
        );
    END;
    $func$;

    CREATE OR REPLACE FUNCTION public.update_inventory_settings(
        p_invoice_days int,
        p_storage_days int
    )
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $func$
    BEGIN
        IF p_invoice_days < 0 THEN
            RAISE EXCEPTION 'Invoice Material Expiry Alert Days cannot be negative.';
        END IF;

        IF p_storage_days < 0 THEN
            RAISE EXCEPTION 'Storage Product Expiry Alert Days cannot be negative.';
        END IF;

        INSERT INTO public.system_settings (key, value, updated_at)
        VALUES 
            ('invoice_material_expiry_alert_days', to_jsonb(p_invoice_days), CURRENT_TIMESTAMP)
        ON CONFLICT (key) DO UPDATE 
        SET value = to_jsonb(p_invoice_days), updated_at = CURRENT_TIMESTAMP;

        INSERT INTO public.system_settings (key, value, updated_at)
        VALUES 
            ('storage_product_expiry_alert_days', to_jsonb(p_storage_days), CURRENT_TIMESTAMP)
        ON CONFLICT (key) DO UPDATE 
        SET value = to_jsonb(p_storage_days), updated_at = CURRENT_TIMESTAMP;

        RETURN jsonb_build_object(
            'success', true,
            'invoice_material_expiry_alert_days', p_invoice_days,
            'storage_product_expiry_alert_days', p_storage_days
        );
    END;
    $func$;
    """)

    conn.close()
    print("Migration completed successfully!")

if __name__ == "__main__":
    run_migration()
