-- ============================================================================
-- BENCHMARK MMS — CHOCOLATE DEPARTMENT ACCESS CONTROL, RACK & CONSIGNMENT
-- ============================================================================

-- 1. Ensure user_profiles_role_check constraint allows CHOCOLATE_USER
ALTER TABLE public.user_profiles 
DROP CONSTRAINT IF EXISTS user_profiles_role_check;

ALTER TABLE public.user_profiles 
ADD CONSTRAINT user_profiles_role_check 
CHECK (role = ANY (ARRAY['OWNER'::text, 'ADMIN'::text, 'MANAGER'::text, 'STAFF'::text, 'VIEWER'::text, 'TEA_USER'::text, 'CHOCOLATE_USER'::text]));

-- 2. Add rack_location column to batches and storage_products
ALTER TABLE public.batches ADD COLUMN IF NOT EXISTS rack_location TEXT;
ALTER TABLE public.storage_products ADD COLUMN IF NOT EXISTS rack_location TEXT;

-- 3. HELPER FUNCTIONS: is_chocolate_user and is_chocolate_product
CREATE OR REPLACE FUNCTION public.is_chocolate_user()
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

    IF UPPER(COALESCE(v_role, '')) = 'CHOCOLATE_USER' OR LOWER(COALESCE(v_username, '')) IN ('chocolate', 'cho') THEN
        RETURN TRUE;
    END IF;

    SELECT (raw_user_meta_data->>'role'), (raw_user_meta_data->>'username') 
    INTO v_role, v_username
    FROM auth.users
    WHERE id = auth.uid();

    IF UPPER(COALESCE(v_role, '')) = 'CHOCOLATE_USER' OR LOWER(COALESCE(v_username, '')) IN ('chocolate', 'cho') THEN
        RETURN TRUE;
    END IF;

    RETURN FALSE;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_chocolate_product(p_code TEXT)
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
      AND UPPER(TRIM(category)) = 'CHOCOLATE'
    LIMIT 1;

    IF COALESCE(v_exists, FALSE) THEN
        RETURN TRUE;
    END IF;

    -- Check storage_products
    SELECT TRUE INTO v_exists
    FROM public.storage_products
    WHERE LOWER(TRIM(product_code)) = LOWER(v_clean_code)
      AND UPPER(TRIM(category)) = 'CHOCOLATE'
    LIMIT 1;

    IF COALESCE(v_exists, FALSE) THEN
        RETURN TRUE;
    END IF;

    -- Check batches
    SELECT TRUE INTO v_exists
    FROM public.batches
    WHERE (LOWER(TRIM(material_code)) = LOWER(v_clean_code) OR LOWER(TRIM(batch_no)) = LOWER(v_clean_code))
      AND UPPER(TRIM(category)) = 'CHOCOLATE'
    LIMIT 1;

    RETURN COALESCE(v_exists, FALSE);
END;
$$;

-- 4. RLS POLICIES FOR CHOCOLATE USER
-- Transfers: Select only chocolate transfers, no deletes for chocolate user
DROP POLICY IF EXISTS "chocolate_user_transfers_select" ON public.transfers;
CREATE POLICY "chocolate_user_transfers_select" ON public.transfers
FOR SELECT TO authenticated
USING (
    NOT public.is_chocolate_user() OR UPPER(COALESCE(category, '')) = 'CHOCOLATE'
);

DROP POLICY IF EXISTS "chocolate_user_transfers_no_delete" ON public.transfers;
CREATE POLICY "chocolate_user_transfers_no_delete" ON public.transfers
FOR DELETE TO authenticated
USING (
    NOT public.is_chocolate_user()
);

-- Batches: Select only chocolate batches
DROP POLICY IF EXISTS "chocolate_user_batches_select" ON public.batches;
CREATE POLICY "chocolate_user_batches_select" ON public.batches
FOR SELECT TO authenticated
USING (
    NOT public.is_chocolate_user() OR UPPER(COALESCE(category, '')) = 'CHOCOLATE'
);

-- Storage Products: Select only chocolate products
DROP POLICY IF EXISTS "chocolate_user_storage_products_select" ON public.storage_products;
CREATE POLICY "chocolate_user_storage_products_select" ON public.storage_products
FOR SELECT TO authenticated
USING (
    NOT public.is_chocolate_user() OR UPPER(COALESCE(category, '')) = 'CHOCOLATE'
);

-- Dispatches (Consignment): Select only chocolate dispatches
DROP POLICY IF EXISTS "chocolate_user_dispatches_select" ON public.dispatches;
CREATE POLICY "chocolate_user_dispatches_select" ON public.dispatches
FOR SELECT TO authenticated
USING (
    NOT public.is_chocolate_user() OR UPPER(COALESCE(category, '')) = 'CHOCOLATE' OR UPPER(COALESCE(department, '')) = 'CHOCOLATE'
);

-- 5. CHOCOLATE OCR IMMUTABLE CONFIRMED LEDGER
CREATE TABLE IF NOT EXISTS public.chocolate_ocr_ledger (
    id BIGSERIAL PRIMARY KEY,
    description TEXT NOT NULL,
    quantity NUMERIC NOT NULL CHECK (quantity > 0),
    unit TEXT NOT NULL DEFAULT 'KG',
    raw_ocr_quantity NUMERIC NOT NULL,
    raw_ocr_text TEXT,
    document_name TEXT,
    status TEXT NOT NULL DEFAULT 'CONFIRMED',
    confirmed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    idempotency_key TEXT UNIQUE,
    created_by TEXT DEFAULT 'chocolate',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enable Row Level Security
ALTER TABLE public.chocolate_ocr_ledger ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Allow select for all" ON public.chocolate_ocr_ledger;
CREATE POLICY "Allow select for all" ON public.chocolate_ocr_ledger
FOR SELECT TO authenticated
USING (true);

DROP POLICY IF EXISTS "Allow insert for confirmed records" ON public.chocolate_ocr_ledger;
CREATE POLICY "Allow insert for confirmed records" ON public.chocolate_ocr_ledger
FOR INSERT TO authenticated
WITH CHECK (quantity > 0 AND status = 'CONFIRMED');

-- Immutable: Strictly NO update and NO delete policies for non-admin/client users.

