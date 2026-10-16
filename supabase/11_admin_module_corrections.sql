-- ============================================================================
-- BENCHMARK MMS — Admin Module Corrections
-- Migration 11: Brand field on invoices + update_material_category RPC
-- Run this on the Supabase SQL Editor or via psql before deploying app build.
-- ============================================================================

-- ── 1. Add brand column to the invoices table ─────────────────────────────
-- Safe: nullable TEXT column, no existing records are touched.
ALTER TABLE invoices
  ADD COLUMN IF NOT EXISTS brand TEXT;

CREATE INDEX IF NOT EXISTS idx_invoices_brand ON invoices(brand);

-- ── 2. update_material_category RPC ──────────────────────────────────────
-- Atomically updates the category column on the materials master record
-- identified by material_code. Does NOT touch stock quantities, unit, lot
-- history, or any related transaction tables. Safe for authorized Admin use.
CREATE OR REPLACE FUNCTION update_material_category(
    p_code     TEXT,
    p_new_cat  TEXT
) RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    UPDATE materials
       SET category     = TRIM(p_new_cat),
           last_updated = NOW()
     WHERE material_code = TRIM(p_code);

    RETURN FOUND;
END;
$$;

-- ── Notes ─────────────────────────────────────────────────────────────────
-- • brand is stored per-invoice (header level), consistent with vendor.
-- • Existing invoices that have no brand will read back as NULL / '' — the
--   app model defaults to '' so no UI changes are required for old records.
-- • update_material_category does NOT cascade to invoice_items, batches, or
--   transfers. Category on those tables is set at create-time and preserved
--   as historical context.
