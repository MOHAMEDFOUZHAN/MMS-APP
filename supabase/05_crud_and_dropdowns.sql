-- ============================================================================
-- BENCHMARK MMS — ATOMIC CRUD & INVENTORY RECONCILIATION RPCS
-- 1. update_purchase (Atomic Invoice Edit & Stock Recalculation)
-- 2. update_transfer (Atomic Transfer Edit & Stock Recalculation)
-- 3. update_dispatch (Atomic Dispatch Edit & FIFO Reallocation)
-- 4. safe_delete_batch (Dependency Checking & Safe Deletion)
-- 5. update_batch_stock (Atomic Batch Stock Adjustment)
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. UPDATE PURCHASE INVOICE & RECALCULATE STOCK ATOMICALLY
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_purchase(
    p_invoice_id BIGINT,
    p_invoice JSONB,
    p_items JSONB,
    p_idempotency_key TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_old_item RECORD;
    v_item RECORD;
    v_gross_amount NUMERIC(15, 2);
    v_discount_amount NUMERIC(15, 2);
    v_net_amount NUMERIC(15, 2);
    v_item_gst NUMERIC(15, 2);
    v_item_igst NUMERIC(15, 2);
    v_item_total NUMERIC(15, 2);
    
    v_calc_subtotal NUMERIC(15, 2) := 0.00;
    v_calc_gst_total NUMERIC(15, 2) := 0.00;
    v_calc_igst_total NUMERIC(15, 2) := 0.00;
    v_final_grand_total NUMERIC(15, 2) := 0.00;
    v_final_total NUMERIC(15, 2) := 0.00;
    
    v_mat_code TEXT;
    v_mat_name TEXT;
    v_category TEXT;
    v_unit TEXT;
    v_hsn_sac TEXT;
    v_grade TEXT;
    v_reorder_level NUMERIC(15, 3);
    v_lot_no TEXT;
    v_p_date DATE;
    v_e_date DATE;
    v_qty NUMERIC(15, 3);
    v_unit_price NUMERIC(15, 2);
    v_disc_pct NUMERIC(5, 2);
    v_gst_pct NUMERIC(5, 2);
    v_igst_pct NUMERIC(5, 2);
    v_lot_exists BOOLEAN;
    v_result JSONB;
BEGIN
    -- 1. Lock invoice row
    PERFORM 1 FROM invoices WHERE id = p_invoice_id FOR UPDATE;

    -- 2. Reverse previous invoice line items stock impact
    FOR v_old_item IN SELECT material, quantity FROM invoice_items WHERE invoice_id = p_invoice_id
    LOOP
        UPDATE materials
        SET quantity = GREATEST(0, quantity - v_old_item.quantity),
            last_updated = CURRENT_TIMESTAMP
        WHERE material_code = v_old_item.material;
    END LOOP;

    -- 3. Delete old batches and items created by this invoice
    DELETE FROM batches WHERE invoice_id = p_invoice_id;
    DELETE FROM invoice_items WHERE invoice_id = p_invoice_id;

    -- 4. Update Invoice Header
    UPDATE invoices
    SET purchase_id = COALESCE(p_invoice->>'purchase_id', purchase_id),
        date = (p_invoice->>'date')::DATE,
        vendor = COALESCE(p_invoice->>'vendor', vendor),
        no_of_items = COALESCE((p_invoice->>'no_of_items')::INT, jsonb_array_length(p_items)),
        cgst_percent = COALESCE((p_invoice->>'cgst_percent')::NUMERIC, 0),
        sgst_percent = COALESCE((p_invoice->>'sgst_percent')::NUMERIC, 0),
        round_off_value = COALESCE((p_invoice->>'round_off_value')::NUMERIC, 0),
        payment_status = COALESCE(p_invoice->>'payment_status', 'Pending'),
        remarks = p_invoice->>'remarks'
    WHERE id = p_invoice_id;

    -- 5. Insert new line items & apply new stock quantities
    FOR v_item IN SELECT * FROM jsonb_to_recordset(p_items) AS x(
        material TEXT,
        description TEXT,
        category TEXT,
        unit TEXT,
        quantity NUMERIC,
        unit_price NUMERIC,
        discount_percentage NUMERIC,
        gst_percentage NUMERIC,
        igst_percentage NUMERIC,
        lot_no TEXT,
        purchase_date TEXT,
        expiry_date TEXT,
        hsn_sac TEXT,
        grade TEXT,
        reorder_level NUMERIC
    )
    LOOP
        v_mat_code := TRIM(v_item.material);
        v_mat_name := TRIM(COALESCE(v_item.description, v_mat_code));
        v_category := TRIM(COALESCE(v_item.category, 'Uncategorized'));
        v_unit := TRIM(COALESCE(v_item.unit, 'kg'));
        v_qty := COALESCE(v_item.quantity, 0);
        v_unit_price := COALESCE(v_item.unit_price, 0);
        v_disc_pct := COALESCE(v_item.discount_percentage, 0);
        v_gst_pct := COALESCE(v_item.gst_percentage, 0);
        v_igst_pct := COALESCE(v_item.igst_percentage, 0);
        v_lot_no := TRIM(COALESCE(v_item.lot_no, 'LOT-' || to_char((p_invoice->>'date')::DATE, 'YYYYMMDD')));
        v_hsn_sac := TRIM(COALESCE(v_item.hsn_sac, ''));
        v_grade := UPPER(TRIM(COALESCE(v_item.grade, '')));
        v_reorder_level := COALESCE(v_item.reorder_level, 0);
        
        IF v_item.purchase_date IS NOT NULL AND v_item.purchase_date != '' THEN
            v_p_date := (v_item.purchase_date)::DATE;
        ELSE
            v_p_date := (p_invoice->>'date')::DATE;
        END IF;

        IF v_item.expiry_date IS NOT NULL AND v_item.expiry_date != '' THEN
            v_e_date := (v_item.expiry_date)::DATE;
        ELSE
            v_e_date := NULL;
        END IF;

        v_gross_amount := ROUND((v_qty * v_unit_price)::NUMERIC, 2);
        v_discount_amount := ROUND((v_gross_amount * (v_disc_pct / 100.0))::NUMERIC, 2);
        v_net_amount := v_gross_amount - v_discount_amount;
        v_item_gst := ROUND((v_net_amount * (v_gst_pct / 100.0))::NUMERIC, 2);
        v_item_igst := ROUND((v_net_amount * (v_igst_pct / 100.0))::NUMERIC, 2);
        v_item_total := v_net_amount + v_item_gst + v_item_igst;

        v_calc_subtotal := v_calc_subtotal + v_net_amount;
        v_calc_gst_total := v_calc_gst_total + v_item_gst;
        v_calc_igst_total := v_calc_igst_total + v_item_igst;

        INSERT INTO invoice_items (
            invoice_id, material, quantity, unit, unit_price,
            discount_percentage, gst_percentage, igst_percentage,
            item_subtotal, item_gst_value, item_igst_value, item_total,
            batch_no, hsn_sac, grade
        ) VALUES (
            p_invoice_id, v_mat_code, v_qty, v_unit, v_unit_price,
            v_disc_pct, v_gst_pct, v_igst_pct,
            v_net_amount, v_item_gst, v_item_igst, v_item_total,
            v_lot_no, v_hsn_sac, v_grade
        );

        -- Update or insert Material Master row
        SELECT EXISTS(
            SELECT 1 FROM materials WHERE material_code = v_mat_code FOR UPDATE
        ) INTO v_lot_exists;

        IF v_lot_exists THEN
            UPDATE materials
            SET description = COALESCE(NULLIF(description, ''), v_mat_name),
                quantity = quantity + v_qty,
                category = COALESCE(NULLIF(category, ''), v_category),
                unit = COALESCE(NULLIF(unit, ''), v_unit),
                reorder_level = CASE WHEN reorder_level > 0 THEN reorder_level ELSE v_reorder_level END,
                unit_price = CASE WHEN v_unit_price > 0 THEN v_unit_price ELSE unit_price END,
                purchase_date = v_p_date,
                expiry_date = COALESCE(v_e_date, expiry_date),
                lot_no = v_lot_no,
                hsn_sac = COALESCE(NULLIF(hsn_sac, ''), v_hsn_sac),
                grade = COALESCE(NULLIF(grade, ''), v_grade),
                last_updated = CURRENT_TIMESTAMP
            WHERE material_code = v_mat_code;
        ELSE
            INSERT INTO materials (
                material_code, description, category, opening_stock,
                quantity, unit, unit_price, purchase_date, expiry_date,
                lot_no, reorder_level, hsn_sac, grade, last_updated
            ) VALUES (
                v_mat_code, v_mat_name, v_category, 0.000,
                v_qty, v_unit, v_unit_price, v_p_date, v_e_date,
                v_lot_no, v_reorder_level, v_hsn_sac, v_grade, CURRENT_TIMESTAMP
            );
        END IF;

        -- Record batch in batches table
        INSERT INTO batches (
            batch_no, material_code, description, received_quantity,
            available_quantity, uom, department, received_date, invoice_id
        ) VALUES (
            v_lot_no, v_mat_code, v_mat_name, v_qty,
            v_qty, v_unit, 'General Storage', v_p_date, p_invoice_id
        );
    END LOOP;

    v_final_grand_total := ROUND(v_calc_subtotal + v_calc_gst_total + v_calc_igst_total, 2);
    v_final_total := v_final_grand_total + COALESCE((p_invoice->>'round_off_value')::NUMERIC, 0);

    UPDATE invoices
    SET total_excl_tax = v_calc_subtotal,
        total_gst = v_calc_gst_total,
        total_igst = v_calc_igst_total,
        grand_total = v_final_grand_total,
        final_total = v_final_total
    WHERE id = p_invoice_id;

    v_result := jsonb_build_object(
        'success', true,
        'invoice_id', p_invoice_id,
        'subtotal', v_calc_subtotal,
        'total_gst', v_calc_gst_total,
        'total_igst', v_calc_igst_total,
        'grand_total', v_final_grand_total,
        'final_total', v_final_total
    );

    -- Audit log
    INSERT INTO audit_logs (user_id, operation, module, record_id, details)
    VALUES (auth.uid(), 'UPDATE', 'invoices', p_invoice_id::TEXT, v_result);

    PERFORM generate_inventory_alerts();

    RETURN v_result;
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. UPDATE TRANSFER & RECALCULATE STOCK ATOMICALLY
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_transfer(
    p_transfer_id BIGINT,
    p_transfer JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_old_transfer RECORD;
    v_code TEXT;
    v_lot_no TEXT;
    v_desc TEXT;
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
    v_result JSONB;
BEGIN
    SELECT * INTO v_old_transfer FROM transfers WHERE id = p_transfer_id FOR UPDATE;
    IF v_old_transfer IS NULL THEN
        RAISE EXCEPTION 'Transfer with ID % not found', p_transfer_id;
    END IF;

    v_code := TRIM(COALESCE(p_transfer->>'code', v_old_transfer.code));
    v_lot_no := TRIM(COALESCE(p_transfer->>'lot_no', v_old_transfer.lot_no, ''));
    v_dept := TRIM(COALESCE(p_transfer->>'department', v_old_transfer.department, ''));
    v_person := TRIM(COALESCE(p_transfer->>'person', v_old_transfer.person, ''));
    v_units := TRIM(COALESCE(p_transfer->>'units', v_old_transfer.units, 'kg'));
    v_date := (COALESCE(p_transfer->>'date', v_old_transfer.date::TEXT))::DATE;
    v_new_outward := COALESCE((p_transfer->>'outward')::NUMERIC, v_old_transfer.outward);
    v_new_return := COALESCE((p_transfer->>'return_units')::NUMERIC, v_old_transfer.return_units);

    -- Find material row with lock
    SELECT id, quantity, description, unit
    INTO v_mat_id, v_current_stock, v_desc, v_units
    FROM materials
    WHERE material_code = v_code
    FOR UPDATE;

    IF v_mat_id IS NULL THEN
        RAISE EXCEPTION 'Material not found in Material Master for code: %', v_code;
    END IF;

    -- Reverse old net change: old_net = old_return - old_outward
    v_old_net := v_old_transfer.return_units - v_old_transfer.outward;
    v_adjusted_stock := v_current_stock - v_old_net;

    -- Validate if new outward can be met from adjusted base stock
    IF v_new_outward > v_adjusted_stock THEN
        RAISE EXCEPTION 'Insufficient stock in Material Master! Available: %, Requested Transfer Out: %', v_adjusted_stock, v_new_outward;
    END IF;

    -- Apply new net change: new_net = new_return - new_outward
    v_new_net := v_new_return - v_new_outward;
    v_final_stock := ROUND(v_adjusted_stock + v_new_net, 3);

    -- Update material stock
    UPDATE materials
    SET quantity = v_final_stock,
        last_updated = CURRENT_TIMESTAMP
    WHERE id = v_mat_id;

    -- Update transfer record
    UPDATE transfers
    SET date = v_date,
        code = v_code,
        description = v_desc,
        lot_no = v_lot_no,
        outward = v_new_outward,
        units = v_units,
        department = v_dept,
        person = v_person,
        return_units = v_new_return,
        availability = v_final_stock
    WHERE id = p_transfer_id;

    v_result := jsonb_build_object(
        'success', true,
        'transfer_id', p_transfer_id,
        'net_change', v_new_net,
        'remaining_balance', v_final_stock
    );

    -- Audit log
    INSERT INTO audit_logs (user_id, operation, module, record_id, details)
    VALUES (auth.uid(), 'UPDATE', 'transfers', p_transfer_id::TEXT, v_result);

    PERFORM generate_inventory_alerts();

    RETURN v_result;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. UPDATE DISPATCH WITH FIFO RE-ALLOCATION
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_dispatch(
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
    SELECT material_code, quantity INTO v_old_mat_code, v_old_qty FROM dispatches WHERE id = p_dispatch_id FOR UPDATE;
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

    -- Calculate total available stock
    SELECT COALESCE(SUM(available_quantity), 0)
    INTO v_total_available
    FROM batches
    WHERE (material_code = v_mat_code OR description ILIKE v_product_name)
      AND available_quantity > 0.0001;

    IF v_total_available < v_req_qty THEN
        RAISE EXCEPTION 'Insufficient stock! Requested: %, Available in batches: %', v_req_qty, v_total_available;
    END IF;

    -- 3. FIFO Re-allocation
    v_remaining_to_dispatch := v_req_qty;

    FOR v_batch IN
        SELECT id, batch_no, available_quantity
        FROM batches
        WHERE (material_code = v_mat_code OR description ILIKE v_product_name)
          AND available_quantity > 0.0001
        ORDER BY id ASC
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

-- ----------------------------------------------------------------------------
-- 4. SAFE DELETE BATCH (With Dependency Verification)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION safe_delete_batch(p_batch_id BIGINT)
RETURNS JSONB
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

    -- Check if referenced in dispatch_batches
    SELECT COUNT(*) INTO v_dispatch_count
    FROM dispatch_batches
    WHERE batch_id = p_batch_id;

    IF v_dispatch_count > 0 THEN
        RAISE EXCEPTION 'Cannot delete batch "%": Referenced in % completed dispatch allocation(s). Deleting would corrupt dispatch history.',
            v_batch.batch_no, v_dispatch_count;
    END IF;

    -- Deduct remaining available quantity from materials master to keep inventory consistent
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

-- ----------------------------------------------------------------------------
-- 5. ATOMIC BATCH UPDATE & STOCK DIFFERENCE RECONCILIATION
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_batch_stock(
    p_batch_id BIGINT,
    p_batch_no TEXT,
    p_description TEXT,
    p_department TEXT,
    p_uom TEXT,
    p_new_available NUMERIC,
    p_new_received NUMERIC
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_batch RECORD;
    v_delta NUMERIC(15, 3);
    v_mat_code TEXT;
    v_current_stock NUMERIC(15, 3);
BEGIN
    SELECT * INTO v_batch FROM batches WHERE id = p_batch_id FOR UPDATE;
    IF v_batch IS NULL THEN
        RAISE EXCEPTION 'Batch with ID % not found', p_batch_id;
    END IF;

    v_mat_code := v_batch.material_code;
    v_delta := p_new_available - v_batch.available_quantity;

    IF v_mat_code IS NOT NULL AND v_delta != 0 THEN
        SELECT quantity INTO v_current_stock FROM materials WHERE material_code = v_mat_code FOR UPDATE;
        IF v_current_stock + v_delta < 0 THEN
            RAISE EXCEPTION 'Stock adjustment would cause negative inventory (% + % = %)', v_current_stock, v_delta, v_current_stock + v_delta;
        END IF;

        UPDATE materials
        SET quantity = quantity + v_delta,
            last_updated = CURRENT_TIMESTAMP
        WHERE material_code = v_mat_code;
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
