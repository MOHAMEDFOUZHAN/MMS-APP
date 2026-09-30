-- ============================================================================
-- GLOBAL TEXT STANDARDIZATION & INTEGRITY TRIGGERS
-- PostgreSQL Database Functions and Triggers for Supabase Cloud
-- ============================================================================

-- 1. IMMUTABLE NORMALIZATION FUNCTIONS
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION normalize_business_text(t TEXT)
RETURNS TEXT AS $$
BEGIN
    IF t IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN UPPER(REGEXP_REPLACE(TRIM(t), '\s+', ' ', 'g'));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

CREATE OR REPLACE FUNCTION normalize_code(t TEXT)
RETURNS TEXT AS $$
BEGIN
    IF t IS NULL THEN
        RETURN NULL;
    END IF;
    RETURN UPPER(REGEXP_REPLACE(TRIM(t), '\s+', '', 'g'));
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- 2. FUNCTIONAL UNIQUE CONSTRAINTS / INDEXES
-- ----------------------------------------------------------------------------
-- Ensures 'TEA', 'Tea', and '  tea  ' collide and cannot create duplicates.
CREATE UNIQUE INDEX IF NOT EXISTS uq_category_locations_norm 
ON category_locations (normalize_business_text(category));

CREATE UNIQUE INDEX IF NOT EXISTS uq_vendors_norm_name 
ON vendors (normalize_business_text(name));

CREATE UNIQUE INDEX IF NOT EXISTS uq_materials_norm_code 
ON materials (normalize_code(material_code));

-- 3. NORMALIZATION TRIGGERS BEFORE INSERT OR UPDATE
-- ----------------------------------------------------------------------------

-- Materials Table Normalization
CREATE OR REPLACE FUNCTION trg_materials_normalize()
RETURNS TRIGGER AS $$
BEGIN
    NEW.material_code := normalize_code(NEW.material_code);
    NEW.description := normalize_business_text(NEW.description);
    NEW.category := normalize_business_text(NEW.category);
    NEW.unit := normalize_business_text(NEW.unit);
    IF NEW.grade IS NOT NULL THEN
        NEW.grade := normalize_business_text(NEW.grade);
    END IF;
    IF NEW.hsn_sac IS NOT NULL THEN
        NEW.hsn_sac := normalize_business_text(NEW.hsn_sac);
    END IF;
    IF NEW.lot_no IS NOT NULL THEN
        NEW.lot_no := normalize_business_text(NEW.lot_no);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_materials ON materials;
CREATE TRIGGER trg_normalize_materials
BEFORE INSERT OR UPDATE ON materials
FOR EACH ROW EXECUTE FUNCTION trg_materials_normalize();

-- Category Locations Table Normalization
CREATE OR REPLACE FUNCTION trg_category_locations_normalize()
RETURNS TRIGGER AS $$
BEGIN
    NEW.category := normalize_business_text(NEW.category);
    IF NEW.location IS NOT NULL THEN
        NEW.location := normalize_business_text(NEW.location);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_category_locations ON category_locations;
CREATE TRIGGER trg_normalize_category_locations
BEFORE INSERT OR UPDATE ON category_locations
FOR EACH ROW EXECUTE FUNCTION trg_category_locations_normalize();

-- Vendors Table Normalization
CREATE OR REPLACE FUNCTION trg_vendors_normalize()
RETURNS TRIGGER AS $$
BEGIN
    NEW.name := normalize_business_text(NEW.name);
    IF NEW.place IS NOT NULL THEN
        NEW.place := normalize_business_text(NEW.place);
    END IF;
    IF NEW.gstin IS NOT NULL THEN
        NEW.gstin := normalize_code(NEW.gstin);
    END IF;
    IF NEW.material IS NOT NULL THEN
        NEW.material := normalize_business_text(NEW.material);
    END IF;
    IF NEW.info IS NOT NULL THEN
        NEW.info := normalize_business_text(NEW.info);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_vendors ON vendors;
CREATE TRIGGER trg_normalize_vendors
BEFORE INSERT OR UPDATE ON vendors
FOR EACH ROW EXECUTE FUNCTION trg_vendors_normalize();

