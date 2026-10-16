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
$function$
