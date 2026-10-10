-- ============================================================================
-- BENCHMARK MMS — SUPABASE SECURITY HARDENING & AUDIT ROUTINES
-- Enterprise PostgreSQL Security Patches: RLS, Functions, and Search Path
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. HARDEN SECURITY DEFINER FUNCTIONS (Mitigate CWE-426 Mutable search_path)
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    -- create_purchase
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'create_purchase') THEN
        ALTER FUNCTION create_purchase(JSONB, JSONB) SET search_path = public, pg_temp;
    END IF;

    -- reset_daily_opening_stock
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'reset_daily_opening_stock') THEN
        ALTER FUNCTION reset_daily_opening_stock() SET search_path = public, pg_temp;
    END IF;

    -- process_dispatch (if exists)
    IF EXISTS (SELECT 1 FROM pg_proc WHERE proname = 'process_dispatch') THEN
        ALTER FUNCTION process_dispatch(JSONB, JSONB) SET search_path = public, pg_temp;
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 2. HARDEN OVERLY PERMISSIVE RLS POLICIES (Remove anon write access)
-- ----------------------------------------------------------------------------

-- Vendors Table: Restrict write operations strictly to authenticated users
DROP POLICY IF EXISTS "Authenticated users can manage vendors" ON vendors;
CREATE POLICY "Authenticated users can manage vendors"
ON vendors FOR ALL TO authenticated
USING (true) WITH CHECK (true);

-- Ensure anonymous can only read vendors if needed, but never write
DROP POLICY IF EXISTS "Anonymous users can view vendors" ON vendors;
CREATE POLICY "Anonymous users can view vendors"
ON vendors FOR SELECT TO anon
USING (true);

-- Category Locations Table: Restrict write operations to authenticated users
DROP POLICY IF EXISTS "Authenticated users can manage category_locations" ON category_locations;
CREATE POLICY "Authenticated users can manage category_locations"
ON category_locations FOR ALL TO authenticated
USING (true) WITH CHECK (true);

DROP POLICY IF EXISTS "Anonymous users can view category_locations" ON category_locations;
CREATE POLICY "Anonymous users can view category_locations"
ON category_locations FOR SELECT TO anon
USING (true);

-- System Settings Table: Restrict updates strictly to authenticated users
DROP POLICY IF EXISTS "Authenticated users can update system_settings" ON system_settings;
CREATE POLICY "Authenticated users can update system_settings"
ON system_settings FOR ALL TO authenticated
USING (true) WITH CHECK (true);

-- ----------------------------------------------------------------------------
-- 3. ENSURE RLS IS ENABLED ON ALL AUXILIARY TABLES
-- ----------------------------------------------------------------------------
ALTER TABLE IF EXISTS storage_products ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS inventory_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS audit_logs ENABLE ROW LEVEL SECURITY;

DO $$
BEGIN
    -- inventory_settings
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'inventory_settings' AND policyname = 'Authenticated view inventory_settings') THEN
        CREATE POLICY "Authenticated view inventory_settings" ON inventory_settings FOR SELECT TO authenticated, anon USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'inventory_settings' AND policyname = 'Authenticated manage inventory_settings') THEN
        CREATE POLICY "Authenticated manage inventory_settings" ON inventory_settings FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;

    -- storage_products
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'storage_products' AND policyname = 'Authenticated view storage_products') THEN
        CREATE POLICY "Authenticated view storage_products" ON storage_products FOR SELECT TO authenticated, anon USING (true);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'storage_products' AND policyname = 'Authenticated manage storage_products') THEN
        CREATE POLICY "Authenticated manage storage_products" ON storage_products FOR ALL TO authenticated USING (true) WITH CHECK (true);
    END IF;

    -- notifications
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'notifications' AND policyname = 'Authenticated view notifications') THEN
        CREATE POLICY "Authenticated view notifications" ON notifications FOR SELECT TO authenticated USING (true);
    END IF;
END $$;

-- ----------------------------------------------------------------------------
-- 4. NON-NEGATIVE INVENTORY CHECK CONSTRAINTS
-- ----------------------------------------------------------------------------
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_materials_qty_non_negative') THEN
        ALTER TABLE materials ADD CONSTRAINT chk_materials_qty_non_negative CHECK (quantity >= 0);
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_constraint WHERE conname = 'chk_batches_avail_non_negative') THEN
        ALTER TABLE batches ADD CONSTRAINT chk_batches_avail_non_negative CHECK (available_quantity >= 0);
    END IF;
END $$;
