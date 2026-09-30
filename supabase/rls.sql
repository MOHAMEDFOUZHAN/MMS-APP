-- ============================================================================
-- BENCHMARK MMS — ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================================================

-- 1. Enable RLS on all tables
ALTER TABLE materials ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispatches ENABLE ROW LEVEL SECURITY;
ALTER TABLE dispatch_batches ENABLE ROW LEVEL SECURITY;
ALTER TABLE transfers ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_adjustments ENABLE ROW LEVEL SECURITY;
ALTER TABLE category_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE vendors ENABLE ROW LEVEL SECURITY;
ALTER TABLE system_settings ENABLE ROW LEVEL SECURITY;

-- 2. Authenticated user policies
-- materials
CREATE POLICY "Authenticated users can view materials"
ON materials FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Authenticated users can insert materials"
ON materials FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update materials"
ON materials FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Authenticated users can delete materials"
ON materials FOR DELETE TO authenticated USING (true);

-- invoices
CREATE POLICY "Authenticated users can view invoices"
ON invoices FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Authenticated users can insert invoices"
ON invoices FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update invoices"
ON invoices FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Authenticated users can delete invoices"
ON invoices FOR DELETE TO authenticated USING (true);

-- invoice_items
CREATE POLICY "Authenticated users can view invoice_items"
ON invoice_items FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Authenticated users can insert invoice_items"
ON invoice_items FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update invoice_items"
ON invoice_items FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Authenticated users can delete invoice_items"
ON invoice_items FOR DELETE TO authenticated USING (true);

-- batches
CREATE POLICY "Authenticated users can view batches"
ON batches FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Authenticated users can insert batches"
ON batches FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update batches"
ON batches FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Authenticated users can delete batches"
ON batches FOR DELETE TO authenticated USING (true);

-- dispatches
CREATE POLICY "Authenticated users can view dispatches"
ON dispatches FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Authenticated users can insert dispatches"
ON dispatches FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update dispatches"
ON dispatches FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Authenticated users can delete dispatches"
ON dispatches FOR DELETE TO authenticated USING (true);

-- dispatch_batches
CREATE POLICY "Authenticated users can view dispatch_batches"
ON dispatch_batches FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Authenticated users can insert dispatch_batches"
ON dispatch_batches FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update dispatch_batches"
ON dispatch_batches FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Authenticated users can delete dispatch_batches"
ON dispatch_batches FOR DELETE TO authenticated USING (true);

-- transfers
CREATE POLICY "Authenticated users can view transfers"
ON transfers FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Authenticated users can insert transfers"
ON transfers FOR INSERT TO authenticated WITH CHECK (true);

CREATE POLICY "Authenticated users can update transfers"
ON transfers FOR UPDATE TO authenticated USING (true) WITH CHECK (true);

CREATE POLICY "Authenticated users can delete transfers"
ON transfers FOR DELETE TO authenticated USING (true);

-- stock_adjustments
CREATE POLICY "Authenticated users can view stock_adjustments"
ON stock_adjustments FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Authenticated users can insert stock_adjustments"
ON stock_adjustments FOR INSERT TO authenticated WITH CHECK (true);

-- category_locations
CREATE POLICY "Authenticated users can view category_locations"
ON category_locations FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Authenticated users can manage category_locations"
ON category_locations FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);

-- vendors
CREATE POLICY "Authenticated users can view vendors"
ON vendors FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Authenticated users can manage vendors"
ON vendors FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);

-- system_settings
CREATE POLICY "Authenticated users can view system_settings"
ON system_settings FOR SELECT TO authenticated, anon USING (true);

CREATE POLICY "Authenticated users can update system_settings"
ON system_settings FOR ALL TO authenticated, anon USING (true) WITH CHECK (true);

-- 3. Enable Realtime Publications for key tables
DO $$
BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE materials;
    ALTER PUBLICATION supabase_realtime ADD TABLE batches;
    ALTER PUBLICATION supabase_realtime ADD TABLE dispatches;
    ALTER PUBLICATION supabase_realtime ADD TABLE transfers;
    ALTER PUBLICATION supabase_realtime ADD TABLE invoices;
EXCEPTION WHEN OTHERS THEN
    NULL;
END;
$$;
