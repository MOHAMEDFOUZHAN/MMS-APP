CREATE OR REPLACE FUNCTION public.update_transfer(p_transfer_id bigint, p_transfer jsonb, p_idempotency_key text DEFAULT NULL::text)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
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
$function$
