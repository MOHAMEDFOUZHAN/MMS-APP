import os
import psycopg2
import json

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = os.environ["SUPABASE_DB_PASSWORD"]
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
conn.autocommit = False
cur = conn.cursor()

try:
    print("1. Creating storage_products table and indexes...")
    cur.execute("""
    CREATE TABLE IF NOT EXISTS public.storage_products (
        id BIGSERIAL PRIMARY KEY,
        product_code TEXT NOT NULL,
        product_name TEXT NOT NULL,
        uom TEXT NOT NULL DEFAULT 'kg',
        grade TEXT DEFAULT 'STANDARD',
        category TEXT DEFAULT 'Finished Goods',
        created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
    );

    CREATE UNIQUE INDEX IF NOT EXISTS uq_storage_products_code_ci 
    ON public.storage_products (LOWER(TRIM(product_code)));

    CREATE UNIQUE INDEX IF NOT EXISTS uq_storage_products_name_ci 
    ON public.storage_products (LOWER(TRIM(product_name)));

    -- Enable RLS
    ALTER TABLE public.storage_products ENABLE ROW LEVEL SECURITY;

    DO $$
    BEGIN
        IF NOT EXISTS (
            SELECT 1 FROM pg_policies WHERE tablename = 'storage_products' AND policyname = 'storage_products_all_access'
        ) THEN
            CREATE POLICY storage_products_all_access ON public.storage_products FOR ALL USING (true) WITH CHECK (true);
        END IF;
    END $$;
    """)

    print("2. Adjusting foreign keys on batches and dispatches...")
    # Drop restrictive FKs linking batches.material_id, batches.product_id and dispatches.material_id to materials table
    # so finished goods in Storage can exist independently from Material Master!
    cur.execute("""
    ALTER TABLE public.batches DROP CONSTRAINT IF EXISTS batches_material_id_fkey;
    ALTER TABLE public.batches DROP CONSTRAINT IF EXISTS batches_product_id_fkey;
    ALTER TABLE public.dispatches DROP CONSTRAINT IF EXISTS dispatches_material_id_fkey;

    -- Add storage_product_id to batches and dispatches
    ALTER TABLE public.batches 
    ADD COLUMN IF NOT EXISTS storage_product_id BIGINT REFERENCES public.storage_products(id) ON DELETE SET NULL;

    ALTER TABLE public.dispatches 
    ADD COLUMN IF NOT EXISTS storage_product_id BIGINT REFERENCES public.storage_products(id) ON DELETE SET NULL,
    ADD COLUMN IF NOT EXISTS return_quantity NUMERIC(15, 3) NOT NULL DEFAULT 0.000,
    ADD COLUMN IF NOT EXISTS net_quantity NUMERIC(15, 3) NOT NULL DEFAULT 0.000;

    ALTER TABLE public.dispatch_batches
    ADD COLUMN IF NOT EXISTS returned_quantity NUMERIC(15, 3) NOT NULL DEFAULT 0.000,
    ADD COLUMN IF NOT EXISTS net_quantity NUMERIC(15, 3) NOT NULL DEFAULT 0.000;
    """)

    print("3. Creating upsert_storage_product RPC...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.upsert_storage_product(
        p_product_code TEXT,
        p_product_name TEXT,
        p_uom TEXT DEFAULT 'kg',
        p_grade TEXT DEFAULT 'STANDARD',
        p_category TEXT DEFAULT 'Finished Goods'
    )
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        v_clean_code TEXT;
        v_clean_name TEXT;
        v_clean_uom TEXT;
        v_clean_grade TEXT;
        v_clean_category TEXT;
        v_row RECORD;
    BEGIN
        v_clean_code := TRIM(p_product_code);
        v_clean_name := TRIM(p_product_name);
        v_clean_uom := COALESCE(NULLIF(TRIM(p_uom), ''), 'kg');
        v_clean_grade := COALESCE(NULLIF(TRIM(p_grade), ''), 'STANDARD');
        v_clean_category := COALESCE(NULLIF(TRIM(p_category), ''), 'Finished Goods');

        IF v_clean_code = '' THEN
            RAISE EXCEPTION 'Product Code cannot be empty';
        END IF;
        IF v_clean_name = '' THEN
            v_clean_name := v_clean_code;
        END IF;

        -- 1. Check existing by product_code (case-insensitive)
        SELECT * INTO v_row 
        FROM public.storage_products 
        WHERE LOWER(TRIM(product_code)) = LOWER(v_clean_code);

        IF v_row.id IS NOT NULL THEN
            UPDATE public.storage_products
            SET product_name = COALESCE(NULLIF(v_clean_name, ''), v_row.product_name),
                uom = COALESCE(NULLIF(v_clean_uom, ''), v_row.uom),
                grade = COALESCE(NULLIF(v_clean_grade, ''), v_row.grade),
                category = COALESCE(NULLIF(v_clean_category, ''), v_row.category),
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_row.id
            RETURNING * INTO v_row;

            RETURN to_jsonb(v_row);
        END IF;

        -- 2. Check existing by product_name (case-insensitive)
        SELECT * INTO v_row 
        FROM public.storage_products 
        WHERE LOWER(TRIM(product_name)) = LOWER(v_clean_name);

        IF v_row.id IS NOT NULL THEN
            RETURN to_jsonb(v_row);
        END IF;

        -- 3. Insert new product
        INSERT INTO public.storage_products (
            product_code, product_name, uom, grade, category, created_at, updated_at
        ) VALUES (
            v_clean_code, v_clean_name, v_clean_uom, v_clean_grade, v_clean_category, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
        ) RETURNING * INTO v_row;

        RETURN to_jsonb(v_row);
    END;
    $$;
    """)

    print("4. Creating get_storage_products search RPC...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.get_storage_products(p_search TEXT DEFAULT NULL)
    RETURNS SETOF public.storage_products
    LANGUAGE sql
    STABLE
    SECURITY DEFINER
    AS $$
        SELECT * FROM public.storage_products
        WHERE p_search IS NULL OR TRIM(p_search) = '' OR
              product_code ILIKE '%' || TRIM(p_search) || '%' OR
              product_name ILIKE '%' || TRIM(p_search) || '%'
        ORDER BY product_name ASC, product_code ASC;
    $$;
    """)

    print("5. Creating get_dispatch_available_products RPC (Only products in Storage with available stock)...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.get_dispatch_available_products(p_search TEXT DEFAULT NULL)
    RETURNS TABLE (
        product_code TEXT,
        product_name TEXT,
        uom TEXT,
        grade TEXT,
        category TEXT,
        total_available NUMERIC(15, 3),
        batch_count BIGINT
    )
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        v_term TEXT;
    BEGIN
        v_term := NULLIF(TRIM(p_search), '');
        RETURN QUERY
        SELECT 
            b.material_code AS product_code,
            COALESCE(NULLIF(MAX(b.description), ''), b.material_code) AS product_name,
            COALESCE(NULLIF(MAX(b.uom), ''), 'kg') AS uom,
            COALESCE(NULLIF(MAX(b.grade), ''), 'STANDARD') AS grade,
            COALESCE(NULLIF(MAX(b.category), ''), 'Finished Goods') AS category,
            ROUND(SUM(b.available_quantity), 3) AS total_available,
            COUNT(b.id) AS batch_count
        FROM public.batches b
        WHERE b.available_quantity > 0.0001
          AND (b.expiry_date IS NULL OR b.expiry_date >= CURRENT_DATE)
          AND (
              v_term IS NULL OR
              b.material_code ILIKE '%' || v_term || '%' OR
              b.description ILIKE '%' || v_term || '%'
          )
        GROUP BY b.material_code
        HAVING SUM(b.available_quantity) > 0.0001
        ORDER BY b.material_code ASC;
    END;
    $$;
    """)

    print("6. Creating updated get_storage_dispatch_preview RPC...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.get_storage_dispatch_preview(
        p_material_code TEXT,
        p_requested_quantity NUMERIC DEFAULT 0,
        p_return_quantity NUMERIC DEFAULT 0
    )
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        v_clean_code TEXT;
        v_clean_name TEXT := '';
        v_uom TEXT := 'kg';
        v_category TEXT := 'General';
        v_grade TEXT := 'STANDARD';
        v_batch RECORD;
        v_total_available NUMERIC(15, 3) := 0;
        v_req_qty NUMERIC(15, 3);
        v_ret_qty NUMERIC(15, 3);
        v_net_dispatch NUMERIC(15, 3);
        v_shortage NUMERIC(15, 3) := 0;
        v_is_sufficient BOOLEAN := true;
        v_batches JSONB := '[]'::JSONB;
        v_allocations JSONB := '[]'::JSONB;
        
        v_remaining_to_allocate NUMERIC(15, 3);
        v_take NUMERIC(15, 3);
        v_alloc_record RECORD;
        
        -- Temporary table for simulation
        v_temp_allocations RECORD;
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

        -- Compute FIFO allocation simulation
        IF v_req_qty > 0 THEN
            IF v_req_qty > v_total_available THEN
                v_shortage := v_req_qty - v_total_available;
                v_is_sufficient := false;
            END IF;

            -- We simulate FIFO consumption and reverse return deduction
            -- Create a temporary structure for batch allocations
            CREATE TEMP TABLE IF NOT EXISTS temp_preview_alloc (
                ord SERIAL,
                batch_id BIGINT,
                batch_no TEXT,
                batch_date DATE,
                available_before NUMERIC(15, 3),
                allocated_quantity NUMERIC(15, 3),
                returned_quantity NUMERIC(15, 3) DEFAULT 0,
                net_deduction NUMERIC(15, 3) DEFAULT 0,
                batch_remaining NUMERIC(15, 3) DEFAULT 0,
                uom TEXT
            ) ON COMMIT DROP;

            DELETE FROM temp_preview_alloc;

            v_remaining_to_allocate := v_req_qty;

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
                EXIT WHEN v_remaining_to_allocate <= 0;

                IF v_batch.available_quantity <= v_remaining_to_allocate THEN
                    v_take := v_batch.available_quantity;
                    v_remaining_to_allocate := v_remaining_to_allocate - v_take;
                ELSE
                    v_take := v_remaining_to_allocate;
                    v_remaining_to_allocate := 0;
                END IF;

                INSERT INTO temp_preview_alloc (
                    batch_id, batch_no, batch_date, available_before, allocated_quantity, net_deduction, uom
                ) VALUES (
                    v_batch.id, v_batch.batch_no, v_batch.b_date, v_batch.available_quantity, v_take, v_take, v_batch.uom
                );
            END LOOP;

            -- Apply return quantity in reverse FIFO order (LIFO of allocation)
            IF v_ret_qty > 0 THEN
                DECLARE
                    v_rem_return NUMERIC(15, 3) := v_ret_qty;
                    v_alloc_id INT;
                    v_curr_alloc NUMERIC(15, 3);
                    v_ret_take NUMERIC(15, 3);
                BEGIN
                    FOR v_alloc_id, v_curr_alloc IN 
                        SELECT ord, allocated_quantity 
                        FROM temp_preview_alloc 
                        ORDER BY ord DESC 
                    LOOP
                        EXIT WHEN v_rem_return <= 0;
                        v_ret_take := LEAST(v_curr_alloc, v_rem_return);
                        
                        UPDATE temp_preview_alloc
                        SET returned_quantity = v_ret_take,
                            net_deduction = allocated_quantity - v_ret_take
                        WHERE ord = v_alloc_id;

                        v_rem_return := v_rem_return - v_ret_take;
                    END LOOP;
                END;
            END IF;

            -- Compute batch_remaining and pack into jsonb
            FOR v_temp_allocations IN SELECT * FROM temp_preview_alloc ORDER BY ord ASC
            LOOP
                v_allocations := v_allocations || jsonb_build_object(
                    'batch_id', v_temp_allocations.batch_id,
                    'batch_no', v_temp_allocations.batch_no,
                    'batch_date', v_temp_allocations.batch_date,
                    'available_before', v_temp_allocations.available_before,
                    'allocated_quantity', v_temp_allocations.allocated_quantity,
                    'returned_quantity', v_temp_allocations.returned_quantity,
                    'net_deduction', v_temp_allocations.net_deduction,
                    'batch_remaining', (v_temp_allocations.available_before - v_temp_allocations.net_deduction),
                    'uom', v_temp_allocations.uom
                );
            END LOOP;

            DROP TABLE IF EXISTS temp_preview_alloc;
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
    $$;
    """)

    print("7. Creating atomic create_dispatch_fifo RPC...")
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
        v_prod_code TEXT;
        v_prod_name TEXT;
        v_storage_prod_id BIGINT;
        v_category TEXT;
        v_grade TEXT;
        v_req_qty NUMERIC(15, 3);
        v_ret_qty NUMERIC(15, 3);
        v_net_qty NUMERIC(15, 3);
        v_unit TEXT;
        v_location TEXT;
        v_dept TEXT;
        v_remarks TEXT;
        v_date DATE;
        v_created_by UUID;
        
        v_total_available NUMERIC(15, 3) := 0;
        v_rem_to_alloc NUMERIC(15, 3);
        v_take NUMERIC(15, 3);
        v_batch RECORD;
        v_allocations JSONB := '[]'::JSONB;
        v_result JSONB;
    BEGIN
        v_idempotency_key := COALESCE(p_idempotency_key, p_dispatch->>'idempotency_key');

        -- Idempotency check
        IF v_idempotency_key IS NOT NULL AND TRIM(v_idempotency_key) != '' THEN
            SELECT response INTO v_cached_response 
            FROM public.idempotency_keys 
            WHERE idempotency_key = v_idempotency_key AND status = 'completed';

            IF v_cached_response IS NOT NULL THEN
                RETURN v_cached_response;
            END IF;
        END IF;

        v_prod_code := TRIM(p_dispatch->>'material_code');
        IF v_prod_code IS NULL OR v_prod_code = '' THEN
            RAISE EXCEPTION 'Product Code is required for dispatch.';
        END IF;

        v_prod_name := COALESCE(NULLIF(TRIM(p_dispatch->>'product'), ''), v_prod_code);
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

        -- 3. FIFO Allocation with Temporary Table
        CREATE TEMP TABLE IF NOT EXISTS temp_exec_alloc (
            ord SERIAL,
            batch_id BIGINT,
            batch_no TEXT,
            batch_date DATE,
            avail_before NUMERIC(15, 3),
            take_qty NUMERIC(15, 3),
            ret_qty NUMERIC(15, 3) DEFAULT 0,
            net_take NUMERIC(15, 3) DEFAULT 0,
            uom TEXT
        ) ON COMMIT DROP;

        DELETE FROM temp_exec_alloc;

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

            INSERT INTO temp_exec_alloc (batch_id, batch_no, batch_date, avail_before, take_qty, net_take, uom)
            VALUES (v_batch.id, v_batch.batch_no, v_batch.b_date, v_batch.available_quantity, v_take, v_take, v_batch.uom);
        END LOOP;

        IF v_rem_to_alloc > 0 THEN
            RAISE EXCEPTION 'Insufficient stock during FIFO execution. Shortage: % %', v_rem_to_alloc, v_unit;
        END IF;

        -- 4. Apply Return Quantity in Reverse Order (LIFO of allocation)
        IF v_ret_qty > 0 THEN
            DECLARE
                v_rem_return NUMERIC(15, 3) := v_ret_qty;
                v_alloc_id INT;
                v_curr_take NUMERIC(15, 3);
                v_ret_take NUMERIC(15, 3);
            BEGIN
                FOR v_alloc_id, v_curr_take IN 
                    SELECT ord, take_qty 
                    FROM temp_exec_alloc 
                    ORDER BY ord DESC 
                LOOP
                    EXIT WHEN v_rem_return <= 0;
                    v_ret_take := LEAST(v_curr_take, v_rem_return);
                    
                    UPDATE temp_exec_alloc
                    SET ret_qty = v_ret_take,
                        net_take = take_qty - v_ret_take
                    WHERE ord = v_alloc_id;

                    v_rem_return := v_rem_return - v_ret_take;
                END LOOP;
            END;
        END IF;

        -- 5. Commit Batch Deductions and Record dispatch_batches
        DECLARE
            v_alloc_rec RECORD;
        BEGIN
            FOR v_alloc_rec IN SELECT * FROM temp_exec_alloc ORDER BY ord ASC
            LOOP
                -- Deduct net_take from batches table
                UPDATE public.batches
                SET available_quantity = available_quantity - v_alloc_rec.net_take,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = v_alloc_rec.batch_id;

                INSERT INTO public.dispatch_batches (
                    dispatch_id, batch_no, batch_id, quantity, returned_quantity, net_quantity, uom, batch_date
                ) VALUES (
                    v_dispatch_id, v_alloc_rec.batch_no, v_alloc_rec.batch_id, v_alloc_rec.take_qty, v_alloc_rec.ret_qty, v_alloc_rec.net_take, v_alloc_rec.uom, v_alloc_rec.batch_date
                );

                v_allocations := v_allocations || jsonb_build_object(
                    'batch_id', v_alloc_rec.batch_id,
                    'batch_no', v_alloc_rec.batch_no,
                    'batch_date', v_alloc_rec.batch_date,
                    'quantity', v_alloc_rec.take_qty,
                    'returned_quantity', v_alloc_rec.ret_qty,
                    'net_quantity', v_alloc_rec.net_take,
                    'uom', v_alloc_rec.uom
                );
            END LOOP;
        END;

        DROP TABLE IF EXISTS temp_exec_alloc;

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
    $$;
    """)

    print("8. Creating updated atomic update_dispatch RPC...")
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
        v_prod_code TEXT;
        v_prod_name TEXT;
        v_storage_prod_id BIGINT;
        v_category TEXT;
        v_grade TEXT;
        v_req_qty NUMERIC(15, 3);
        v_ret_qty NUMERIC(15, 3);
        v_net_qty NUMERIC(15, 3);
        v_unit TEXT;
        v_location TEXT;
        v_dept TEXT;
        v_remarks TEXT;
        v_date DATE;
        
        v_total_available NUMERIC(15, 3) := 0;
        v_rem_to_alloc NUMERIC(15, 3);
        v_take NUMERIC(15, 3);
        v_batch RECORD;
        v_allocations JSONB := '[]'::JSONB;
        v_result JSONB;
    BEGIN
        -- 1. Lock existing dispatch header
        SELECT * INTO v_old_dispatch FROM public.dispatches WHERE id = p_dispatch_id FOR UPDATE;
        
        IF v_old_dispatch.id IS NULL THEN
            RAISE EXCEPTION 'Dispatch with ID % not found', p_dispatch_id;
        END IF;

        -- 2. Reverse previous allocations: restore net quantities back to batches
        FOR v_old_alloc IN 
            SELECT batch_id, COALESCE(net_quantity, quantity - COALESCE(returned_quantity, 0)) AS net_restoration
            FROM public.dispatch_batches 
            WHERE dispatch_id = p_dispatch_id 
            FOR UPDATE
        LOOP
            UPDATE public.batches
            SET available_quantity = available_quantity + v_old_alloc.net_restoration,
                updated_at = CURRENT_TIMESTAMP
            WHERE id = v_old_alloc.batch_id;
        END LOOP;

        -- Delete old allocation rows
        DELETE FROM public.dispatch_batches WHERE dispatch_id = p_dispatch_id;

        -- 3. Resolve target product & inputs
        v_prod_code := TRIM(COALESCE(p_dispatch->>'material_code', v_old_dispatch.material_code));
        v_prod_name := COALESCE(NULLIF(TRIM(p_dispatch->>'product'), ''), v_old_dispatch.product, v_prod_code);
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

        SELECT id INTO v_storage_prod_id
        FROM public.storage_products
        WHERE LOWER(TRIM(product_code)) = LOWER(v_prod_code);

        v_unit := COALESCE(NULLIF(TRIM(p_dispatch->>'units'), ''), v_old_dispatch.units, 'kg');
        v_category := COALESCE(NULLIF(TRIM(p_dispatch->>'category'), ''), v_old_dispatch.category, 'Finished Goods');
        v_grade := COALESCE(NULLIF(TRIM(p_dispatch->>'grade'), ''), v_old_dispatch.grade, 'STANDARD');
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

        -- 5. FIFO Allocation with Temporary Table
        CREATE TEMP TABLE IF NOT EXISTS temp_exec_alloc (
            ord SERIAL,
            batch_id BIGINT,
            batch_no TEXT,
            batch_date DATE,
            avail_before NUMERIC(15, 3),
            take_qty NUMERIC(15, 3),
            ret_qty NUMERIC(15, 3) DEFAULT 0,
            net_take NUMERIC(15, 3) DEFAULT 0,
            uom TEXT
        ) ON COMMIT DROP;

        DELETE FROM temp_exec_alloc;

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

            INSERT INTO temp_exec_alloc (batch_id, batch_no, batch_date, avail_before, take_qty, net_take, uom)
            VALUES (v_batch.id, v_batch.batch_no, v_batch.b_date, v_batch.available_quantity, v_take, v_take, v_batch.uom);
        END LOOP;

        IF v_rem_to_alloc > 0 THEN
            RAISE EXCEPTION 'Insufficient stock during FIFO execution. Shortage: % %', v_rem_to_alloc, v_unit;
        END IF;

        -- Apply Return Quantity in reverse order
        IF v_ret_qty > 0 THEN
            DECLARE
                v_rem_return NUMERIC(15, 3) := v_ret_qty;
                v_alloc_id INT;
                v_curr_take NUMERIC(15, 3);
                v_ret_take NUMERIC(15, 3);
            BEGIN
                FOR v_alloc_id, v_curr_take IN 
                    SELECT ord, take_qty 
                    FROM temp_exec_alloc 
                    ORDER BY ord DESC 
                LOOP
                    EXIT WHEN v_rem_return <= 0;
                    v_ret_take := LEAST(v_curr_take, v_rem_return);
                    
                    UPDATE temp_exec_alloc
                    SET ret_qty = v_ret_take,
                        net_take = take_qty - v_ret_take
                    WHERE ord = v_alloc_id;

                    v_rem_return := v_rem_return - v_ret_take;
                END LOOP;
            END;
        END IF;

        -- Commit deductions
        DECLARE
            v_alloc_rec RECORD;
        BEGIN
            FOR v_alloc_rec IN SELECT * FROM temp_exec_alloc ORDER BY ord ASC
            LOOP
                UPDATE public.batches
                SET available_quantity = available_quantity - v_alloc_rec.net_take,
                    updated_at = CURRENT_TIMESTAMP
                WHERE id = v_alloc_rec.batch_id;

                INSERT INTO public.dispatch_batches (
                    dispatch_id, batch_no, batch_id, quantity, returned_quantity, net_quantity, uom, batch_date
                ) VALUES (
                    p_dispatch_id, v_alloc_rec.batch_no, v_alloc_rec.batch_id, v_alloc_rec.take_qty, v_alloc_rec.ret_qty, v_alloc_rec.net_take, v_alloc_rec.uom, v_alloc_rec.batch_date
                );

                v_allocations := v_allocations || jsonb_build_object(
                    'batch_id', v_alloc_rec.batch_id,
                    'batch_no', v_alloc_rec.batch_no,
                    'batch_date', v_alloc_rec.batch_date,
                    'quantity', v_alloc_rec.take_qty,
                    'returned_quantity', v_alloc_rec.ret_qty,
                    'net_quantity', v_alloc_rec.net_take,
                    'uom', v_alloc_rec.uom
                );
            END LOOP;
        END;

        DROP TABLE IF EXISTS temp_exec_alloc;

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
    $$;
    """)

    print("9. Creating updated atomic delete_dispatch RPC...")
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

        -- Delete dispatch_batches and dispatch
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
    $$;
    """)

    print("10. Creating/updating Transfer RPCs with return_quantity and exact lot reconciliation...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.create_transfer(
        p_transfer JSONB, 
        p_idempotency_key TEXT DEFAULT NULL::TEXT
    )
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
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

        v_dept := TRIM(COALESCE(p_transfer->>'department', ''));
        v_person := TRIM(COALESCE(p_transfer->>'person', ''));
        v_units := TRIM(COALESCE(p_transfer->>'units', 'kg'));
        
        IF p_transfer->>'date' IS NOT NULL AND TRIM(p_transfer->>'date') != '' THEN
            v_date := (p_transfer->>'date')::DATE;
        ELSE
            v_date := CURRENT_DATE;
        END IF;
        
        v_created_at := CURRENT_TIMESTAMP;
        v_outward := ROUND(COALESCE((p_transfer->>'outward')::NUMERIC, 0.000), 3);
        v_return_units := ROUND(COALESCE((p_transfer->>'return_units')::NUMERIC, 0.000), 3);

        IF v_outward < 0 THEN
            RAISE EXCEPTION 'Outward quantity cannot be negative.';
        END IF;
        IF v_return_units < 0 THEN
            RAISE EXCEPTION 'Return quantity cannot be negative.';
        END IF;
        IF v_outward = 0 AND v_return_units = 0 THEN
            RAISE EXCEPTION 'Either Outward Quantity or Return Quantity must be greater than zero.';
        END IF;

        -- Find Material Master record with atomic lock
        SELECT id, quantity, description, unit
        INTO v_mat_id, v_current_stock, v_desc, v_units
        FROM public.materials
        WHERE material_code = v_code
        FOR UPDATE;

        IF v_mat_id IS NULL THEN
            RAISE EXCEPTION 'Material not found in Material Master for code: %', v_code;
        END IF;

        -- Check available stock in material_lots
        SELECT COALESCE(SUM(available_quantity), 0)
        INTO v_total_lot_stock
        FROM public.material_lots
        WHERE material_code = v_code AND available_quantity > 0;

        -- If material has general stock but no lots yet, backfill a lot
        IF v_total_lot_stock < v_current_stock AND v_current_stock > 0 THEN
            INSERT INTO public.material_lots (
                material_id, material_code, lot_no, lot_date, initial_quantity, available_quantity, uom
            ) VALUES (
                v_mat_id, v_code, 'LOT-001', v_date, (v_current_stock - v_total_lot_stock), (v_current_stock - v_total_lot_stock), v_units
            );
            v_total_lot_stock := v_current_stock;
        END IF;

        -- Outward cannot exceed available lot stock
        IF v_outward > v_total_lot_stock THEN
            RAISE EXCEPTION 'Insufficient stock. Available: % %, Requested Outward: % %', v_total_lot_stock, v_units, v_outward, v_units;
        END IF;

        -- Net Change = Return Quantity - Outward Quantity
        v_net_change := v_return_units - v_outward;
        v_remaining_balance := ROUND(v_current_stock + v_net_change, 3);

        IF v_remaining_balance < 0 THEN
            RAISE EXCEPTION 'Transfer would result in negative final stock (% %)', v_remaining_balance, v_units;
        END IF;

        -- Update Material master
        UPDATE public.materials
        SET quantity = v_remaining_balance,
            last_updated = CURRENT_TIMESTAMP
        WHERE id = v_mat_id;

        -- Save transfer record
        INSERT INTO public.transfers (
            date, code, description, lot_no, outward, units, department, person, return_units, availability, created_at
        ) VALUES (
            v_date, v_code, v_desc, '', v_outward, v_units, v_dept, v_person, v_return_units, v_remaining_balance, v_created_at
        ) RETURNING id INTO v_transfer_id;

        -- Case A: Outward > 0 (Deduct lots via FIFO)
        v_needed := v_outward;
        IF v_needed > 0 THEN
            FOR v_lot IN 
                SELECT id, lot_no, available_quantity 
                FROM public.material_lots 
                WHERE material_code = v_code AND available_quantity > 0
                ORDER BY lot_date ASC, id ASC
                FOR UPDATE
            LOOP
                EXIT WHEN v_needed <= 0;

                v_take := LEAST(v_lot.available_quantity, v_needed);

                UPDATE public.material_lots
                SET available_quantity = available_quantity - v_take
                WHERE id = v_lot.id;

                INSERT INTO public.transfer_lot_allocations (
                    transfer_id, lot_id, lot_no, quantity, created_at
                ) VALUES (
                    v_transfer_id, v_lot.id, v_lot.lot_no, v_take, v_created_at
                );

                IF v_lots_allocated = '' THEN
                    v_lots_allocated := v_lot.lot_no;
                ELSE
                    v_lots_allocated := v_lots_allocated || ', ' || v_lot.lot_no;
                END IF;

                v_needed := v_needed - v_take;
            END LOOP;
        END IF;

        -- Case B: Return > 0 (Credit back into lots)
        IF v_return_units > 0 THEN
            -- If lots were allocated in this transfer, restore return into them in reverse FIFO
            IF v_outward > 0 THEN
                DECLARE
                    v_rem_ret NUMERIC(15, 3) := v_return_units;
                    v_alloc RECORD;
                    v_cred NUMERIC(15, 3);
                BEGIN
                    FOR v_alloc IN 
                        SELECT id, lot_id, quantity 
                        FROM public.transfer_lot_allocations 
                        WHERE transfer_id = v_transfer_id 
                        ORDER BY id DESC 
                    LOOP
                        EXIT WHEN v_rem_ret <= 0;
                        v_cred := LEAST(v_alloc.quantity, v_rem_ret);
                        
                        UPDATE public.material_lots
                        SET available_quantity = available_quantity + v_cred
                        WHERE id = v_alloc.lot_id;

                        UPDATE public.transfer_lot_allocations
                        SET quantity = quantity - v_cred
                        WHERE id = v_alloc.id;

                        v_rem_ret := v_rem_ret - v_cred;
                    END LOOP;

                    -- If return exceeded outward, add remaining excess to the oldest or default lot
                    IF v_rem_ret > 0 THEN
                        DECLARE
                            v_target_lot_id BIGINT;
                        BEGIN
                            SELECT id INTO v_target_lot_id 
                            FROM public.material_lots 
                            WHERE material_code = v_code 
                            ORDER BY id DESC LIMIT 1;

                            IF v_target_lot_id IS NOT NULL THEN
                                UPDATE public.material_lots
                                SET available_quantity = available_quantity + v_rem_ret
                                WHERE id = v_target_lot_id;

                                INSERT INTO public.transfer_lot_allocations (
                                    transfer_id, lot_id, lot_no, quantity, created_at
                                ) VALUES (
                                    v_transfer_id, v_target_lot_id, 'RETURN', -v_rem_ret, v_created_at
                                );
                            END IF;
                        END;
                    END IF;
                END;
            ELSE
                -- Pure return (outward = 0, return > 0): add directly to newest lot
                DECLARE
                    v_target_lot RECORD;
                BEGIN
                    SELECT * INTO v_target_lot 
                    FROM public.material_lots 
                    WHERE material_code = v_code 
                    ORDER BY id DESC LIMIT 1;

                    IF v_target_lot.id IS NULL THEN
                        INSERT INTO public.material_lots (
                            material_id, material_code, lot_no, lot_date, initial_quantity, available_quantity, uom
                        ) VALUES (
                            v_mat_id, v_code, 'RET-001', v_date, v_return_units, v_return_units, v_units
                        ) RETURNING * INTO v_target_lot;
                    ELSE
                        UPDATE public.material_lots
                        SET available_quantity = available_quantity + v_return_units
                        WHERE id = v_target_lot.id;
                    END IF;

                    INSERT INTO public.transfer_lot_allocations (
                        transfer_id, lot_id, lot_no, quantity, created_at
                    ) VALUES (
                        v_transfer_id, v_target_lot.id, v_target_lot.lot_no, -v_return_units, v_created_at
                    );

                    v_lots_allocated := v_target_lot.lot_no;
                END;
            END IF;
        END IF;

        -- Update transfers with allocated lot summary
        UPDATE public.transfers
        SET lot_no = v_lots_allocated
        WHERE id = v_transfer_id;

        v_result := jsonb_build_object(
            'success', true,
            'transfer_id', v_transfer_id,
            'lot_no', v_lots_allocated,
            'outward', v_outward,
            'return_units', v_return_units,
            'net_change', v_net_change,
            'remaining_balance', v_remaining_balance
        );

        -- Store idempotency
        IF v_idempotency_key IS NOT NULL AND TRIM(v_idempotency_key) != '' THEN
            INSERT INTO public.idempotency_keys (idempotency_key, operation_type, user_id, device_id, status, response)
            VALUES (
                v_idempotency_key, 
                'transfer_create', 
                auth.uid(), 
                p_transfer->>'device_id', 
                'completed', 
                v_result
            ) ON CONFLICT (idempotency_key) DO UPDATE SET response = EXCLUDED.response;
        END IF;

        -- Audit log
        INSERT INTO public.audit_logs (user_id, operation, module, record_id, details)
        VALUES (
            auth.uid(), 
            'CREATE', 
            'transfers', 
            v_transfer_id::TEXT, 
            jsonb_build_object('code', v_code, 'outward', v_outward, 'return', v_return_units, 'department', v_dept)
        );

        RETURN v_result;
    END;
    $$;
    """)

    print("11. Creating updated delete_transfer RPC...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.delete_transfer(p_transfer_id BIGINT)
    RETURNS BOOLEAN
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        v_transfer RECORD;
        v_alloc RECORD;
        v_net_change NUMERIC(15, 3);
    BEGIN
        SELECT * INTO v_transfer FROM public.transfers WHERE id = p_transfer_id FOR UPDATE;
        IF v_transfer IS NULL THEN
            RETURN false;
        END IF;

        -- Restore exact quantities to exact lots from transfer_lot_allocations
        FOR v_alloc IN SELECT lot_id, quantity FROM public.transfer_lot_allocations WHERE transfer_id = p_transfer_id
        LOOP
            UPDATE public.material_lots
            SET available_quantity = available_quantity + v_alloc.quantity
            WHERE id = v_alloc.lot_id;
        END LOOP;

        -- Revert materials master quantity: old net change was return_units - outward
        v_net_change := v_transfer.return_units - v_transfer.outward;

        UPDATE public.materials
        SET quantity = GREATEST(0, ROUND(quantity - v_net_change, 3)),
            last_updated = CURRENT_TIMESTAMP
        WHERE material_code = v_transfer.code;

        -- Delete transfer (transfer_lot_allocations cascade automatically)
        DELETE FROM public.transfers WHERE id = p_transfer_id;

        INSERT INTO public.audit_logs (user_id, operation, module, record_id, details)
        VALUES (auth.uid(), 'DELETE', 'transfers', p_transfer_id::TEXT, jsonb_build_object('code', v_transfer.code, 'net_reversed', -v_net_change));

        RETURN true;
    END;
    $$;
    """)

    print("12. Creating updated update_transfer RPC...")
    cur.execute("""
    CREATE OR REPLACE FUNCTION public.update_transfer(p_transfer_id BIGINT, p_transfer JSONB)
    RETURNS JSONB
    LANGUAGE plpgsql
    SECURITY DEFINER
    AS $$
    DECLARE
        v_old_transfer RECORD;
        v_alloc RECORD;
        v_code TEXT;
        v_dept TEXT;
        v_person TEXT;
        v_units TEXT;
        v_date DATE;
        v_new_outward NUMERIC(15, 3);
        v_new_return NUMERIC(15, 3);
        v_old_net NUMERIC(15, 3);
        v_new_net NUMERIC(15, 3);
        v_current_stock NUMERIC(15, 3);
        v_adjusted_stock NUMERIC(15, 3);
        v_final_stock NUMERIC(15, 3);
        v_mat_id BIGINT;
        
        v_needed NUMERIC(15, 3);
        v_lot RECORD;
        v_take NUMERIC(15, 3);
        v_lots_allocated TEXT := '';
        v_result JSONB;
    BEGIN
        SELECT * INTO v_old_transfer FROM public.transfers WHERE id = p_transfer_id FOR UPDATE;
        IF v_old_transfer IS NULL THEN
            RAISE EXCEPTION 'Transfer with ID % not found', p_transfer_id;
        END IF;

        v_code := TRIM(COALESCE(p_transfer->>'code', v_old_transfer.code));
        v_dept := TRIM(COALESCE(p_transfer->>'department', v_old_transfer.department, ''));
        v_person := TRIM(COALESCE(p_transfer->>'person', v_old_transfer.person, ''));
        v_units := TRIM(COALESCE(p_transfer->>'units', v_old_transfer.units, 'kg'));
        v_date := (COALESCE(p_transfer->>'date', v_old_transfer.date::TEXT))::DATE;
        v_new_outward := ROUND(COALESCE((p_transfer->>'outward')::NUMERIC, v_old_transfer.outward), 3);
        v_new_return := ROUND(COALESCE((p_transfer->>'return_units')::NUMERIC, v_old_transfer.return_units), 3);

        IF v_new_outward < 0 THEN
            RAISE EXCEPTION 'Outward quantity cannot be negative.';
        END IF;
        IF v_new_return < 0 THEN
            RAISE EXCEPTION 'Return quantity cannot be negative.';
        END IF;
        IF v_new_outward = 0 AND v_new_return = 0 THEN
            RAISE EXCEPTION 'Either Outward Quantity or Return Quantity must be greater than zero.';
        END IF;

        -- 1. Restore exact previous lot allocations
        FOR v_alloc IN SELECT lot_id, quantity FROM public.transfer_lot_allocations WHERE transfer_id = p_transfer_id
        LOOP
            UPDATE public.material_lots
            SET available_quantity = available_quantity + v_alloc.quantity
            WHERE id = v_alloc.lot_id;
        END LOOP;
        DELETE FROM public.transfer_lot_allocations WHERE transfer_id = p_transfer_id;

        -- 2. Reverse previous materials quantity impact
        SELECT id, quantity, description, unit
        INTO v_mat_id, v_current_stock, v_dept, v_units
        FROM public.materials
        WHERE material_code = v_code
        FOR UPDATE;

        IF v_mat_id IS NULL THEN
            RAISE EXCEPTION 'Material not found in Material Master for code: %', v_code;
        END IF;

        v_old_net := v_old_transfer.return_units - v_old_transfer.outward;
        v_adjusted_stock := v_current_stock - v_old_net;

        -- Check available stock
        SELECT COALESCE(SUM(available_quantity), 0)
        INTO v_current_stock
        FROM public.material_lots
        WHERE material_code = v_code AND available_quantity > 0;

        IF v_new_outward > v_current_stock THEN
            RAISE EXCEPTION 'Insufficient stock. Available: % %, Requested Outward: % %', v_current_stock, v_units, v_new_outward, v_units;
        END IF;

        v_new_net := v_new_return - v_new_outward;
        v_final_stock := ROUND(v_adjusted_stock + v_new_net, 3);

        IF v_final_stock < 0 THEN
            RAISE EXCEPTION 'Transfer edit would result in negative final stock (% %)', v_final_stock, v_units;
        END IF;

        UPDATE public.materials
        SET quantity = v_final_stock,
            last_updated = CURRENT_TIMESTAMP
        WHERE id = v_mat_id;

        -- 3. Re-allocate lots FIFO
        v_needed := v_new_outward;
        IF v_needed > 0 THEN
            FOR v_lot IN 
                SELECT id, lot_no, available_quantity 
                FROM public.material_lots 
                WHERE material_code = v_code AND available_quantity > 0
                ORDER BY lot_date ASC, id ASC
                FOR UPDATE
            LOOP
                EXIT WHEN v_needed <= 0;

                v_take := LEAST(v_lot.available_quantity, v_needed);

                UPDATE public.material_lots
                SET available_quantity = available_quantity - v_take
                WHERE id = v_lot.id;

                INSERT INTO public.transfer_lot_allocations (
                    transfer_id, lot_id, lot_no, quantity, created_at
                ) VALUES (
                    p_transfer_id, v_lot.id, v_lot.lot_no, v_take, CURRENT_TIMESTAMP
                );

                IF v_lots_allocated = '' THEN
                    v_lots_allocated := v_lot.lot_no;
                ELSE
                    v_lots_allocated := v_lots_allocated || ', ' || v_lot.lot_no;
                END IF;

                v_needed := v_needed - v_take;
            END LOOP;
        END IF;

        -- Apply new return
        IF v_new_return > 0 THEN
            IF v_new_outward > 0 THEN
                DECLARE
                    v_rem_ret NUMERIC(15, 3) := v_new_return;
                    v_alloc_r RECORD;
                    v_cred NUMERIC(15, 3);
                BEGIN
                    FOR v_alloc_r IN 
                        SELECT id, lot_id, quantity 
                        FROM public.transfer_lot_allocations 
                        WHERE transfer_id = p_transfer_id 
                        ORDER BY id DESC 
                    LOOP
                        EXIT WHEN v_rem_ret <= 0;
                        v_cred := LEAST(v_alloc_r.quantity, v_rem_ret);
                        
                        UPDATE public.material_lots
                        SET available_quantity = available_quantity + v_cred
                        WHERE id = v_alloc_r.lot_id;

                        UPDATE public.transfer_lot_allocations
                        SET quantity = quantity - v_cred
                        WHERE id = v_alloc_r.id;

                        v_rem_ret := v_rem_ret - v_cred;
                    END LOOP;

                    IF v_rem_ret > 0 THEN
                        DECLARE
                            v_target_lot_id BIGINT;
                        BEGIN
                            SELECT id INTO v_target_lot_id 
                            FROM public.material_lots 
                            WHERE material_code = v_code 
                            ORDER BY id DESC LIMIT 1;

                            IF v_target_lot_id IS NOT NULL THEN
                                UPDATE public.material_lots
                                SET available_quantity = available_quantity + v_rem_ret
                                WHERE id = v_target_lot_id;

                                INSERT INTO public.transfer_lot_allocations (
                                    transfer_id, lot_id, lot_no, quantity, created_at
                                ) VALUES (
                                    p_transfer_id, v_target_lot_id, 'RETURN', -v_rem_ret, CURRENT_TIMESTAMP
                                );
                            END IF;
                        END;
                    END IF;
                END;
            ELSE
                DECLARE
                    v_target_lot RECORD;
                BEGIN
                    SELECT * INTO v_target_lot 
                    FROM public.material_lots 
                    WHERE material_code = v_code 
                    ORDER BY id DESC LIMIT 1;

                    IF v_target_lot.id IS NOT NULL THEN
                        UPDATE public.material_lots
                        SET available_quantity = available_quantity + v_new_return
                        WHERE id = v_target_lot.id;

                        INSERT INTO public.transfer_lot_allocations (
                            transfer_id, lot_id, lot_no, quantity, created_at
                        ) VALUES (
                            p_transfer_id, v_target_lot.id, v_target_lot.lot_no, -v_new_return, CURRENT_TIMESTAMP
                        );

                        v_lots_allocated := v_target_lot.lot_no;
                    END IF;
                END;
            END IF;
        END IF;

        -- 4. Update transfer header
        UPDATE public.transfers
        SET date = v_date,
            code = v_code,
            department = v_dept,
            person = v_person,
            outward = v_new_outward,
            return_units = v_new_return,
            units = v_units,
            lot_no = v_lots_allocated,
            availability = v_final_stock
        WHERE id = p_transfer_id;

        v_result := jsonb_build_object(
            'success', true,
            'transfer_id', p_transfer_id,
            'lot_no', v_lots_allocated,
            'outward', v_new_outward,
            'return_units', v_new_return,
            'net_change', v_new_net,
            'remaining_balance', v_final_stock
        );

        INSERT INTO public.audit_logs (user_id, operation, module, record_id, details)
        VALUES (auth.uid(), 'UPDATE', 'transfers', p_transfer_id::TEXT, v_result);

        RETURN v_result;
    END;
    $$;
    """)

    conn.commit()
    print("SUCCESS: Database migration and RPC update completed successfully!")

except Exception as e:
    conn.rollback()
    print("FAILED during migration:", e)
    raise e
finally:
    cur.close()
    conn.close()
