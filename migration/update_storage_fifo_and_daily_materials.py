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

    # 1. Ensure batches table has received_at timestamp with time zone
    print("1. Ensuring batches.received_at TIMESTAMPTZ...")
    cur.execute("""
        ALTER TABLE public.batches ADD COLUMN IF NOT EXISTS received_at TIMESTAMPTZ DEFAULT now();
        UPDATE public.batches SET received_at = created_at WHERE received_at IS NULL;
    """)

    # 2. Update get_storage_dispatch_preview to use received_at timestamp-based FIFO ordering
    print("2. Updating get_storage_dispatch_preview with timestamp-based FIFO...")
    cur.execute("DROP FUNCTION IF EXISTS public.get_storage_dispatch_preview(text, numeric, numeric);")
    cur.execute("DROP FUNCTION IF EXISTS public.get_storage_dispatch_preview(bigint, text, numeric);")
    cur.execute("DROP FUNCTION IF EXISTS public.get_storage_dispatch_preview(bigint, text, numeric, numeric);")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.get_storage_dispatch_preview(
        p_material_id bigint DEFAULT NULL::bigint,
        p_material_code text DEFAULT NULL::text,
        p_requested_quantity numeric DEFAULT 0,
        p_return_quantity numeric DEFAULT 0
    )
    RETURNS jsonb
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $func$
    DECLARE
        v_clean_code TEXT;
        v_clean_name TEXT;
        v_category TEXT;
        v_grade TEXT;
        v_uom TEXT;
        v_req_qty NUMERIC(15, 3);
        v_ret_qty NUMERIC(15, 3);
        v_net_qty NUMERIC(15, 3);
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
        v_clean_code := TRIM(COALESCE(p_material_code, ''));
        IF v_clean_code = '' AND p_material_id IS NOT NULL THEN
            SELECT product_code INTO v_clean_code FROM public.storage_products WHERE id = p_material_id;
            IF v_clean_code IS NULL THEN
                SELECT material_code INTO v_clean_code FROM public.batches WHERE id = p_material_id OR storage_product_id = p_material_id LIMIT 1;
            END IF;
        END IF;
        IF v_clean_code IS NULL OR v_clean_code = '' THEN
            RETURN jsonb_build_object('success', false, 'error', 'Material code is required');
        END IF;

        v_req_qty := ROUND(COALESCE(p_requested_quantity, 0), 3);
        v_ret_qty := ROUND(COALESCE(p_return_quantity, 0), 3);
        v_net_qty := v_req_qty - v_ret_qty;

        -- Resolve product metadata
        SELECT product_name, category, grade, uom 
        INTO v_clean_name, v_category, v_grade, v_uom
        FROM public.storage_products
        WHERE LOWER(TRIM(product_code)) = LOWER(v_clean_code);

        -- Query all active stock batches
        FOR v_batch IN
            SELECT 
                b.id,
                b.batch_no,
                COALESCE(b.batch_date, b.received_date) AS batch_date,
                b.received_date,
                b.received_at,
                b.created_at,
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
                b.expiry_date ASC NULLS LAST,
                COALESCE(b.received_at, b.created_at, b.batch_date::timestamptz, b.received_date::timestamptz) ASC,
                b.created_at ASC,
                b.id ASC
        LOOP
            IF NOT v_batch.is_expired THEN
                v_total_available := v_total_available + v_batch.available_quantity;
            END IF;

            v_batches := v_batches || jsonb_build_object(
                'batch_id', v_batch.id,
                'batch_no', v_batch.batch_no,
                'batch_date', v_batch.batch_date,
                'received_at', v_batch.received_at,
                'created_at', v_batch.created_at,
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
                    b.expiry_date ASC NULLS LAST,
                    COALESCE(b.received_at, b.created_at, b.batch_date::timestamptz, b.received_date::timestamptz) ASC,
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
            'requested_quantity', v_req_qty,
            'return_quantity', v_ret_qty,
            'net_quantity', v_net_qty,
            'total_available_stock', v_total_available,
            'shortage_quantity', v_shortage,
            'is_sufficient', v_is_sufficient,
            'active_batches', v_batches,
            'fifo_allocations', v_allocations
        );
    END;
    $func$;
    """)

    # 3. Update create_dispatch_fifo with timestamp-based FIFO ordering
    print("3. Updating create_dispatch_fifo with timestamp-based FIFO...")
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

        -- 1. Concurrency-Safe Row Lock on Eligible Storage Batches in strict FIFO Order (Expiry ASC, Received Timestamp ASC, ID ASC)
        SELECT COALESCE(SUM(available_quantity), 0)
        INTO v_total_available
        FROM public.batches
        WHERE LOWER(TRIM(material_code)) = LOWER(v_prod_code)
          AND available_quantity > 0.0001
          AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE);

        IF v_total_available < v_req_qty THEN
            RAISE EXCEPTION 'Insufficient storage stock for %. Requested: % %, Available: % %',
                v_prod_code, v_req_qty, v_unit, v_total_available, v_unit;
        END IF;

        -- 2. Insert Parent Dispatch Record atomically
        INSERT INTO public.dispatches (
            date, material_code, product, quantity, return_quantity, net_quantity,
            units, location, department, remarks, storage_product_id, category, grade, created_by
        ) VALUES (
            v_date, v_prod_code, v_prod_name, v_req_qty, v_ret_qty, v_net_qty,
            v_unit, v_location, v_dept, v_remarks, v_storage_prod_id, v_category, v_grade, v_created_by
        ) RETURNING id INTO v_dispatch_id;

        -- 3. In-memory FIFO Allocation Calculation using received_at timestamp
        v_rem_to_alloc := v_req_qty;

        FOR v_batch IN
            SELECT b.id, b.batch_no, COALESCE(b.batch_date, b.received_date) AS b_date, b.available_quantity, b.uom
            FROM public.batches b
            WHERE LOWER(TRIM(b.material_code)) = LOWER(v_prod_code)
              AND b.available_quantity > 0.0001
              AND (b.expiry_date IS NULL OR b.expiry_date >= CURRENT_DATE)
            ORDER BY 
                b.expiry_date ASC NULLS LAST,
                COALESCE(b.received_at, b.created_at, b.batch_date::timestamptz, b.received_date::timestamptz) ASC,
                b.created_at ASC,
                b.id ASC
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
        -- They remain permanently in history with available_quantity = 0.
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

        -- Record idempotency
        IF v_idempotency_key IS NOT NULL THEN
            INSERT INTO public.idempotency_keys (
                idempotency_key, 
                user_id, 
                resource, 
                action, 
                status, 
                response
            ) VALUES (
                v_idempotency_key, 
                v_created_by, 
                'dispatches', 
                'create_dispatch_fifo', 
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

    # 4. Update update_dispatch with timestamp-based FIFO ordering
    print("4. Updating update_dispatch with timestamp-based FIFO...")
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
            RAISE EXCEPTION 'Dispatch #% does not exist.', p_dispatch_id;
        END IF;

        -- 2. Restore all previously allocated quantities to exact original batches
        FOR v_alloc IN
            SELECT batch_id, net_quantity
            FROM public.dispatch_batches
            WHERE dispatch_id = p_dispatch_id
            FOR UPDATE
        LOOP
            UPDATE public.batches
            SET available_quantity = available_quantity + v_alloc.net_quantity,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_alloc.batch_id;
        END LOOP;

        -- Delete old allocation records with explicit WHERE clause
        DELETE FROM public.dispatch_batches WHERE dispatch_id = p_dispatch_id;

        -- 3. Extract and sanitize updated parameters
        v_prod_code := TRIM(COALESCE(p_dispatch->>'material_code', v_old_dispatch.material_code));
        v_req_qty := ROUND(COALESCE((p_dispatch->>'quantity')::NUMERIC, v_old_dispatch.quantity), 3);
        v_ret_qty := ROUND(COALESCE((p_dispatch->>'return_quantity')::NUMERIC, 0), 3);

        IF v_req_qty <= 0 THEN
            RAISE EXCEPTION 'Dispatch quantity must be greater than zero.';
        END IF;

        IF v_ret_qty < 0 THEN
            RAISE EXCEPTION 'Return quantity cannot be negative.';
        END IF;

        IF v_ret_qty > v_req_qty THEN
            RAISE EXCEPTION 'Return quantity cannot exceed dispatch quantity.';
        END IF;

        v_net_qty := v_req_qty - v_ret_qty;

        -- Resolve product metadata
        SELECT id, product_name, uom, grade, category 
        INTO v_storage_prod_id, v_prod_name, v_unit, v_grade, v_category
        FROM public.storage_products
        WHERE LOWER(TRIM(product_code)) = LOWER(v_prod_code);

        v_prod_name := COALESCE(NULLIF(TRIM(p_dispatch->>'product'), ''), v_prod_name, v_old_dispatch.product);
        v_unit := COALESCE(NULLIF(TRIM(p_dispatch->>'units'), ''), v_unit, v_old_dispatch.units);
        v_category := COALESCE(NULLIF(TRIM(p_dispatch->>'category'), ''), v_category, v_old_dispatch.category);
        v_grade := COALESCE(NULLIF(TRIM(p_dispatch->>'grade'), ''), v_grade, v_old_dispatch.grade);
        v_location := COALESCE(NULLIF(TRIM(p_dispatch->>'location'), ''), v_old_dispatch.location);
        v_dept := COALESCE(NULLIF(TRIM(p_dispatch->>'department'), ''), v_old_dispatch.department);
        v_remarks := NULLIF(TRIM(COALESCE(p_dispatch->>'remarks', v_old_dispatch.remarks)), '');
        v_date := COALESCE((p_dispatch->>'date')::DATE, v_old_dispatch.date);

        -- Check total available stock after restoration
        SELECT COALESCE(SUM(available_quantity), 0)
        INTO v_total_available
        FROM public.batches
        WHERE LOWER(TRIM(material_code)) = LOWER(v_prod_code)
          AND available_quantity > 0.0001
          AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE);

        IF v_total_available < v_req_qty THEN
            RAISE EXCEPTION 'Insufficient stock to update dispatch #%. Requested: %, Available: %',
                p_dispatch_id, v_req_qty, v_total_available;
        END IF;

        -- 4. In-memory FIFO Allocation Calculation using received_at timestamp
        v_rem_to_alloc := v_req_qty;

        FOR v_batch IN
            SELECT b.id, b.batch_no, COALESCE(b.batch_date, b.received_date) AS b_date, b.available_quantity, b.uom
            FROM public.batches b
            WHERE LOWER(TRIM(b.material_code)) = LOWER(v_prod_code)
              AND b.available_quantity > 0.0001
              AND (b.expiry_date IS NULL OR b.expiry_date >= CURRENT_DATE)
            ORDER BY 
                b.expiry_date ASC NULLS LAST,
                COALESCE(b.received_at, b.created_at, b.batch_date::timestamptz, b.received_date::timestamptz) ASC,
                b.created_at ASC,
                b.id ASC
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

        -- Apply Return Quantity (LIFO of allocation)
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

        -- 5. Commit Batch Deductions and Insert dispatch_batches
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

        -- 6. Update Parent Dispatch Record
        UPDATE public.dispatches
        SET date = v_date,
            material_code = v_prod_code,
            product = v_prod_name,
            quantity = v_req_qty,
            return_quantity = v_ret_qty,
            net_quantity = v_net_qty,
            units = v_unit,
            location = v_location,
            department = v_dept,
            remarks = v_remarks,
            storage_product_id = v_storage_prod_id,
            category = v_category,
            grade = v_grade,
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

        -- Audit log
        INSERT INTO public.audit_logs (user_id, operation, module, record_id, details)
        VALUES (
            auth.uid(), 
            'UPDATE', 
            'dispatches', 
            p_dispatch_id::TEXT, 
            jsonb_build_object('product_code', v_prod_code, 'quantity', v_req_qty, 'return', v_ret_qty, 'net', v_net_qty)
        );

        RETURN v_result;
    END;
    $func$;
    """)

    # 5. Update get_live_materials_summary to implement continuous daily opening/closing stock chain and daily movement reset
    print("5. Updating get_live_materials_summary with daily opening/closing chain...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.get_live_materials_summary(
        p_search text DEFAULT NULL::text, 
        p_category text DEFAULT NULL::text, 
        p_grade text DEFAULT NULL::text, 
        p_status text DEFAULT 'all'::text, 
        p_from_date date DEFAULT NULL::date, 
        p_to_date date DEFAULT NULL::date, 
        p_limit integer DEFAULT 100, 
        p_offset integer DEFAULT 0, 
        p_expiry_days integer DEFAULT NULL::integer
    )
    RETURNS TABLE(
        id bigint, 
        material_code text, 
        description text, 
        category text, 
        grade text, 
        opening_stock numeric, 
        purchased numeric, 
        transfer_out numeric, 
        return_in numeric, 
        closing_stock numeric, 
        shelves_bin text, 
        reorder_level numeric, 
        unit text, 
        lot_count integer, 
        earliest_expiry date
    )
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $function$
    DECLARE
        v_alert_days INT := 30;
        v_val JSONB;
        v_start_date DATE;
        v_end_date DATE;
    BEGIN
        IF p_expiry_days IS NOT NULL THEN
            v_alert_days := p_expiry_days;
        ELSE
            SELECT value INTO v_val FROM public.system_settings WHERE key = 'invoice_material_expiry_alert_days';
            IF v_val IS NOT NULL THEN
                v_alert_days := COALESCE((v_val#>>'{}')::INT, 30);
            END IF;
        END IF;

        -- When viewing without date filter, default to Today (CURRENT_DATE)
        -- Enforces: Opening Stock = Previous Day's Closing Stock, and Today's In/Out reset
        v_start_date := COALESCE(p_from_date, CURRENT_DATE);
        v_end_date := COALESCE(p_to_date, v_start_date);

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
        -- Prior movements strictly BEFORE v_start_date
        prior_purchases AS (
            SELECT 
                ii.material as mat_code,
                COALESCE(SUM(ii.quantity), 0) as prior_purchased
            FROM invoice_items ii
            JOIN invoices i ON i.id = ii.invoice_id
            WHERE i.date < v_start_date
            GROUP BY ii.material
        ),
        prior_transfers AS (
            SELECT 
                t.code as mat_code,
                COALESCE(SUM(t.outward), 0) as prior_out,
                COALESCE(SUM(t.return_units), 0) as prior_ret
            FROM transfers t
            WHERE t.date < v_start_date
            GROUP BY t.code
        ),
        prior_adjustments AS (
            SELECT 
                sa.material_code as mat_code,
                COALESCE(SUM(sa.amount), 0) as prior_adj
            FROM stock_adjustments sa
            WHERE sa.created_at::date < v_start_date
            GROUP BY sa.material_code
        ),
        -- Current movements within [v_start_date, v_end_date]
        curr_purchases AS (
            SELECT 
                ii.material as mat_code,
                COALESCE(SUM(ii.quantity), 0) as total_purchased
            FROM invoice_items ii
            JOIN invoices i ON i.id = ii.invoice_id
            WHERE i.date >= v_start_date AND i.date <= v_end_date
            GROUP BY ii.material
        ),
        curr_transfers AS (
            SELECT 
                t.code as mat_code,
                COALESCE(SUM(t.outward), 0) as total_out,
                COALESCE(SUM(t.return_units), 0) as total_ret
            FROM transfers t
            WHERE t.date >= v_start_date AND t.date <= v_end_date
            GROUP BY t.code
        ),
        curr_adjustments AS (
            SELECT 
                sa.material_code as mat_code,
                COALESCE(SUM(sa.amount), 0) as total_adj
            FROM stock_adjustments sa
            WHERE sa.created_at::date >= v_start_date AND sa.created_at::date <= v_end_date
            GROUP BY sa.material_code
        )
        SELECT 
            m.id,
            m.material_code,
            m.description,
            COALESCE(m.category, 'General') as category,
            COALESCE(NULLIF(m.grade, ''), ls.lot_grds, '-') as grade,
            -- Opening Stock = Initial baseline + all movements before v_start_date (= Previous day's closing stock)
            ROUND(
                (COALESCE(m.opening_stock, 0) 
                 + COALESCE(pp.prior_purchased, 0) 
                 - COALESCE(pt.prior_out, 0) 
                 + COALESCE(pt.prior_ret, 0)
                 + COALESCE(pa.prior_adj, 0))::NUMERIC, 
                3
            ) as opening_stock,
            -- Daily movements reset for target day/range
            ROUND(COALESCE(cp.total_purchased, 0)::NUMERIC, 3) as purchased,
            ROUND(COALESCE(ct.total_out, 0)::NUMERIC, 3) as transfer_out,
            ROUND(COALESCE(ct.total_ret, 0)::NUMERIC, 3) as return_in,
            -- Closing Stock = Opening + Purchased - Transfer Out + Return In + Adjustments
            ROUND(
                (
                    (COALESCE(m.opening_stock, 0) 
                     + COALESCE(pp.prior_purchased, 0) 
                     - COALESCE(pt.prior_out, 0) 
                     + COALESCE(pt.prior_ret, 0)
                     + COALESCE(pa.prior_adj, 0))
                    + COALESCE(cp.total_purchased, 0)
                    - COALESCE(ct.total_out, 0)
                    + COALESCE(ct.total_ret, 0)
                    + COALESCE(ca.total_adj, 0)
                )::NUMERIC, 
                3
            ) as closing_stock,
            COALESCE(l.location, 'â€”') as shelves_bin,
            m.reorder_level,
            m.unit,
            COALESCE(ls.lot_cnt, CASE WHEN m.lot_no IS NOT NULL AND m.lot_no != '' THEN 1 ELSE 0 END)::INT as lot_count,
            COALESCE(ls.min_exp, m.expiry_date) as earliest_expiry
        FROM materials m
        LEFT JOIN locs l ON l.category = m.category
        LEFT JOIN lots_summary ls ON ls.material_code = m.material_code
        LEFT JOIN prior_purchases pp ON pp.mat_code = m.material_code
        LEFT JOIN prior_transfers pt ON pt.mat_code = m.material_code
        LEFT JOIN prior_adjustments pa ON pa.mat_code = m.material_code
        LEFT JOIN curr_purchases cp ON cp.mat_code = m.material_code
        LEFT JOIN curr_transfers ct ON ct.mat_code = m.material_code
        LEFT JOIN curr_adjustments ca ON ca.mat_code = m.material_code
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
                (m.expiry_date IS NOT NULL AND m.expiry_date <= CURRENT_DATE + (v_alert_days || ' days')::INTERVAL AND m.expiry_date >= CURRENT_DATE) OR
                EXISTS (
                    SELECT 1 FROM material_lots ml_e 
                    WHERE ml_e.material_code = m.material_code 
                      AND ml_e.expiry_date IS NOT NULL 
                      AND ml_e.expiry_date <= CURRENT_DATE + (v_alert_days || ' days')::INTERVAL 
                      AND ml_e.expiry_date >= CURRENT_DATE
                )
            ))
        )
        ORDER BY m.material_code ASC
        LIMIT p_limit OFFSET p_offset;
    END;
    $function$;
    """)

    conn.close()
    print("MIGRATION COMPLETED SUCCESSFULLY!")

if __name__ == '__main__':
    run_migration()