-- Invoices Table Normalization
CREATE OR REPLACE FUNCTION trg_invoices_normalize()
RETURNS TRIGGER AS $$
BEGIN
    NEW.invoice_no := normalize_business_text(NEW.invoice_no);
    IF NEW.vendor IS NOT NULL THEN
        NEW.vendor := normalize_business_text(NEW.vendor);
    END IF;
    IF NEW.purchase_id IS NOT NULL THEN
        NEW.purchase_id := normalize_business_text(NEW.purchase_id);
    END IF;
    IF NEW.remarks IS NOT NULL THEN
        NEW.remarks := normalize_business_text(NEW.remarks);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_invoices ON invoices;
CREATE TRIGGER trg_normalize_invoices
BEFORE INSERT OR UPDATE ON invoices
FOR EACH ROW EXECUTE FUNCTION trg_invoices_normalize();

-- Invoice Items Table Normalization
CREATE OR REPLACE FUNCTION trg_invoice_items_normalize()
RETURNS TRIGGER AS $$
BEGIN
    NEW.material := normalize_code(NEW.material);
    NEW.unit := normalize_business_text(NEW.unit);
    IF NEW.lot_no IS NOT NULL THEN
        NEW.lot_no := normalize_business_text(NEW.lot_no);
    END IF;
    IF NEW.hsn_sac IS NOT NULL THEN
        NEW.hsn_sac := normalize_business_text(NEW.hsn_sac);
    END IF;
    IF NEW.grade IS NOT NULL THEN
        NEW.grade := normalize_business_text(NEW.grade);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_invoice_items ON invoice_items;
CREATE TRIGGER trg_normalize_invoice_items
BEFORE INSERT OR UPDATE ON invoice_items
FOR EACH ROW EXECUTE FUNCTION trg_invoice_items_normalize();

-- Transfers Table Normalization
CREATE OR REPLACE FUNCTION trg_transfers_normalize()
RETURNS TRIGGER AS $$
BEGIN
    NEW.code := normalize_code(NEW.code);
    IF NEW.lot_no IS NOT NULL THEN
        NEW.lot_no := normalize_business_text(NEW.lot_no);
    END IF;
    IF NEW.department IS NOT NULL THEN
        NEW.department := normalize_business_text(NEW.department);
    END IF;
    IF NEW.person IS NOT NULL THEN
        NEW.person := normalize_business_text(NEW.person);
    END IF;
    IF NEW.units IS NOT NULL THEN
        NEW.units := normalize_business_text(NEW.units);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_transfers ON transfers;
CREATE TRIGGER trg_normalize_transfers
BEFORE INSERT OR UPDATE ON transfers
FOR EACH ROW EXECUTE FUNCTION trg_transfers_normalize();

-- Dispatches Table Normalization
CREATE OR REPLACE FUNCTION trg_dispatches_normalize()
RETURNS TRIGGER AS $$
BEGIN
    NEW.material_code := normalize_code(NEW.material_code);
    IF NEW.product IS NOT NULL THEN
        NEW.product := normalize_business_text(NEW.product);
    END IF;
    IF NEW.units IS NOT NULL THEN
        NEW.units := normalize_business_text(NEW.units);
    END IF;
    IF NEW.location IS NOT NULL THEN
        NEW.location := normalize_business_text(NEW.location);
    END IF;
    IF NEW.department IS NOT NULL THEN
        NEW.department := normalize_business_text(NEW.department);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_dispatches ON dispatches;
CREATE TRIGGER trg_normalize_dispatches
BEFORE INSERT OR UPDATE ON dispatches
FOR EACH ROW EXECUTE FUNCTION trg_dispatches_normalize();

-- Stock Adjustments Table Normalization
CREATE OR REPLACE FUNCTION trg_stock_adjustments_normalize()
RETURNS TRIGGER AS $$
BEGIN
    NEW.material_code := normalize_code(NEW.material_code);
    IF NEW.reason IS NOT NULL THEN
        NEW.reason := normalize_business_text(NEW.reason);
    END IF;
    IF NEW.adjusted_by IS NOT NULL THEN
        NEW.adjusted_by := normalize_business_text(NEW.adjusted_by);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_normalize_stock_adjustments ON stock_adjustments;
CREATE TRIGGER trg_normalize_stock_adjustments
BEFORE INSERT OR UPDATE ON stock_adjustments
FOR EACH ROW EXECUTE FUNCTION trg_stock_adjustments_normalize();
