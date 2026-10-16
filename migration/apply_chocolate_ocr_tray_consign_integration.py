import os
import sys
import psycopg2

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = os.environ.get("SUPABASE_DB_PASSWORD", "mapleconnect2307")
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

def main():
    print("=" * 60)
    print("MIGRATION: Integrate Chocolate OCR, Tray, and Consign")
    print("=" * 60)

    conn = psycopg2.connect(
        host=HOST,
        port=PORT,
        user=USER,
        password=PASSWORD,
        dbname=DBNAME,
        connect_timeout=15
    )
    conn.autocommit = False
    cur = conn.cursor()

    try:
        # 1. Add product_code column to chocolate_ocr_ledger if not exists
        print("1. Adding product_code column to chocolate_ocr_ledger...")
        cur.execute("""
        ALTER TABLE public.chocolate_ocr_ledger
        ADD COLUMN IF NOT EXISTS product_code TEXT;
        """)

        cur.execute("""
        CREATE INDEX IF NOT EXISTS idx_chocolate_ocr_ledger_prod
        ON public.chocolate_ocr_ledger (product_code, description);
        """)

        # 2. Add ocr_ledger_id to batches table
        print("2. Adding ocr_ledger_id column to batches table...")
        cur.execute("""
        ALTER TABLE public.batches
        ADD COLUMN IF NOT EXISTS ocr_ledger_id BIGINT REFERENCES public.chocolate_ocr_ledger(id) ON DELETE SET NULL;
        """)

        cur.execute("""
        CREATE INDEX IF NOT EXISTS idx_batches_ocr_ledger_id
        ON public.batches (ocr_ledger_id);
        """)

        # 3. Add ocr_ledger_id to dispatches table
        print("3. Adding ocr_ledger_id column to dispatches table...")
        cur.execute("""
        ALTER TABLE public.dispatches
        ADD COLUMN IF NOT EXISTS ocr_ledger_id BIGINT REFERENCES public.chocolate_ocr_ledger(id) ON DELETE SET NULL;
        """)

        cur.execute("""
        CREATE INDEX IF NOT EXISTS idx_dispatches_ocr_ledger_id
        ON public.dispatches (ocr_ledger_id);
        """)

        # 4. Update get_dispatch_available_products to filter by p_category and order by product_name ASC
        print("4. Updating get_dispatch_available_products function for alphabetical sorting and category filtering...")
        cur.execute("""
        CREATE OR REPLACE FUNCTION public.get_dispatch_available_products(
            p_search text DEFAULT NULL::text, 
            p_category text DEFAULT NULL::text
        )
        RETURNS TABLE(
            product_code text, 
            product_name text, 
            uom text, 
            grade text, 
            category text, 
            total_available numeric, 
            batch_count bigint
        )
        LANGUAGE plpgsql
        SECURITY DEFINER
        AS $$
        DECLARE
            v_term TEXT;
            v_is_tea BOOLEAN;
            v_cat_filter TEXT;
        BEGIN
            v_term := NULLIF(TRIM(p_search), '');
            v_cat_filter := NULLIF(UPPER(TRIM(p_category)), '');
            v_is_tea := public.is_tea_user() OR (v_cat_filter = 'TEA');

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
                  -- If Tea user, strictly Tea items
                  (NOT v_is_tea) OR
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
              AND (
                  -- If category filter supplied (e.g. CHOCOLATE), strictly enforce
                  v_cat_filter IS NULL OR
                  UPPER(COALESCE(b.category, '')) = v_cat_filter
              )
            GROUP BY b.material_code
            HAVING SUM(b.available_quantity) > 0.0001
            ORDER BY COALESCE(NULLIF(MAX(b.description), ''), b.material_code) ASC, b.material_code ASC;
        END;
        $$;
        """)

        # 5. Update create_dispatch_fifo to support ocr_ledger_id
        print("5. Updating create_dispatch_fifo to persist ocr_ledger_id...")
        cur.execute("""
        CREATE OR REPLACE FUNCTION public.create_dispatch_fifo(
            p_dispatch jsonb, 
            p_idempotency_key text DEFAULT NULL::text
        )
        RETURNS jsonb
        LANGUAGE plpgsql
        SECURITY DEFINER
        AS $$
        DECLARE
            v_idempotency_key TEXT;
            v_existing_response JSONB;
            v_dispatch_id BIGINT;
            v_prod_code TEXT;
            v_prod_name TEXT;
            v_req_qty NUMERIC(15, 3);
            v_ret_qty NUMERIC(15, 3);
            v_net_qty NUMERIC(15, 3);
            v_unit TEXT;
            v_category TEXT;
            v_grade TEXT;
            v_location TEXT;
            v_dept TEXT;
            v_remarks TEXT;
            v_date DATE;
            v_storage_prod_id BIGINT;
            v_ocr_ledger_id BIGINT;
            v_total_available NUMERIC(15, 3);
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
            v_ocr_ledger_id := (p_dispatch->>'ocr_ledger_id')::BIGINT;
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
                date, material_code, product, quantity, return_quantity, net_quantity, 
                units, location, department, remarks, category, grade, storage_product_id, 
                ocr_ledger_id, created_by, updated_at
            ) VALUES (
                v_date, v_prod_code, v_prod_name, v_req_qty, v_ret_qty, v_net_qty, 
                v_unit, v_location, v_dept, v_remarks, v_category, v_grade, v_storage_prod_id, 
                v_ocr_ledger_id, v_created_by, CURRENT_TIMESTAMP
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
                'ocr_ledger_id', v_ocr_ledger_id,
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
                jsonb_build_object('product_code', v_prod_code, 'quantity', v_req_qty, 'return', v_ret_qty, 'net', v_net_qty, 'ocr_ledger_id', v_ocr_ledger_id)
            );

            RETURN v_result;
        END;
        $$;
        """)

        conn.commit()
        print("\n[SUCCESS] Migration applied cleanly!")

    except Exception as e:
        conn.rollback()
        print(f"\n[ERROR] Migration failed: {e}")
        sys.exit(1)
    finally:
        cur.close()
        conn.close()

if __name__ == "__main__":
    main()
