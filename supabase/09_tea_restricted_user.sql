-- ============================================================================
-- BENCHMARK MMS — RESTRICTED TEA USER ACCESS CONTROL & CATEGORY ENFORCEMENT
-- ============================================================================

-- 1. Ensure user_profiles_role_check constraint allows TEA_USER
ALTER TABLE public.user_profiles 
DROP CONSTRAINT IF EXISTS user_profiles_role_check;

ALTER TABLE public.user_profiles 
ADD CONSTRAINT user_profiles_role_check 
CHECK (role = ANY (ARRAY['OWNER'::text, 'ADMIN'::text, 'MANAGER'::text, 'STAFF'::text, 'VIEWER'::text, 'TEA_USER'::text]));

-- 2. Additive category column on transfers for fast querying and indexing
ALTER TABLE public.transfers 
ADD COLUMN IF NOT EXISTS category TEXT;

-- Backfill existing transfers category non-destructively from materials master
UPDATE public.transfers t
SET category = m.category
FROM public.materials m
WHERE m.material_code = t.code AND t.category IS NULL;

CREATE INDEX IF NOT EXISTS idx_transfers_category ON public.transfers(category);

-- 3. HELPER FUNCTION: Check if the authenticated user is the restricted Tea user
CREATE OR REPLACE FUNCTION public.is_tea_user()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_role TEXT;
    v_username TEXT;
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT role, username INTO v_role, v_username
    FROM public.user_profiles
    WHERE id = auth.uid();

    IF UPPER(COALESCE(v_role, '')) = 'TEA_USER' OR LOWER(COALESCE(v_username, '')) = 'bm' THEN
        RETURN TRUE;
    END IF;

    SELECT (raw_user_meta_data->>'role'), (raw_user_meta_data->>'username') 
    INTO v_role, v_username
    FROM auth.users
    WHERE id = auth.uid();

    IF UPPER(COALESCE(v_role, '')) = 'TEA_USER' OR LOWER(COALESCE(v_username, '')) = 'bm' THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

