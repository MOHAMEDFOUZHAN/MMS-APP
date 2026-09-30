-- ============================================================================
-- BENCHMARK MMS — ATOMIC DATABASE FUNCTIONS / STORED PROCEDURES
-- Supabase PostgreSQL RPC Functions
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. CREATE PURCHASE INVOICE & UPDATE STOCK ATOMICALLY
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_purchase(
    p_invoice JSONB,
    p_items JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_invoice_id BIGINT;
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
    v_batch_no TEXT;
    
    v_lot_exists BOOLEAN;
BEGIN
    -- Insert Invoice Header with placeholder totals
    INSERT INTO invoices (
        purchase_id,
        date,
        invoice_no,
        vendor,
        no_of_items,
        total_excl_tax,
        total_gst,
        total_igst,
        cgst_percent,
        sgst_percent,
        round_off_value,
        grand_total,
        final_total,
        payment_status,
        remarks
    ) VALUES (
        p_invoice->>'purchase_id',
        (p_invoice->>'date')::DATE,
        p_invoice->>'invoice_no',
        p_invoice->>'vendor',
        COALESCE((p_invoice->>'no_of_items')::INT, jsonb_array_length(p_items)),
        0, 0, 0,
        COALESCE((p_invoice->>'cgst_percent')::NUMERIC, 0),
        COALESCE((p_invoice->>'sgst_percent')::NUMERIC, 0),
        COALESCE((p_invoice->>'round_off_value')::NUMERIC, 0),
        0, 0,
        COALESCE(p_invoice->>'payment_status', 'Pending'),
        p_invoice->>'remarks'
    ) RETURNING id INTO v_invoice_id;

    -- Process each invoice line item
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

        -- Calculations:
        -- 1. Gross & Net Amount
        v_gross_amount := ROUND((v_qty * v_unit_price)::NUMERIC, 2);
        v_discount_amount := ROUND((v_gross_amount * (v_disc_pct / 100.0))::NUMERIC, 2);
        v_net_amount := v_gross_amount - v_discount_amount;

        -- 2. GST & IGST (Ledger style rounded per row)
        v_item_gst := ROUND((v_net_amount * (v_gst_pct / 100.0))::NUMERIC, 2);
        v_item_igst := ROUND((v_net_amount * (v_igst_pct / 100.0))::NUMERIC, 2);
        v_item_total := v_net_amount + v_item_gst + v_item_igst;

        -- Accumulate totals
        v_calc_subtotal := v_calc_subtotal + v_net_amount;
        v_calc_gst_total := v_calc_gst_total + v_item_gst;
        v_calc_igst_total := v_calc_igst_total + v_item_igst;

        -- Insert line item
        INSERT INTO invoice_items (
            invoice_id, material, quantity, unit, unit_price,
            discount_percentage, gst_percentage, igst_percentage,
            item_subtotal, item_gst_value, item_igst_value, item_total,
            batch_no, hsn_sac, grade
        ) VALUES (
            v_invoice_id, v_mat_code, v_qty, v_unit, v_unit_price,
            v_disc_pct, v_gst_pct, v_igst_pct,
            v_net_amount, v_item_gst, v_item_igst, v_item_total,
            v_lot_no, v_hsn_sac, v_grade
        );

        -- Update or Insert Material Master (SINGLE master record for each Material Code)
        SELECT EXISTS(
            SELECT 1 FROM materials WHERE material_code = v_mat_code
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

        -- Record operational batch in batches table
        INSERT INTO batches (
            batch_no, material_code, description, received_quantity,
            available_quantity, uom, department, received_date, invoice_id
        ) VALUES (
            v_lot_no, v_mat_code, v_mat_name, v_qty,
            v_qty, v_unit, 'General Storage', v_p_date, v_invoice_id
        );
    END LOOP;

    -- Final invoice header update
    v_final_grand_total := ROUND(v_calc_subtotal + v_calc_gst_total + v_calc_igst_total, 2);
    v_final_total := v_final_grand_total + COALESCE((p_invoice->>'round_off_value')::NUMERIC, 0);

    UPDATE invoices
    SET total_excl_tax = v_calc_subtotal,
        total_gst = v_calc_gst_total,
        total_igst = v_calc_igst_total,
        grand_total = v_final_grand_total,
        final_total = v_final_total
    WHERE id = v_invoice_id;

    RETURN jsonb_build_object(
        'success', true,
        'invoice_id', v_invoice_id,
        'subtotal', v_calc_subtotal,
        'total_gst', v_calc_gst_total,
        'total_igst', v_calc_igst_total,
        'grand_total', v_final_grand_total,
        'final_total', v_final_total
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 2. DELETE PURCHASE INVOICE & REVERSE STOCK ATOMICALLY
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION delete_purchase(p_invoice_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_item RECORD;
BEGIN
    -- Revert material stock for each item in the invoice
    FOR v_item IN SELECT material, quantity, batch_no FROM invoice_items WHERE invoice_id = p_invoice_id
    LOOP
        UPDATE materials
        SET quantity = GREATEST(0, quantity - v_item.quantity),
            last_updated = CURRENT_TIMESTAMP
        WHERE material_code = v_item.material;
    END LOOP;

    -- Delete associated batches
    DELETE FROM batches WHERE invoice_id = p_invoice_id;

    -- Delete invoice (invoice_items cascade delete automatically)
    DELETE FROM invoices WHERE id = p_invoice_id;

    RETURN true;
END;
$$;

-- ----------------------------------------------------------------------------
-- 3. FIFO DISPATCH ALLOCATION (Multi-Batch FIFO Consumer)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_dispatch_fifo(
    p_dispatch JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
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
BEGIN
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

    -- Calculate total available stock across active batches
    SELECT COALESCE(SUM(available_quantity), 0)
    INTO v_total_available
    FROM batches
    WHERE (material_code = v_mat_code OR description ILIKE v_product_name)
      AND available_quantity > 0.0001;

    IF v_total_available < v_req_qty THEN
        RAISE EXCEPTION 'Insufficient stock! Requested: %, Available in batches: %', v_req_qty, v_total_available;
    END IF;

    -- Insert Dispatches header record
    INSERT INTO dispatches (
        date, material_code, product, quantity, units, location, department
    ) VALUES (
        v_date, v_mat_code, v_product_name, v_req_qty, v_unit, v_location, v_dept
    ) RETURNING id INTO v_dispatch_id;

    -- FIFO Deduction: Sort oldest batch first (by id ASC or received_date ASC)
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

        -- Record allocation
        INSERT INTO dispatch_batches (dispatch_id, batch_no, batch_id, quantity)
        VALUES (v_dispatch_id, v_batch.batch_no, v_batch.id, v_take);

        v_allocations := v_allocations || jsonb_build_object(
            'batch_id', v_batch.id,
            'batch_no', v_batch.batch_no,
            'quantity', v_take
        );
    END LOOP;

    -- Synchronize Material Master aggregate stock
    UPDATE materials
    SET quantity = GREATEST(0, quantity - v_req_qty),
        last_updated = CURRENT_TIMESTAMP
    WHERE material_code = v_mat_code;

    RETURN jsonb_build_object(
        'success', true,
        'dispatch_id', v_dispatch_id,
        'dispatched_quantity', v_req_qty,
        'allocations', v_allocations
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 4. DELETE DISPATCH & RESTORE EXACT BATCH ALLOCATIONS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION delete_dispatch(p_dispatch_id BIGINT)
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

    RETURN true;
END;
$$;

-- ----------------------------------------------------------------------------
-- 5. DEPARTMENT TRANSFER & RETURN ATOMIC HANDLER
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_transfer(
    p_transfer JSONB
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_transfer_id BIGINT;
    v_code TEXT;
    v_lot_no TEXT;
    v_desc TEXT;
    v_dept TEXT;
    v_person TEXT;
    v_units TEXT;
    v_date DATE;
    v_outward NUMERIC(15, 3);
    v_return_units NUMERIC(15, 3);
    v_net_change NUMERIC(15, 3);
    
    v_current_stock NUMERIC(15, 3);
    v_remaining_balance NUMERIC(15, 3);
    v_mat_id BIGINT;
BEGIN
    v_code := TRIM(p_transfer->>'code');
    v_lot_no := TRIM(COALESCE(p_transfer->>'lot_no', ''));
    v_dept := TRIM(COALESCE(p_transfer->>'department', ''));
    v_person := TRIM(COALESCE(p_transfer->>'person', ''));
    v_units := TRIM(COALESCE(p_transfer->>'units', 'kg'));
    v_date := (p_transfer->>'date')::DATE;
    v_outward := COALESCE((p_transfer->>'outward')::NUMERIC, 0.000);
    v_return_units := COALESCE((p_transfer->>'return_units')::NUMERIC, 0.000);

    -- Find Material Master record
    SELECT id, quantity, description, unit
    INTO v_mat_id, v_current_stock, v_desc, v_units
    FROM materials
    WHERE material_code = v_code
    FOR UPDATE;

    IF v_mat_id IS NULL THEN
        RAISE EXCEPTION 'Material not found in Material Master for code: %', v_code;
    END IF;

    -- Validation
    IF v_outward > v_current_stock THEN
        RAISE EXCEPTION 'Insufficient stock in Material Master! Available: %, Transfer Out: %', v_current_stock, v_outward;
    END IF;

    -- Net Change = Return Quantity - Outward Quantity
    v_net_change := v_return_units - v_outward;
    v_remaining_balance := ROUND(v_current_stock + v_net_change, 3);

    -- Update material stock
    UPDATE materials
    SET quantity = v_remaining_balance,
        last_updated = CURRENT_TIMESTAMP
    WHERE id = v_mat_id;

    -- Save transfer record
    INSERT INTO transfers (
        date, code, description, lot_no, outward, units, department, person, return_units, availability
    ) VALUES (
        v_date, v_code, v_desc, v_lot_no, v_outward, v_units, v_dept, v_person, v_return_units, v_remaining_balance
    ) RETURNING id INTO v_transfer_id;

    RETURN jsonb_build_object(
        'success', true,
        'transfer_id', v_transfer_id,
        'net_change', v_net_change,
        'remaining_balance', v_remaining_balance
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 6. DELETE TRANSFER & REVERT STOCK
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION delete_transfer(p_transfer_id BIGINT)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_transfer RECORD;
    v_net_change NUMERIC(15, 3);
BEGIN
    SELECT * INTO v_transfer FROM transfers WHERE id = p_transfer_id;
    IF v_transfer IS NULL THEN
        RETURN false;
    END IF;

    v_net_change := v_transfer.return_units - v_transfer.outward;

    UPDATE materials
    SET quantity = GREATEST(0, ROUND(quantity - v_net_change, 3)),
        last_updated = CURRENT_TIMESTAMP
    WHERE material_code = v_transfer.code;

    DELETE FROM transfers WHERE id = p_transfer_id;
    RETURN true;
END;
$$;

-- ----------------------------------------------------------------------------
-- 7. STOCK ADJUSTMENT (FIFO Subtraction from oldest lots / Add to latest lot)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION create_stock_adjustment(
    p_code TEXT,
    p_operation TEXT,
    p_amount NUMERIC,
    p_reason TEXT,
    p_user TEXT
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_current_total NUMERIC(15, 3);
    v_new_total NUMERIC(15, 3);
    v_remaining NUMERIC(15, 3);
    v_lot RECORD;
    v_latest_id BIGINT;
    v_op TEXT := LOWER(TRIM(p_operation));
BEGIN
    IF p_amount <= 0 THEN
        RAISE EXCEPTION 'Adjustment amount must be positive.';
    END IF;

    SELECT COALESCE(SUM(quantity), 0)
    INTO v_current_total
    FROM materials
    WHERE material_code = p_code;

    IF v_op = 'subtract' THEN
        IF p_amount > v_current_total THEN
            RAISE EXCEPTION 'Cannot subtract % — only % in stock for %', p_amount, v_current_total, p_code;
        END IF;

        -- Consume FIFO from oldest lots first
        v_remaining := p_amount;
        FOR v_lot IN
            SELECT id, quantity
            FROM materials
            WHERE material_code = p_code AND quantity > 0
            ORDER BY id ASC
            FOR UPDATE
        LOOP
            EXIT WHEN v_remaining <= 0;

            IF v_lot.quantity <= v_remaining THEN
                UPDATE materials SET quantity = 0, last_updated = CURRENT_TIMESTAMP WHERE id = v_lot.id;
                v_remaining := v_remaining - v_lot.quantity;
            ELSE
                UPDATE materials SET quantity = quantity - v_remaining, last_updated = CURRENT_TIMESTAMP WHERE id = v_lot.id;
                v_remaining := 0;
            END IF;
        END LOOP;

        v_new_total := v_current_total - p_amount;
    ELSE
        -- Add: target latest lot or create default
        SELECT id INTO v_latest_id
        FROM materials
        WHERE material_code = p_code
        ORDER BY id DESC
        LIMIT 1;

        IF v_latest_id IS NOT NULL THEN
            UPDATE materials
            SET quantity = quantity + p_amount,
                last_updated = CURRENT_TIMESTAMP
            WHERE id = v_latest_id;
        ELSE
            INSERT INTO materials (
                material_code, description, category, quantity, opening_stock, unit, last_updated
            ) VALUES (
                p_code, 'Material ' || p_code, 'General', p_amount, p_amount, 'kg', CURRENT_TIMESTAMP
            );
        END IF;

        v_new_total := v_current_total + p_amount;
    END IF;

    -- Record audit log
    INSERT INTO stock_adjustments (
        material_code, operation, amount, reason, before_qty, after_qty, adjusted_by
    ) VALUES (
        p_code, p_operation, p_amount, p_reason, v_current_total, v_new_total, p_user
    );

    RETURN jsonb_build_object(
        'success', true,
        'material_code', p_code,
        'before_qty', v_current_total,
        'after_qty', v_new_total
    );
END;
$$;

-- ----------------------------------------------------------------------------
-- 8. GLOBAL MATERIAL UNIT SYNCHRONIZATION
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION update_material_unit(
    p_code TEXT,
    p_new_unit TEXT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    -- 1. materials
    UPDATE materials SET unit = p_new_unit WHERE material_code = p_code;

    -- 2. batches
    UPDATE batches SET uom = p_new_unit WHERE material_code = p_code;

    -- 3. invoice_items
    UPDATE invoice_items SET unit = p_new_unit WHERE material = p_code;

    -- 4. transfers
    UPDATE transfers SET units = p_new_unit WHERE code = p_code;

    -- 5. dispatches
    UPDATE dispatches SET units = p_new_unit WHERE material_code = p_code;

    RETURN true;
END;
$$;

-- ----------------------------------------------------------------------------
-- 9. RESET DAILY OPENING STOCK
-- Opening Stock = Previous Closing Stock (Yesterday's quantity becomes today's opening_stock)
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION reset_daily_opening_stock()
RETURNS INT
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_updated_count INT;
BEGIN
    UPDATE materials
    SET opening_stock = quantity,
        last_updated = CURRENT_TIMESTAMP;
    
    GET DIAGNOSTICS v_updated_count = ROW_COUNT;
    RETURN v_updated_count;
END;
$$;

-- ----------------------------------------------------------------------------
-- 10. MATERIAL UTILIZATION REPORT (MUR) WITH HISTORICAL BACKTRACKING
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION get_mur_report(
    p_start_date DATE,
    p_end_date DATE,
    p_category TEXT DEFAULT NULL
) RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_mat RECORD;
    v_current_stock NUMERIC(15, 3);
    v_in_purchased NUMERIC(15, 3);
    v_in_transferred NUMERIC(15, 3);
    v_in_returned NUMERIC(15, 3);
    v_in_dispatched NUMERIC(15, 3);
    v_in_used NUMERIC(15, 3);
    
    v_after_purchased NUMERIC(15, 3);
    v_after_transferred NUMERIC(15, 3);
    v_after_dispatched NUMERIC(15, 3);
    v_after_used NUMERIC(15, 3);
    
    v_period_closing NUMERIC(15, 3);
    v_period_opening NUMERIC(15, 3);
    v_util_pct NUMERIC(5, 1);
    
    v_loc_map JSONB := '{}'::JSONB;
    v_shelf_loc TEXT;
    v_results JSONB := '[]'::JSONB;
BEGIN
    -- Build category location mapping
    SELECT jsonb_object_agg(category, location) INTO v_loc_map FROM category_locations;
    IF v_loc_map IS NULL THEN v_loc_map := '{}'::JSONB; END IF;

    -- Iterate distinct materials
    FOR v_mat IN
        SELECT DISTINCT material_code, description, unit, category
        FROM materials
        WHERE (p_category IS NULL OR p_category = '' OR category = p_category)
        ORDER BY material_code
    LOOP
        -- 1. Total Current Stock
        SELECT COALESCE(SUM(quantity), 0)
        INTO v_current_stock
        FROM materials
        WHERE material_code = v_mat.material_code;

        -- 2. Purchased In Period
        SELECT COALESCE(SUM(ii.quantity), 0)
        INTO v_in_purchased
        FROM invoice_items ii
        JOIN invoices i ON ii.invoice_id = i.id
        WHERE ii.material = v_mat.material_code
          AND i.date BETWEEN p_start_date AND p_end_date;

        -- 3. Used In Period (Transfers Out + Dispatches - Returns)
        SELECT COALESCE(SUM(outward), 0)
        INTO v_in_transferred
        FROM transfers
        WHERE code = v_mat.material_code
          AND date BETWEEN p_start_date AND p_end_date;

        SELECT COALESCE(SUM(return_units), 0)
        INTO v_in_returned
        FROM transfers
        WHERE code = v_mat.material_code
          AND date BETWEEN p_start_date AND p_end_date;

        SELECT COALESCE(SUM(quantity), 0)
        INTO v_in_dispatched
        FROM dispatches
        WHERE material_code = v_mat.material_code
          AND date BETWEEN p_start_date AND p_end_date;

        v_in_used := (v_in_transferred + v_in_dispatched) - v_in_returned;

        -- 4. Flows After Period (to backtrack from current to period closing)
        SELECT COALESCE(SUM(ii.quantity), 0)
        INTO v_after_purchased
        FROM invoice_items ii
        JOIN invoices i ON ii.invoice_id = i.id
        WHERE ii.material = v_mat.material_code
          AND i.date > p_end_date;

        SELECT COALESCE(SUM(outward - return_units), 0)
        INTO v_after_transferred
        FROM transfers
        WHERE code = v_mat.material_code
          AND date > p_end_date;

        SELECT COALESCE(SUM(quantity), 0)
        INTO v_after_dispatched
        FROM dispatches
        WHERE material_code = v_mat.material_code
          AND date > p_end_date;

        v_after_used := v_after_transferred + v_after_dispatched;

        -- Backtracking math:
        -- Period Closing = Current Stock + Used_After - Purchased_After
        v_period_closing := v_current_stock + v_after_used - v_after_purchased;
        -- Period Opening = Period Closing + Used_In - Purchased_In
        v_period_opening := v_period_closing + v_in_used - v_in_purchased;

        -- Utilization Percentage
        IF (v_period_opening + v_in_purchased) > 0 THEN
            v_util_pct := LEAST(100.0, GREATEST(0.0, ROUND((v_in_used / (v_period_opening + v_in_purchased) * 100.0)::NUMERIC, 1)));
        ELSE
            v_util_pct := 0.0;
        END IF;

        v_shelf_loc := COALESCE(v_loc_map->>v_mat.category, 'Not Assigned');

        v_results := v_results || jsonb_build_object(
            'code', v_mat.material_code,
            'description', v_mat.description,
            'category', COALESCE(v_mat.category, 'Uncategorized'),
            'unit', v_mat.unit,
            'shelf_location', v_shelf_loc,
            'opening', v_period_opening,
            'purchased', v_in_purchased,
            'used', v_in_used,
            'closing', v_period_closing,
            'utilization_percent', v_util_pct
        );
    END LOOP;

    RETURN v_results;
END;
$$;
