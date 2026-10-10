import os
import psycopg2

def run_migration():
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
    
    print("1. Adding lot_no to invoice_items if not exists...")
    cur.execute("""
        ALTER TABLE public.invoice_items ADD COLUMN IF NOT EXISTS lot_no TEXT;
    """)
    cur.execute("""
        UPDATE public.invoice_items SET lot_no = batch_no WHERE lot_no IS NULL AND batch_no IS NOT NULL;
    """)
    
    print("2. Creating material_lots table...")
    cur.execute("""
        CREATE TABLE IF NOT EXISTS public.material_lots (
            id BIGSERIAL PRIMARY KEY,
            material_id BIGINT REFERENCES public.materials(id) ON DELETE CASCADE,
            material_code TEXT NOT NULL,
            lot_no TEXT NOT NULL,
            lot_date DATE NOT NULL DEFAULT CURRENT_DATE,
            initial_quantity NUMERIC(15, 3) NOT NULL,
            available_quantity NUMERIC(15, 3) NOT NULL,
            uom TEXT NOT NULL DEFAULT 'kg',
            invoice_id BIGINT REFERENCES public.invoices(id) ON DELETE SET NULL,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX IF NOT EXISTS idx_material_lots_mat_code ON public.material_lots (material_code);
        CREATE INDEX IF NOT EXISTS idx_material_lots_avail ON public.material_lots (material_code, available_quantity) WHERE available_quantity > 0;
        CREATE INDEX IF NOT EXISTS idx_material_lots_fifo ON public.material_lots (material_code, lot_date ASC, id ASC);
    """)

    print("3. Creating transfer_lot_allocations table...")
    cur.execute("""
        CREATE TABLE IF NOT EXISTS public.transfer_lot_allocations (
            id BIGSERIAL PRIMARY KEY,
            transfer_id BIGINT NOT NULL REFERENCES public.transfers(id) ON DELETE CASCADE,
            lot_id BIGINT NOT NULL REFERENCES public.material_lots(id) ON DELETE RESTRICT,
            lot_no TEXT NOT NULL,
            quantity NUMERIC(15, 3) NOT NULL,
            created_at TIMESTAMP WITH TIME ZONE NOT NULL DEFAULT CURRENT_TIMESTAMP
        );
        CREATE INDEX IF NOT EXISTS idx_transfer_lot_alloc_transfer ON public.transfer_lot_allocations (transfer_id);
        CREATE INDEX IF NOT EXISTS idx_transfer_lot_alloc_lot ON public.transfer_lot_allocations (lot_id);
    """)

    print("4. Granting permissions and enabling RLS...")
    cur.execute("""
        ALTER TABLE public.material_lots ENABLE ROW LEVEL SECURITY;
        ALTER TABLE public.transfer_lot_allocations ENABLE ROW LEVEL SECURITY;
        
        DROP POLICY IF EXISTS "Enable all access to material_lots" ON public.material_lots;
        CREATE POLICY "Enable all access to material_lots" ON public.material_lots FOR ALL USING (true) WITH CHECK (true);
        
        DROP POLICY IF EXISTS "Enable all access to transfer_lot_allocations" ON public.transfer_lot_allocations;
        CREATE POLICY "Enable all access to transfer_lot_allocations" ON public.transfer_lot_allocations FOR ALL USING (true) WITH CHECK (true);
        
        GRANT ALL ON public.material_lots TO anon, authenticated, service_role;
        GRANT ALL ON public.transfer_lot_allocations TO anon, authenticated, service_role;
        GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO anon, authenticated, service_role;
    """)

    print("5. Initializing material_lots from existing materials with quantity > 0...")
    cur.execute("""
        INSERT INTO public.material_lots (
            material_id, material_code, lot_no, lot_date, initial_quantity, available_quantity, uom
        )
        SELECT 
            m.id, 
            m.material_code, 
            COALESCE(NULLIF(m.lot_no, ''), 'LOT-001'), 
            COALESCE(m.purchase_date, CURRENT_DATE), 
            m.quantity, 
            m.quantity, 
            m.unit
        FROM public.materials m
        WHERE m.quantity > 0
          AND NOT EXISTS (
              SELECT 1 FROM public.material_lots ml WHERE ml.material_code = m.material_code
          );
    """)

    print("6. Updating trg_invoice_items_normalize trigger function...")
    cur.execute("""
        CREATE OR REPLACE FUNCTION public.trg_invoice_items_normalize()
        RETURNS trigger
        LANGUAGE plpgsql
        AS $function$
        BEGIN
            NEW.material := normalize_code(NEW.material);
            NEW.unit := normalize_business_text(NEW.unit);
            IF NEW.lot_no IS NOT NULL THEN
                NEW.lot_no := normalize_business_text(NEW.lot_no);
            END IF;
            IF NEW.batch_no IS NOT NULL THEN
                NEW.batch_no := normalize_business_text(NEW.batch_no);
            END IF;
            -- Keep lot_no and batch_no in sync if one is provided
            IF NEW.lot_no IS NOT NULL AND (NEW.batch_no IS NULL OR NEW.batch_no = '') THEN
                NEW.batch_no := NEW.lot_no;
            ELSIF NEW.batch_no IS NOT NULL AND (NEW.lot_no IS NULL OR NEW.lot_no = '') THEN
                NEW.lot_no := NEW.batch_no;
            END IF;
            IF NEW.hsn_sac IS NOT NULL THEN
                NEW.hsn_sac := normalize_business_text(NEW.hsn_sac);
            END IF;
            IF NEW.grade IS NOT NULL THEN
                NEW.grade := normalize_business_text(NEW.grade);
            END IF;
            RETURN NEW;
        END;
        $function$;
    """)

    print("7. Updating create_purchase RPC...")
    cur.execute("""
        CREATE OR REPLACE FUNCTION public.create_purchase(p_invoice jsonb, p_items jsonb, p_idempotency_key text DEFAULT NULL::text)
        RETURNS jsonb
        LANGUAGE plpgsql
        SECURITY DEFINER
        AS $function$
        DECLARE
            v_idempotency_key TEXT;
            v_cached_response JSONB;
            v_invoice_id BIGINT;
            v_calc_subtotal NUMERIC(15, 2) := 0;
            v_calc_gst_total NUMERIC(15, 2) := 0;
            v_calc_igst_total NUMERIC(15, 2) := 0;
            v_final_grand_total NUMERIC(15, 2) := 0;
            v_final_total NUMERIC(15, 2) := 0;
            
            v_item RECORD;
            v_mat_id BIGINT;
            v_mat_code TEXT;
            v_mat_name TEXT;
            v_category TEXT;
            v_unit TEXT;
            v_qty NUMERIC(15, 3);
            v_unit_price NUMERIC(15, 2);
            v_disc_pct NUMERIC(5, 2);
            v_gst_pct NUMERIC(5, 2);
            v_igst_pct NUMERIC(5, 2);
            v_lot_no TEXT;
            v_hsn_sac TEXT;
            v_grade TEXT;
            v_reorder_level NUMERIC(15, 3);
            v_p_date DATE;
            v_e_date DATE;
            
            v_gross_amount NUMERIC(15, 2);
            v_discount_amount NUMERIC(15, 2);
            v_net_amount NUMERIC(15, 2);
            v_item_gst NUMERIC(15, 2);
            v_item_igst NUMERIC(15, 2);
            v_item_total NUMERIC(15, 2);
            
            v_mat_exists BOOLEAN;
            v_existing_code_for_desc TEXT;
            v_result JSONB;
            v_inv_date DATE;
        BEGIN
            v_idempotency_key := COALESCE(p_idempotency_key, p_invoice->>'idempotency_key');

            -- Idempotency check
            IF v_idempotency_key IS NOT NULL AND TRIM(v_idempotency_key) != '' THEN
                SELECT response INTO v_cached_response 
                FROM idempotency_keys 
                WHERE idempotency_key = v_idempotency_key AND status = 'completed';

                IF v_cached_response IS NOT NULL THEN
                    RETURN v_cached_response;
                END IF;
            END IF;

            v_inv_date := (p_invoice->>'date')::DATE;

            -- Check if invoice_no already exists
            SELECT id INTO v_invoice_id 
            FROM invoices 
            WHERE invoice_no = TRIM(p_invoice->>'invoice_no')
            LIMIT 1;

            IF v_invoice_id IS NOT NULL THEN
                SELECT jsonb_build_object(
                    'success', true,
                    'invoice_id', id,
                    'subtotal', total_excl_tax,
                    'total_gst', total_gst,
                    'total_igst', total_igst,
                    'grand_total', grand_total,
                    'final_total', final_total,
                    'is_duplicate', true
                ) INTO v_result
                FROM invoices WHERE id = v_invoice_id;
                RETURN v_result;
            END IF;

            -- Insert Invoice Header
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
                v_inv_date,
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
                v_lot_no := TRIM(COALESCE(v_item.lot_no, 'LOT-' || LPAD(EXTRACT(DOY FROM v_inv_date)::TEXT, 3, '0')));
                v_hsn_sac := TRIM(COALESCE(v_item.hsn_sac, ''));
                v_grade := UPPER(TRIM(COALESCE(v_item.grade, '')));
                v_reorder_level := COALESCE(v_item.reorder_level, 0);
                
                IF v_item.purchase_date IS NOT NULL AND v_item.purchase_date != '' THEN
                    v_p_date := (v_item.purchase_date)::DATE;
                ELSE
                    v_p_date := v_inv_date;
                END IF;

                IF v_item.expiry_date IS NOT NULL AND v_item.expiry_date != '' THEN
                    v_e_date := (v_item.expiry_date)::DATE;
                ELSE
                    v_e_date := NULL;
                END IF;

                -- Calculations
                v_gross_amount := ROUND((v_qty * v_unit_price)::NUMERIC, 2);
                v_discount_amount := ROUND((v_gross_amount * (v_disc_pct / 100.0))::NUMERIC, 2);
                v_net_amount := v_gross_amount - v_discount_amount;
                v_item_gst := ROUND((v_net_amount * (v_gst_pct / 100.0))::NUMERIC, 2);
                v_item_igst := ROUND((v_net_amount * (v_igst_pct / 100.0))::NUMERIC, 2);
                v_item_total := v_net_amount + v_item_gst + v_item_igst;

                v_calc_subtotal := v_calc_subtotal + v_net_amount;
                v_calc_gst_total := v_calc_gst_total + v_item_gst;
                v_calc_igst_total := v_calc_igst_total + v_item_igst;

                -- Insert line item with both lot_no and batch_no
                INSERT INTO invoice_items (
                    invoice_id, material, quantity, unit, unit_price,
                    discount_percentage, gst_percentage, igst_percentage,
                    item_subtotal, item_gst_value, item_igst_value, item_total,
                    lot_no, batch_no, hsn_sac, grade
                ) VALUES (
                    v_invoice_id, v_mat_code, v_qty, v_unit, v_unit_price,
                    v_disc_pct, v_gst_pct, v_igst_pct,
                    v_net_amount, v_item_gst, v_item_igst, v_item_total,
                    v_lot_no, v_lot_no, v_hsn_sac, v_grade
                );

                -- Check Material Master existence by code
                SELECT id INTO v_mat_id 
                FROM materials 
                WHERE LOWER(material_code) = LOWER(v_mat_code) 
                FOR UPDATE;

                IF v_mat_id IS NOT NULL THEN
                    -- Existing material: update stock and lot_no
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
                    WHERE id = v_mat_id;
                ELSE
                    -- New material: check if description already exists (case-insensitive)
                    SELECT material_code INTO v_existing_code_for_desc
                    FROM materials
                    WHERE LOWER(TRIM(description)) = LOWER(v_mat_name)
                    LIMIT 1;

                    IF v_existing_code_for_desc IS NOT NULL THEN
                        RAISE EXCEPTION 'Material description "%" already exists (under code %).', v_mat_name, v_existing_code_for_desc;
                    END IF;

                    INSERT INTO materials (
                        material_code, description, category, opening_stock,
                        quantity, unit, unit_price, purchase_date, expiry_date,
                        lot_no, reorder_level, hsn_sac, grade, last_updated
                    ) VALUES (
                        v_mat_code, v_mat_name, v_category, 0.000,
                        v_qty, v_unit, v_unit_price, v_p_date, v_e_date,
                        v_lot_no, v_reorder_level, v_hsn_sac, v_grade, CURRENT_TIMESTAMP
                    ) RETURNING id INTO v_mat_id;
                END IF;

                -- Record lot in material_lots (Raw material LOT, NOT storage batches!)
                INSERT INTO material_lots (
                    material_id, material_code, lot_no, lot_date,
                    initial_quantity, available_quantity, uom, invoice_id
                ) VALUES (
                    v_mat_id, v_mat_code, v_lot_no, v_p_date,
                    v_qty, v_qty, v_unit, v_invoice_id
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

            v_result := jsonb_build_object(
                'success', true,
                'invoice_id', v_invoice_id,
                'subtotal', v_calc_subtotal,
                'total_gst', v_calc_gst_total,
                'total_igst', v_calc_igst_total,
                'grand_total', v_final_grand_total,
                'final_total', v_final_total
            );

            -- Store idempotency result
            IF v_idempotency_key IS NOT NULL AND TRIM(v_idempotency_key) != '' THEN
                INSERT INTO idempotency_keys (idempotency_key, operation_type, user_id, device_id, status, response)
                VALUES (
                    v_idempotency_key, 
                    'invoice_create', 
                    auth.uid(), 
                    p_invoice->>'device_id', 
                    'completed', 
                    v_result
                ) ON CONFLICT (idempotency_key) DO UPDATE SET response = EXCLUDED.response;
            END IF;

            -- Audit log
            INSERT INTO audit_logs (user_id, operation, module, record_id, details)
            VALUES (auth.uid(), 'CREATE', 'invoices', v_invoice_id::TEXT, jsonb_build_object('invoice_no', p_invoice->>'invoice_no', 'grand_total', v_final_grand_total));

            -- Recalculate alerts
            PERFORM generate_inventory_alerts();

            RETURN v_result;
        END;
        $function$;
    """)

    print("8. Updating update_purchase RPC...")
    cur.execute("""
        CREATE OR REPLACE FUNCTION public.update_purchase(p_invoice_id bigint, p_invoice jsonb, p_items jsonb)
        RETURNS jsonb
        LANGUAGE plpgsql
        SECURITY DEFINER
        AS $function$
        DECLARE
            v_old_item RECORD;
            v_item RECORD;
            v_calc_subtotal NUMERIC(15, 2) := 0;
            v_calc_gst_total NUMERIC(15, 2) := 0;
            v_calc_igst_total NUMERIC(15, 2) := 0;
            v_final_grand_total NUMERIC(15, 2) := 0;
            v_final_total NUMERIC(15, 2) := 0;
            
            v_mat_id BIGINT;
            v_mat_code TEXT;
            v_mat_name TEXT;
            v_category TEXT;
            v_unit TEXT;
            v_qty NUMERIC(15, 3);
            v_unit_price NUMERIC(15, 2);
            v_disc_pct NUMERIC(5, 2);
            v_gst_pct NUMERIC(5, 2);
            v_igst_pct NUMERIC(5, 2);
            v_lot_no TEXT;
            v_hsn_sac TEXT;
            v_grade TEXT;
            v_reorder_level NUMERIC(15, 3);
            v_p_date DATE;
            v_e_date DATE;
            v_inv_date DATE;
            
            v_gross_amount NUMERIC(15, 2);
            v_discount_amount NUMERIC(15, 2);
            v_net_amount NUMERIC(15, 2);
            v_item_gst NUMERIC(15, 2);
            v_item_igst NUMERIC(15, 2);
            v_item_total NUMERIC(15, 2);
            v_result JSONB;
        BEGIN
            -- 1. Ensure invoice exists
            IF NOT EXISTS (SELECT 1 FROM invoices WHERE id = p_invoice_id FOR UPDATE) THEN
                RAISE EXCEPTION 'Invoice with ID % not found', p_invoice_id;
            END IF;

            v_inv_date := (p_invoice->>'date')::DATE;

            -- 2. Reverse previous invoice line items stock impact
            FOR v_old_item IN SELECT material, quantity FROM invoice_items WHERE invoice_id = p_invoice_id
            LOOP
                UPDATE materials
                SET quantity = GREATEST(0, quantity - v_old_item.quantity),
                    last_updated = CURRENT_TIMESTAMP
                WHERE material_code = v_old_item.material;
            END LOOP;

            -- 3. Delete old material_lots created by this invoice
            DELETE FROM material_lots WHERE invoice_id = p_invoice_id;
            DELETE FROM invoice_items WHERE invoice_id = p_invoice_id;

            -- 4. Update Invoice Header
            UPDATE invoices
            SET purchase_id = COALESCE(p_invoice->>'purchase_id', purchase_id),
                date = v_inv_date,
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
                v_lot_no := TRIM(COALESCE(v_item.lot_no, 'LOT-' || LPAD(EXTRACT(DOY FROM v_inv_date)::TEXT, 3, '0')));
                v_hsn_sac := TRIM(COALESCE(v_item.hsn_sac, ''));
                v_grade := UPPER(TRIM(COALESCE(v_item.grade, '')));
                v_reorder_level := COALESCE(v_item.reorder_level, 0);
                
                IF v_item.purchase_date IS NOT NULL AND v_item.purchase_date != '' THEN
                    v_p_date := (v_item.purchase_date)::DATE;
                ELSE
                    v_p_date := v_inv_date;
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
                    lot_no, batch_no, hsn_sac, grade
                ) VALUES (
                    p_invoice_id, v_mat_code, v_qty, v_unit, v_unit_price,
                    v_disc_pct, v_gst_pct, v_igst_pct,
                    v_net_amount, v_item_gst, v_item_igst, v_item_total,
                    v_lot_no, v_lot_no, v_hsn_sac, v_grade
                );

                -- Update or insert Material Master row
                SELECT id INTO v_mat_id
                FROM materials 
                WHERE LOWER(material_code) = LOWER(v_mat_code)
                FOR UPDATE;

                IF v_mat_id IS NOT NULL THEN
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
                    WHERE id = v_mat_id;
                ELSE
                    INSERT INTO materials (
                        material_code, description, category, opening_stock,
                        quantity, unit, unit_price, purchase_date, expiry_date,
                        lot_no, reorder_level, hsn_sac, grade, last_updated
                    ) VALUES (
                        v_mat_code, v_mat_name, v_category, 0.000,
                        v_qty, v_unit, v_unit_price, v_p_date, v_e_date,
                        v_lot_no, v_reorder_level, v_hsn_sac, v_grade, CURRENT_TIMESTAMP
                    ) RETURNING id INTO v_mat_id;
                END IF;

                -- Record lot in material_lots
                INSERT INTO material_lots (
                    material_id, material_code, lot_no, lot_date,
                    initial_quantity, available_quantity, uom, invoice_id
                ) VALUES (
                    v_mat_id, v_mat_code, v_lot_no, v_p_date,
                    v_qty, v_qty, v_unit, p_invoice_id
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
        $function$;
    """)

    print("9. Updating delete_purchase RPC...")
    cur.execute("""
        CREATE OR REPLACE FUNCTION public.delete_purchase(p_invoice_id bigint)
        RETURNS boolean
        LANGUAGE plpgsql
        SECURITY DEFINER
        AS $function$
        DECLARE
            v_item RECORD;
        BEGIN
            -- Revert material stock for each item in the invoice
            FOR v_item IN SELECT material, quantity FROM invoice_items WHERE invoice_id = p_invoice_id
            LOOP
                UPDATE materials
                SET quantity = GREATEST(0, quantity - v_item.quantity),
                    last_updated = CURRENT_TIMESTAMP
                WHERE material_code = v_item.material;
            END LOOP;

            -- Delete associated material_lots
            DELETE FROM material_lots WHERE invoice_id = p_invoice_id;

            -- Delete invoice (invoice_items cascade delete automatically)
            DELETE FROM invoices WHERE id = p_invoice_id;

            RETURN true;
        END;
        $function$;
    """)

    print("10. Updating create_transfer RPC for multi-lot FIFO allocation...")
    cur.execute("""
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
                FROM idempotency_keys 
                WHERE idempotency_key = v_idempotency_key AND status = 'completed';

                IF v_cached_response IS NOT NULL THEN
                    RETURN v_cached_response;
                END IF;
            END IF;

            v_code := TRIM(p_transfer->>'code');
            v_dept := TRIM(COALESCE(p_transfer->>'department', ''));
            v_person := TRIM(COALESCE(p_transfer->>'person', ''));
            v_units := TRIM(COALESCE(p_transfer->>'units', 'kg'));
            
            IF p_transfer->>'date' IS NOT NULL AND TRIM(p_transfer->>'date') != '' THEN
                v_date := (p_transfer->>'date')::DATE;
            ELSE
                v_date := CURRENT_DATE;
            END IF;
            
            v_created_at := CURRENT_TIMESTAMP;
            v_outward := COALESCE((p_transfer->>'outward')::NUMERIC, 0.000);
            v_return_units := COALESCE((p_transfer->>'return_units')::NUMERIC, 0.000);

            -- Find Material Master record with atomic lock
            SELECT id, quantity, description, unit
            INTO v_mat_id, v_current_stock, v_desc, v_units
            FROM materials
            WHERE material_code = v_code
            FOR UPDATE;

            IF v_mat_id IS NULL THEN
                RAISE EXCEPTION 'Material not found in Material Master for code: %', v_code;
            END IF;

            -- Check available stock in material_lots
            SELECT COALESCE(SUM(available_quantity), 0)
            INTO v_total_lot_stock
            FROM material_lots
            WHERE material_code = v_code AND available_quantity > 0;

            -- If material has general stock but no lots yet, backfill a lot
            IF v_total_lot_stock < v_current_stock AND v_current_stock > 0 THEN
                INSERT INTO material_lots (
                    material_id, material_code, lot_no, lot_date, initial_quantity, available_quantity, uom
                ) VALUES (
                    v_mat_id, v_code, 'LOT-001', v_date, (v_current_stock - v_total_lot_stock), (v_current_stock - v_total_lot_stock), v_units
                );
                v_total_lot_stock := v_current_stock;
            END IF;

            -- Stock validation
            IF v_outward > v_total_lot_stock THEN
                RAISE EXCEPTION 'Insufficient stock. Available: % %, Requested: % %', v_total_lot_stock, v_units, v_outward, v_units;
            END IF;

            -- Net Change = Return Quantity - Outward Quantity
            v_net_change := v_return_units - v_outward;
            v_remaining_balance := ROUND(v_current_stock + v_net_change, 3);

            -- Deduct from Material master
            UPDATE materials
            SET quantity = v_remaining_balance,
                last_updated = CURRENT_TIMESTAMP
            WHERE id = v_mat_id;

            -- Save transfer record initially
            INSERT INTO transfers (
                date, code, description, lot_no, outward, units, department, person, return_units, availability, created_at
            ) VALUES (
                v_date, v_code, v_desc, '', v_outward, v_units, v_dept, v_person, v_return_units, v_remaining_balance, v_created_at
            ) RETURNING id INTO v_transfer_id;

            -- Multi-lot FIFO allocation from material_lots
            v_needed := v_outward;
            IF v_needed > 0 THEN
                FOR v_lot IN 
                    SELECT id, lot_no, available_quantity 
                    FROM material_lots 
                    WHERE material_code = v_code AND available_quantity > 0
                    ORDER BY lot_date ASC, id ASC
                    FOR UPDATE
                LOOP
                    EXIT WHEN v_needed <= 0;

                    v_take := LEAST(v_lot.available_quantity, v_needed);

                    -- Deduct from lot
                    UPDATE material_lots
                    SET available_quantity = available_quantity - v_take
                    WHERE id = v_lot.id;

                    -- Record allocation
                    INSERT INTO transfer_lot_allocations (
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

            -- Update transfers with allocated lot summary
            UPDATE transfers
            SET lot_no = v_lots_allocated
            WHERE id = v_transfer_id;

            v_result := jsonb_build_object(
                'success', true,
                'transfer_id', v_transfer_id,
                'lot_no', v_lots_allocated,
                'net_change', v_net_change,
                'remaining_balance', v_remaining_balance
            );

            -- Store idempotency
            IF v_idempotency_key IS NOT NULL AND TRIM(v_idempotency_key) != '' THEN
                INSERT INTO idempotency_keys (idempotency_key, operation_type, user_id, device_id, status, response)
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
            INSERT INTO audit_logs (user_id, operation, module, record_id, details)
            VALUES (auth.uid(), 'CREATE', 'transfers', v_transfer_id::TEXT, jsonb_build_object('code', v_code, 'outward', v_outward, 'department', v_dept, 'lots', v_lots_allocated));

            -- Recalculate alerts
            PERFORM generate_inventory_alerts();

            RETURN v_result;
        END;
        $function$;
    """)

    print("11. Updating delete_transfer RPC for exact lot restoration...")
    cur.execute("""
        CREATE OR REPLACE FUNCTION public.delete_transfer(p_transfer_id bigint)
        RETURNS boolean
        LANGUAGE plpgsql
        SECURITY DEFINER
        AS $function$
        DECLARE
            v_transfer RECORD;
            v_alloc RECORD;
            v_net_change NUMERIC(15, 3);
        BEGIN
            SELECT * INTO v_transfer FROM transfers WHERE id = p_transfer_id;
            IF v_transfer IS NULL THEN
                RETURN false;
            END IF;

            -- Restore exact quantities to exact lots from transfer_lot_allocations
            FOR v_alloc IN SELECT lot_id, quantity FROM transfer_lot_allocations WHERE transfer_id = p_transfer_id
            LOOP
                UPDATE material_lots
                SET available_quantity = available_quantity + v_alloc.quantity
                WHERE id = v_alloc.lot_id;
            END LOOP;

            -- Revert materials master quantity: old net change was return_units - outward
            v_net_change := v_transfer.return_units - v_transfer.outward;

            UPDATE materials
            SET quantity = GREATEST(0, ROUND(quantity - v_net_change, 3)),
                last_updated = CURRENT_TIMESTAMP
            WHERE material_code = v_transfer.code;

            -- Delete transfer (transfer_lot_allocations cascade automatically)
            DELETE FROM transfers WHERE id = p_transfer_id;

            RETURN true;
        END;
        $function$;
    """)

    print("12. Updating update_transfer RPC for exact lot restoration and re-allocation...")
    cur.execute("""
        CREATE OR REPLACE FUNCTION public.update_transfer(p_transfer_id bigint, p_transfer jsonb)
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
            
            v_needed NUMERIC(15, 3);
            v_lot RECORD;
            v_take NUMERIC(15, 3);
            v_lots_allocated TEXT := '';
            v_result JSONB;
        BEGIN
            SELECT * INTO v_old_transfer FROM transfers WHERE id = p_transfer_id FOR UPDATE;
            IF v_old_transfer IS NULL THEN
                RAISE EXCEPTION 'Transfer with ID % not found', p_transfer_id;
            END IF;

            v_code := TRIM(COALESCE(p_transfer->>'code', v_old_transfer.code));
            v_dept := TRIM(COALESCE(p_transfer->>'department', v_old_transfer.department, ''));
            v_person := TRIM(COALESCE(p_transfer->>'person', v_old_transfer.person, ''));
            v_units := TRIM(COALESCE(p_transfer->>'units', v_old_transfer.units, 'kg'));
            v_date := (COALESCE(p_transfer->>'date', v_old_transfer.date::TEXT))::DATE;
            v_new_outward := COALESCE((p_transfer->>'outward')::NUMERIC, v_old_transfer.outward);
            v_new_return := COALESCE((p_transfer->>'return_units')::NUMERIC, v_old_transfer.return_units);

            -- 1. Restore exact previous lot allocations
            FOR v_alloc IN SELECT lot_id, quantity FROM transfer_lot_allocations WHERE transfer_id = p_transfer_id
            LOOP
                UPDATE material_lots
                SET available_quantity = available_quantity + v_alloc.quantity
                WHERE id = v_alloc.lot_id;
            END LOOP;
            DELETE FROM transfer_lot_allocations WHERE transfer_id = p_transfer_id;

            -- 2. Reverse previous materials quantity impact
            SELECT id, quantity, description, unit
            INTO v_mat_id, v_current_stock, v_dept, v_units
            FROM materials
            WHERE material_code = v_code
            FOR UPDATE;

            IF v_mat_id IS NULL THEN
                RAISE EXCEPTION 'Material not found in Material Master for code: %', v_code;
            END IF;

            v_old_net := v_old_transfer.return_units - v_old_transfer.outward;
            v_adjusted_stock := v_current_stock - v_old_net;

            -- Check stock
            SELECT COALESCE(SUM(available_quantity), 0)
            INTO v_current_stock
            FROM material_lots
            WHERE material_code = v_code AND available_quantity > 0;

            IF v_new_outward > v_current_stock THEN
                RAISE EXCEPTION 'Insufficient stock. Available: % %, Requested: % %', v_current_stock, v_units, v_new_outward, v_units;
            END IF;

            v_new_net := v_new_return - v_new_outward;
            v_final_stock := ROUND(v_adjusted_stock + v_new_net, 3);

            UPDATE materials
            SET quantity = v_final_stock,
                last_updated = CURRENT_TIMESTAMP
            WHERE id = v_mat_id;

            -- 3. Re-allocate lots FIFO
            v_needed := v_new_outward;
            IF v_needed > 0 THEN
                FOR v_lot IN 
                    SELECT id, lot_no, available_quantity 
                    FROM material_lots 
                    WHERE material_code = v_code AND available_quantity > 0
                    ORDER BY lot_date ASC, id ASC
                    FOR UPDATE
                LOOP
                    EXIT WHEN v_needed <= 0;

                    v_take := LEAST(v_lot.available_quantity, v_needed);

                    UPDATE material_lots
                    SET available_quantity = available_quantity - v_take
                    WHERE id = v_lot.id;

                    INSERT INTO transfer_lot_allocations (
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

            -- 4. Update transfer record
            UPDATE transfers
            SET date = v_date,
                code = v_code,
                lot_no = v_lots_allocated,
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
                'lot_no', v_lots_allocated,
                'net_change', v_new_net,
                'remaining_balance', v_final_stock
            );

            INSERT INTO audit_logs (user_id, operation, module, record_id, details)
            VALUES (auth.uid(), 'UPDATE', 'transfers', p_transfer_id::TEXT, v_result);

            PERFORM generate_inventory_alerts();

            RETURN v_result;
        END;
        $function$;
    """)

    print("Migration completed successfully!")
    conn.close()

if __name__ == '__main__':
    run_migration()