-- 4. HELPER FUNCTION: Verify if a material/product code belongs to TEA category
CREATE OR REPLACE FUNCTION public.is_tea_product(p_code TEXT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
STABLE
AS $$
DECLARE
    v_clean_code TEXT;
    v_exists BOOLEAN := FALSE;
BEGIN
    v_clean_code := TRIM(COALESCE(p_code, ''));
    IF v_clean_code = '' THEN
        RETURN FALSE;
    END IF;

    -- Check canonical category in materials table
    SELECT TRUE INTO v_exists
    FROM public.materials
    WHERE LOWER(TRIM(material_code)) = LOWER(v_clean_code)
      AND UPPER(TRIM(category)) = 'TEA'
    LIMIT 1;

    IF COALESCE(v_exists, FALSE) THEN
        RETURN TRUE;
    END IF;

    -- Check storage_products
    SELECT TRUE INTO v_exists
    FROM public.storage_products
    WHERE LOWER(TRIM(product_code)) = LOWER(v_clean_code)
      AND UPPER(TRIM(category)) = 'TEA'
    LIMIT 1;

    IF COALESCE(v_exists, FALSE) THEN
        RETURN TRUE;
    END IF;

    -- Check batches
    SELECT TRUE INTO v_exists
    FROM public.batches
    WHERE LOWER(TRIM(material_code)) = LOWER(v_clean_code)
      AND UPPER(TRIM(category)) = 'TEA'
    LIMIT 1;

    RETURN COALESCE(v_exists, FALSE);
END;
$$;

-- 5. RPC: get_transfer_available_materials with Tea category enforcement
CREATE OR REPLACE FUNCTION public.get_transfer_available_materials(p_category text DEFAULT NULL::text)
RETURNS SETOF materials
LANGUAGE plpgsql
STABLE SECURITY DEFINER
AS $$
DECLARE
    v_filter_cat TEXT;
BEGIN
    IF public.is_tea_user() THEN
        v_filter_cat := 'TEA';
    ELSIF p_category IS NOT NULL AND TRIM(p_category) != '' THEN
        v_filter_cat := UPPER(TRIM(p_category));
    ELSE
        v_filter_cat := NULL;
    END IF;

    RETURN QUERY
    SELECT DISTINCT m.*
    FROM public.materials m
    JOIN public.material_lots ml ON ml.material_code = m.material_code
    WHERE ml.available_quantity > 0 AND m.quantity > 0
      AND (v_filter_cat IS NULL OR UPPER(TRIM(m.category)) = v_filter_cat)
    ORDER BY m.material_code ASC;
END;
$$;

-- 6. RPC: create_transfer with server-side category authorization
CREATE OR REPLACE FUNCTION public.create_transfer(p_transfer jsonb, p_idempotency_key text DEFAULT NULL::text)
RETURNS jsonb
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

    -- SERVER-SIDE SECURITY: Tea account category enforcement
    IF public.is_tea_user() AND UPPER(COALESCE(v_mat_category, '')) != 'TEA' THEN
        RAISE EXCEPTION 'Access Denied: Tea account is restricted to materials in the TEA category only. Material "%" has category "%".', 
            v_code, COALESCE(v_mat_category, 'UNKNOWN');
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

    -- Return Handling
    IF v_return_units > 0 THEN
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

-- 7. RPC: update_transfer with category authorization
CREATE OR REPLACE FUNCTION public.update_transfer(p_transfer_id bigint, p_transfer jsonb, p_idempotency_key text DEFAULT NULL::text)
RETURNS jsonb
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
    v_mat_category TEXT;
    
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

    SELECT id, category INTO v_mat_id, v_mat_category FROM public.materials WHERE material_code = v_code;

    -- Security check for Tea user
    IF public.is_tea_user() THEN
        IF UPPER(COALESCE(v_mat_category, '')) != 'TEA' OR UPPER(COALESCE(v_old_transfer.category, '')) != 'TEA' THEN
            RAISE EXCEPTION 'Access Denied: Tea account can only modify transfers in the TEA category.';
        END IF;
    END IF;

    IF v_new_outward < 0 THEN
        RAISE EXCEPTION 'Outward quantity cannot be negative.';
    END IF;
    IF v_new_return < 0 THEN
        RAISE EXCEPTION 'Return quantity cannot be negative.';
    END IF;
    IF v_new_outward = 0 AND v_new_return = 0 THEN
        RAISE EXCEPTION 'Either Outward Quantity or Return Quantity must be greater than zero.';
    END IF;

    -- 1. Restore previous lot deductions
    FOR v_alloc IN 
        SELECT lot_id, quantity 
        FROM public.transfer_lot_allocations 
        WHERE transfer_id = p_transfer_id 
        ORDER BY id DESC
    LOOP
        UPDATE public.material_lots
        SET available_quantity = available_quantity + v_alloc.quantity
        WHERE id = v_alloc.lot_id;
    END LOOP;

    DELETE FROM public.transfer_lot_allocations WHERE transfer_id = p_transfer_id;

    -- 2. Reverse previous net effect on materials stock
    v_old_net := v_old_transfer.return_units - v_old_transfer.outward;
    
    SELECT quantity INTO v_current_stock 
    FROM public.materials 
    WHERE material_code = v_old_transfer.code 
    FOR UPDATE;

    v_adjusted_stock := v_current_stock - v_old_net;

    -- If material code changed, restore old material and lock new material
    IF v_code != v_old_transfer.code THEN
        UPDATE public.materials 
        SET quantity = v_adjusted_stock, last_updated = CURRENT_TIMESTAMP 
        WHERE material_code = v_old_transfer.code;

        SELECT id, quantity, category INTO v_mat_id, v_current_stock, v_mat_category 
        FROM public.materials 
        WHERE material_code = v_code 
        FOR UPDATE;

        IF v_mat_id IS NULL THEN
            RAISE EXCEPTION 'Target material % not found in Material Master.', v_code;
        END IF;
        v_adjusted_stock := v_current_stock;
    END IF;

    -- 3. Check new outward feasibility
    v_new_net := v_new_return - v_new_outward;
    v_final_stock := v_adjusted_stock + v_new_net;

    IF v_final_stock < 0 THEN
        RAISE EXCEPTION 'Updated transfer would result in negative stock (% + % = %).', 
            v_adjusted_stock, v_new_net, v_final_stock;
    END IF;

    -- 4. Deduct new outward in FIFO order
    IF v_new_outward > 0 THEN
        v_needed := v_new_outward;
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

        IF v_needed > 0 THEN
            RAISE EXCEPTION 'Insufficient stock in active lots for updated outward quantity.';
        END IF;
    END IF;

    -- 5. Return quantity handling
    IF v_new_return > 0 THEN
        DECLARE
            v_target_lot_id BIGINT;
        BEGIN
            SELECT id INTO v_target_lot_id 
            FROM public.material_lots 
            WHERE material_code = v_code 
            ORDER BY id DESC LIMIT 1;

            IF v_target_lot_id IS NOT NULL THEN
                UPDATE public.material_lots
                SET available_quantity = available_quantity + v_new_return
                WHERE id = v_target_lot_id;

                INSERT INTO public.transfer_lot_allocations (
                    transfer_id, lot_id, lot_no, quantity, created_at
                ) VALUES (
                    p_transfer_id, v_target_lot_id, 'RETURN', -v_new_return, CURRENT_TIMESTAMP
                );
            END IF;
        END;
    END IF;

    -- Update parent material quantity
    UPDATE public.materials
    SET quantity = v_final_stock,
        last_updated = CURRENT_TIMESTAMP
    WHERE material_code = v_code;

    -- Update transfers record
    UPDATE public.transfers
    SET code = v_code,
        date = v_date,
        outward = v_new_outward,
        return_units = v_new_return,
        units = v_units,
        department = v_dept,
        person = v_person,
        availability = v_final_stock,
        lot_no = v_lots_allocated,
        category = COALESCE(v_mat_category, v_old_transfer.category)
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
    VALUES (
        auth.uid(), 
        'UPDATE', 
        'transfers', 
        p_transfer_id::TEXT, 
        jsonb_build_object('code', v_code, 'outward', v_new_outward, 'return', v_new_return, 'department', v_dept)
    );

    RETURN v_result;
END;
$$;

-- 8. RPC: delete_transfer with category authorization
CREATE OR REPLACE FUNCTION public.delete_transfer(p_transfer_id bigint)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_transfer RECORD;
    v_alloc RECORD;
    v_net_change NUMERIC(15, 3);
    v_cat TEXT;
BEGIN
    SELECT * INTO v_transfer FROM public.transfers WHERE id = p_transfer_id FOR UPDATE;
    IF v_transfer IS NULL THEN
        RETURN false;
    END IF;

    -- Resolve category
    v_cat := v_transfer.category;
    IF v_cat IS NULL THEN
        SELECT category INTO v_cat FROM public.materials WHERE material_code = v_transfer.code;
    END IF;

    -- Security check
    IF public.is_tea_user() AND UPPER(COALESCE(v_cat, '')) != 'TEA' THEN
        RAISE EXCEPTION 'Access Denied: Tea account cannot delete non-Tea transfer records.';
    END IF;

    -- Restore exact quantities to exact lots
    FOR v_alloc IN SELECT lot_id, quantity FROM public.transfer_lot_allocations WHERE transfer_id = p_transfer_id
    LOOP
        UPDATE public.material_lots
        SET available_quantity = available_quantity + v_alloc.quantity
        WHERE id = v_alloc.lot_id;
    END LOOP;

    -- Revert materials master quantity
    v_net_change := v_transfer.return_units - v_transfer.outward;

    UPDATE public.materials
    SET quantity = GREATEST(0, ROUND(quantity - v_net_change, 3)),
        last_updated = CURRENT_TIMESTAMP
    WHERE material_code = v_transfer.code;

    DELETE FROM public.transfers WHERE id = p_transfer_id;

    INSERT INTO public.audit_logs (user_id, operation, module, record_id, details)
    VALUES (auth.uid(), 'DELETE', 'transfers', p_transfer_id::TEXT, jsonb_build_object('code', v_transfer.code, 'net_reversed', -v_net_change));

    RETURN true;
END;
$$;

-- 9. RPC: get_storage_products with Tea category restriction
CREATE OR REPLACE FUNCTION public.get_storage_products(p_search text DEFAULT NULL::text, p_category text DEFAULT NULL::text)
RETURNS SETOF storage_products
LANGUAGE sql
STABLE SECURITY DEFINER
AS $$
    SELECT sp.* FROM public.storage_products sp
    WHERE (p_search IS NULL OR TRIM(p_search) = '' OR
           sp.product_code ILIKE '%' || TRIM(p_search) || '%' OR
           sp.product_name ILIKE '%' || TRIM(p_search) || '%')
      AND (
          (p_category IS NULL OR TRIM(p_category) = '' OR 
           UPPER(sp.category) = UPPER(TRIM(p_category)) OR
           EXISTS (SELECT 1 FROM public.materials m WHERE m.material_code = sp.product_code AND UPPER(m.category) = UPPER(TRIM(p_category))))
      )
      AND (
          NOT public.is_tea_user() OR
          UPPER(sp.category) = 'TEA' OR
          EXISTS (SELECT 1 FROM public.materials m WHERE m.material_code = sp.product_code AND UPPER(m.category) = 'TEA')
      )
    ORDER BY sp.product_name ASC, sp.product_code ASC;
$$;

-- 10. RPC: upsert_storage_product with Tea user category restriction
CREATE OR REPLACE FUNCTION public.upsert_storage_product(p_product_code text, p_product_name text, p_uom text DEFAULT 'kg'::text, p_grade text DEFAULT 'STANDARD'::text, p_category text DEFAULT 'Finished Goods'::text)
RETURNS jsonb
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
    v_mat_cat TEXT;
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

    -- If created by Tea user:
    IF public.is_tea_user() THEN
        v_clean_category := 'TEA';
        -- Check if material code exists in materials with non-tea category
        SELECT category INTO v_mat_cat FROM public.materials WHERE material_code = v_clean_code;
        IF v_mat_cat IS NOT NULL AND UPPER(v_mat_cat) != 'TEA' THEN
            RAISE EXCEPTION 'Access Denied: Product "%" belongs to category "%" and cannot be registered by Tea account.',
                v_clean_code, v_mat_cat;
        END IF;
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

-- 11. RPC: get_dispatch_available_products with Tea category restriction
CREATE OR REPLACE FUNCTION public.get_dispatch_available_products(p_search text DEFAULT NULL::text, p_category text DEFAULT NULL::text)
RETURNS TABLE(product_code text, product_name text, uom text, grade text, category text, total_available numeric, batch_count bigint)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_term TEXT;
    v_is_tea BOOLEAN;
BEGIN
    v_term := NULLIF(TRIM(p_search), '');
    v_is_tea := public.is_tea_user() OR (p_category IS NOT NULL AND UPPER(TRIM(p_category)) = 'TEA');

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
      AND (
          NOT v_is_tea OR
          UPPER(COALESCE(b.category, '')) = 'TEA' OR
          EXISTS (
              SELECT 1 FROM public.materials m 
              WHERE (m.id = b.material_id OR m.material_code = b.material_code) 
                AND UPPER(m.category) = 'TEA'
          ) OR
          EXISTS (
              SELECT 1 FROM public.storage_products sp
              WHERE sp.product_code = b.material_code
                AND UPPER(sp.category) = 'TEA'
          )
      )
    GROUP BY b.material_code
    HAVING SUM(b.available_quantity) > 0.0001
    ORDER BY b.material_code ASC;
END;
$$;

-- 12. RPC: create_dispatch_fifo with Tea category authorization
CREATE OR REPLACE FUNCTION public.create_dispatch_fifo(p_dispatch jsonb, p_idempotency_key text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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

    -- SECURITY CHECK FOR TEA USER:
    IF public.is_tea_user() AND NOT public.is_tea_product(v_prod_code) THEN
        RAISE EXCEPTION 'Access Denied: Tea account is restricted to dispatching TEA category products only. Product "%" is not a Tea product.',
            v_prod_code;
    END IF;

    v_req_qty := ROUND(COALESCE((p_dispatch->>'quantity')::NUMERIC, 0), 3);
    v_ret_qty := ROUND(COALESCE((p_dispatch->>'return_quantity')::NUMERIC, 0), 3);

    IF v_req_qty <= 0 THEN
        RAISE EXCEPTION 'Dispatch quantity must be strictly greater than 0.';
    END IF;
    IF v_ret_qty < 0 THEN
        RAISE EXCEPTION 'Return quantity cannot be negative.';
    END IF;
    IF v_ret_qty > v_req_qty THEN
        RAISE EXCEPTION 'Return quantity (%) cannot exceed dispatched quantity (%).', v_ret_qty, v_req_qty;
    END IF;

    v_net_qty := v_req_qty - v_ret_qty;
    v_prod_name := TRIM(COALESCE(p_dispatch->>'product', v_prod_code));
    v_category := TRIM(COALESCE(p_dispatch->>'category', 'Finished Goods'));
    IF public.is_tea_user() THEN
        v_category := 'TEA';
    END IF;
    v_grade := TRIM(COALESCE(p_dispatch->>'grade', 'STANDARD'));
    v_location := TRIM(COALESCE(p_dispatch->>'location', ''));
    v_dept := TRIM(COALESCE(p_dispatch->>'department', ''));
    v_remarks := TRIM(COALESCE(p_dispatch->>'remarks', ''));
    v_unit := TRIM(COALESCE(p_dispatch->>'units', 'kg'));

    IF p_dispatch->>'date' IS NOT NULL AND TRIM(p_dispatch->>'date') != '' THEN
        v_date := (p_dispatch->>'date')::DATE;
    ELSE
        v_date := CURRENT_DATE;
    END IF;

    v_storage_prod_id := (p_dispatch->>'storage_product_id')::BIGINT;
    v_created_by := auth.uid();

    -- Validate stock across active, non-expired batches
    SELECT COALESCE(SUM(available_quantity), 0) INTO v_total_available
    FROM public.batches
    WHERE LOWER(TRIM(material_code)) = LOWER(v_prod_code)
      AND available_quantity > 0.0001
      AND (expiry_date IS NULL OR expiry_date >= CURRENT_DATE);

    IF v_total_available < v_req_qty THEN
        RAISE EXCEPTION 'Insufficient stock in Storage. Requested: % %, Available non-expired: % %',
            v_req_qty, v_unit, v_total_available, v_unit;
    END IF;

    -- Insert Dispatch Header
    INSERT INTO public.dispatches (
        date, material_code, product, quantity, return_quantity, net_quantity, units, location, department, remarks, category, grade, storage_product_id, created_by, updated_at
    ) VALUES (
        v_date, v_prod_code, v_prod_name, v_req_qty, v_ret_qty, v_net_qty, v_unit, v_location, v_dept, v_remarks, v_category, v_grade, v_storage_prod_id, v_created_by, CURRENT_TIMESTAMP
    ) RETURNING id INTO v_dispatch_id;

    -- FIFO Allocation
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

    -- Return Quantity in reverse FIFO order
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

    -- Commit Batch Deductions
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

    IF v_idempotency_key IS NOT NULL THEN
        INSERT INTO public.idempotency_keys (
            idempotency_key, user_id, resource, action, status, response
        ) VALUES (
            v_idempotency_key, v_created_by, 'dispatches', 'create_dispatch_fifo', 'completed', v_result
        ) ON CONFLICT (idempotency_key) DO UPDATE SET response = EXCLUDED.response;
    END IF;

    INSERT INTO public.audit_logs (user_id, operation, module, record_id, details)
    VALUES (
        v_created_by, 'CREATE', 'dispatches', v_dispatch_id::TEXT, 
        jsonb_build_object('product_code', v_prod_code, 'quantity', v_req_qty, 'return', v_ret_qty, 'net', v_net_qty)
    );

    RETURN v_result;
END;
$$;

-- 13. RPC: update_dispatch with Tea category authorization
CREATE OR REPLACE FUNCTION public.update_dispatch(p_dispatch_id bigint, p_dispatch jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
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
    SELECT * INTO v_old_dispatch
    FROM public.dispatches
    WHERE id = p_dispatch_id
    FOR UPDATE;

    IF v_old_dispatch.id IS NULL THEN
        RAISE EXCEPTION 'Dispatch #% does not exist.', p_dispatch_id;
    END IF;

    v_prod_code := TRIM(COALESCE(p_dispatch->>'material_code', v_old_dispatch.material_code));

    -- Security check for Tea user
    IF public.is_tea_user() THEN
        IF NOT public.is_tea_product(v_prod_code) OR NOT public.is_tea_product(v_old_dispatch.material_code) THEN
            RAISE EXCEPTION 'Access Denied: Tea account cannot modify dispatches for non-Tea products.';
        END IF;
    END IF;

    -- 1. Restore all previously allocated quantities to exact original batches
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

    DELETE FROM public.dispatch_batches WHERE dispatch_id = p_dispatch_id;

    -- 2. Extract and sanitize updated parameters
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

    SELECT id, product_name, uom, grade, category 
    INTO v_storage_prod_id, v_prod_name, v_unit, v_grade, v_category
    FROM public.storage_products
    WHERE LOWER(TRIM(product_code)) = LOWER(v_prod_code);

    v_prod_name := COALESCE(NULLIF(TRIM(p_dispatch->>'product'), ''), v_prod_name, v_old_dispatch.product);
    v_unit := COALESCE(NULLIF(TRIM(p_dispatch->>'units'), ''), v_unit, v_old_dispatch.units);
    v_category := COALESCE(NULLIF(TRIM(p_dispatch->>'category'), ''), v_category, v_old_dispatch.category);
    IF public.is_tea_user() THEN
        v_category := 'TEA';
    END IF;
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
$$;

-- 14. RPC: delete_dispatch with Tea category authorization
CREATE OR REPLACE FUNCTION public.delete_dispatch(p_dispatch_id bigint)
RETURNS boolean
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

    IF public.is_tea_user() AND NOT public.is_tea_product(v_mat_code) THEN
        RAISE EXCEPTION 'Access Denied: Tea account cannot delete non-Tea dispatch records.';
    END IF;

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

    DELETE FROM public.dispatch_batches WHERE dispatch_id = p_dispatch_id;
    DELETE FROM public.dispatches WHERE id = p_dispatch_id;

    INSERT INTO public.audit_logs (user_id, operation, module, record_id, details)
    VALUES (
        auth.uid(), 'DELETE', 'dispatches', p_dispatch_id::TEXT, 
        jsonb_build_object('material_code', v_mat_code, 'quantity', v_qty)
    );

    RETURN true;
END;
$$;

-- 15. RPC: safe_delete_batch with Tea category authorization
CREATE OR REPLACE FUNCTION public.safe_delete_batch(p_batch_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_batch RECORD;
    v_dispatch_count INT;
BEGIN
    SELECT * INTO v_batch FROM batches WHERE id = p_batch_id FOR UPDATE;
    IF v_batch IS NULL THEN
        RETURN jsonb_build_object('success', false, 'message', 'Batch not found.');
    END IF;

    -- Security check for Tea user
    IF public.is_tea_user() AND NOT public.is_tea_product(v_batch.material_code) AND UPPER(COALESCE(v_batch.category, '')) != 'TEA' THEN
        RAISE EXCEPTION 'Access Denied: Tea account cannot delete non-Tea batches.';
    END IF;

    SELECT COUNT(*) INTO v_dispatch_count
    FROM dispatch_batches
    WHERE batch_id = p_batch_id;

    IF v_dispatch_count > 0 THEN
        RAISE EXCEPTION 'Cannot delete batch "%": Referenced in % completed dispatch allocation(s). Deleting would corrupt dispatch history.',
            v_batch.batch_no, v_dispatch_count;
    END IF;

    IF v_batch.material_code IS NOT NULL AND v_batch.available_quantity > 0 THEN
        UPDATE materials
        SET quantity = GREATEST(0, quantity - v_batch.available_quantity),
            last_updated = CURRENT_TIMESTAMP
        WHERE material_code = v_batch.material_code;
    END IF;

    DELETE FROM batches WHERE id = p_batch_id;

    INSERT INTO audit_logs (user_id, operation, module, record_id, details)
    VALUES (auth.uid(), 'DELETE', 'batches', p_batch_id::TEXT, jsonb_build_object('batch_no', v_batch.batch_no, 'material_code', v_batch.material_code));

    PERFORM generate_inventory_alerts();

    RETURN jsonb_build_object(
        'success', true,
        'message', 'Batch deleted successfully.'
    );
END;
$$;

-- 16. RPC: update_batch_stock with Tea category authorization
CREATE OR REPLACE FUNCTION public.update_batch_stock(p_batch_id bigint, p_batch_no text, p_description text, p_department text, p_uom text, p_new_available numeric, p_new_received numeric)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_batch RECORD;
    v_delta NUMERIC(15, 3);
    v_mat_code TEXT;
    v_current_stock NUMERIC(15, 3);
    v_total_dispatched NUMERIC(15, 3);
    v_consumed NUMERIC(15, 3);
BEGIN
    SELECT * INTO v_batch FROM batches WHERE id = p_batch_id FOR UPDATE;
    IF v_batch IS NULL THEN
        RAISE EXCEPTION 'Batch with ID % not found', p_batch_id;
    END IF;

    -- Security check for Tea user
    IF public.is_tea_user() AND NOT public.is_tea_product(v_batch.material_code) AND UPPER(COALESCE(v_batch.category, '')) != 'TEA' THEN
        RAISE EXCEPTION 'Access Denied: Tea account cannot modify non-Tea batches.';
    END IF;

    SELECT COALESCE(SUM(quantity), 0) INTO v_total_dispatched
    FROM dispatch_batches
    WHERE batch_id = p_batch_id;

    v_consumed := GREATEST(v_total_dispatched, v_batch.received_quantity - v_batch.available_quantity);

    IF p_new_received < v_consumed THEN
        RAISE EXCEPTION 'Cannot reduce received quantity (%) below already dispatched quantity (% %)', 
            p_new_received, v_consumed, v_batch.uom;
    END IF;

    IF p_new_available < 0 THEN
        RAISE EXCEPTION 'Available stock cannot be negative.';
    END IF;

    v_mat_code := v_batch.material_code;
    v_delta := p_new_available - v_batch.available_quantity;

    IF v_mat_code IS NOT NULL AND v_delta != 0 THEN
        SELECT quantity INTO v_current_stock FROM materials WHERE material_code = v_mat_code FOR UPDATE;
        IF v_current_stock IS NOT NULL AND (v_current_stock + v_delta < 0) THEN
            RAISE EXCEPTION 'Stock adjustment would cause negative inventory (% + % = %)', v_current_stock, v_delta, v_current_stock + v_delta;
        END IF;

        IF v_current_stock IS NOT NULL THEN
            UPDATE materials
            SET quantity = quantity + v_delta,
                last_updated = CURRENT_TIMESTAMP
            WHERE material_code = v_mat_code;
        END IF;
    END IF;

    UPDATE batches
    SET batch_no = COALESCE(NULLIF(p_batch_no, ''), batch_no),
        description = COALESCE(NULLIF(p_description, ''), description),
        department = COALESCE(NULLIF(p_department, ''), department),
        uom = COALESCE(NULLIF(p_uom, ''), uom),
        available_quantity = p_new_available,
        received_quantity = p_new_received
    WHERE id = p_batch_id;

    INSERT INTO audit_logs (user_id, operation, module, record_id, details)
    VALUES (auth.uid(), 'UPDATE', 'batches', p_batch_id::TEXT, jsonb_build_object('batch_no', p_batch_no, 'delta', v_delta));

    PERFORM generate_inventory_alerts();

    RETURN jsonb_build_object(
        'success', true,
        'batch_id', p_batch_id,
        'delta', v_delta
    );
END;
$$;
