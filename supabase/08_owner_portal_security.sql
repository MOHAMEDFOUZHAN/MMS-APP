-- ============================================================================
-- BENCHMARK MMS — OWNER / EXECUTIVE PORTAL SECURITY & RPCs
-- Migration: 08_owner_portal_security.sql
-- ============================================================================

-- 1. Ensure user_profiles allows 'OWNER' role
ALTER TABLE user_profiles DROP CONSTRAINT IF EXISTS user_profiles_role_check;
ALTER TABLE user_profiles ADD CONSTRAINT user_profiles_role_check 
    CHECK (role IN ('OWNER', 'ADMIN', 'MANAGER', 'STAFF', 'VIEWER'));

-- 2. Update owner@benchmarkmms.com profile to OWNER role with comprehensive owner permissions
UPDATE user_profiles
SET 
    role = 'OWNER',
    permissions = ARRAY[
        'owner.*',
        'materials.*',
        'invoice.*',
        'transfer.*',
        'dispatch.*',
        'stock_adjustment.*',
        'reports.*',
        'users.manage',
        'settings.manage'
    ],
    updated_at = NOW()
WHERE username = 'owner' 
   OR id IN (SELECT id FROM auth.users WHERE email = 'owner@benchmarkmms.com');

-- Also ensure user_profiles has an entry for owner if not present
INSERT INTO user_profiles (id, username, full_name, role, permissions)
SELECT 
    id,
    'owner',
    'System Owner',
    'OWNER',
    ARRAY[
        'owner.*',
        'materials.*',
        'invoice.*',
        'transfer.*',
        'dispatch.*',
        'stock_adjustment.*',
        'reports.*',
        'users.manage',
        'settings.manage'
    ]
FROM auth.users
WHERE email = 'owner@benchmarkmms.com'
ON CONFLICT (id) DO UPDATE SET
    role = 'OWNER',
    permissions = ARRAY[
        'owner.*',
        'materials.*',
        'invoice.*',
        'transfer.*',
        'dispatch.*',
        'stock_adjustment.*',
        'reports.*',
        'users.manage',
        'settings.manage'
    ],
    updated_at = NOW();

-- 3. Security Definer Function: is_owner()
CREATE OR REPLACE FUNCTION is_owner()
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_role TEXT;
    v_perms TEXT[];
BEGIN
    IF auth.uid() IS NULL THEN
        RETURN FALSE;
    END IF;

    SELECT role, permissions INTO v_role, v_perms
    FROM user_profiles
    WHERE id = auth.uid();

    IF v_role IS NULL THEN
        -- Fallback check for owner email
        IF EXISTS (SELECT 1 FROM auth.users WHERE id = auth.uid() AND email = 'owner@benchmarkmms.com') THEN
            RETURN TRUE;
        END IF;
        RETURN FALSE;
    END IF;

    RETURN UPPER(v_role) = 'OWNER' OR ('owner.*' = ANY(v_perms));
END;
$$;

-- 4. Security Verification Function: verify_owner_access()
CREATE OR REPLACE FUNCTION verify_owner_access()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_uid UUID;
    v_role TEXT;
    v_perms TEXT[];
    v_username TEXT;
    v_fullname TEXT;
    v_email TEXT;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'Not authenticated' USING ERRCODE = '42501';
    END IF;

    SELECT email INTO v_email FROM auth.users WHERE id = v_uid;

    SELECT role, permissions, username, full_name 
    INTO v_role, v_perms, v_username, v_fullname
    FROM user_profiles
    WHERE id = v_uid;

    IF v_role IS NULL THEN
        IF v_email = 'owner@benchmarkmms.com' THEN
            v_role := 'OWNER';
            v_username := 'owner';
            v_fullname := 'System Owner';
        ELSE
            RAISE EXCEPTION 'Access Denied: User profile not found' USING ERRCODE = '42501';
        END IF;
    END IF;

    IF UPPER(v_role) != 'OWNER' AND NOT ('owner.*' = ANY(v_perms)) THEN
        RAISE EXCEPTION 'Access Denied: Owner executive role required' USING ERRCODE = '42501';
    END IF;

    RETURN jsonb_build_object(
        'authorized', true,
        'user_id', v_uid,
        'email', v_email,
        'role', v_role,
        'username', v_username,
        'full_name', v_fullname
    );
END;
$$;

-- 5. Comprehensive Authoritative Owner Dashboard Aggregation RPC
CREATE OR REPLACE FUNCTION get_owner_dashboard_summary(
    p_from_date DATE DEFAULT NULL,
    p_to_date DATE DEFAULT NULL,
    p_invoice_expiry_days INT DEFAULT 30,
    p_storage_expiry_days INT DEFAULT 30
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    v_auth jsonb;
    v_today DATE := CURRENT_DATE;
    v_today_str TEXT := v_today::text;
    
    -- KPIs
    v_total_materials INT := 0;
    v_active_storage_products INT := 0;
    v_total_storage_stock NUMERIC := 0.0;
    v_total_purchases_val NUMERIC := 0.0;
    v_total_purchases_cnt INT := 0;
    v_total_dispatched_qty NUMERIC := 0.0;
    v_total_dispatched_cnt INT := 0;
    v_total_transferred_out NUMERIC := 0.0;
    v_total_transferred_ret NUMERIC := 0.0;
    v_total_transferred_net NUMERIC := 0.0;
    v_out_of_stock_cnt INT := 0;
    v_low_stock_cnt INT := 0;
    v_expiring_soon_cnt INT := 0;
    v_expired_cnt INT := 0;
    v_pending_invoices_cnt INT := 0;
    v_pending_invoices_val NUMERIC := 0.0;
    v_total_vendors_cnt INT := 0;
    v_active_batches_cnt INT := 0;
    v_depleted_batches_cnt INT := 0;
    v_total_materials_stock NUMERIC := 0.0;

    -- Today's snapshot
    v_today_purchases_val NUMERIC := 0.0;
    v_today_purchases_cnt INT := 0;
    v_today_stock_in_qty NUMERIC := 0.0;
    v_today_new_batches_cnt INT := 0;
    v_today_dispatch_qty NUMERIC := 0.0;
    v_today_dispatch_cnt INT := 0;
    v_today_transfer_out NUMERIC := 0.0;
    v_today_transfer_ret NUMERIC := 0.0;
    v_today_invoices_cnt INT := 0;

    -- Weekly & Monthly Invoices
    v_week_invoices_cnt INT := 0;
    v_week_invoices_val NUMERIC := 0.0;
    v_month_invoices_cnt INT := 0;
    v_month_invoices_val NUMERIC := 0.0;

    -- Weekly & Monthly Dispatches
    v_week_dispatch_qty NUMERIC := 0.0;
    v_week_dispatch_cnt INT := 0;
    v_month_dispatch_qty NUMERIC := 0.0;
    v_month_dispatch_cnt INT := 0;
    v_total_dispatch_returns NUMERIC := 0.0;

    -- JSON containers
    v_top_consumed_materials jsonb;
    v_highest_stock_materials jsonb;
    v_top_dispatched_products jsonb;
    v_top_storage_products jsonb;
    v_lowest_storage_products jsonb;
    v_expiring_storage_products jsonb;
    v_top_purchased_materials jsonb;
    v_top_reorder_risk jsonb;
    v_recent_vendors jsonb;
    v_recent_purchases jsonb;
    v_recent_dispatches jsonb;
    v_top_departments_dispatch jsonb;
    v_top_departments_transfer jsonb;
    v_most_transferred_materials jsonb;
    v_recent_activity jsonb;
    v_system_alerts jsonb;
    v_category_breakdown jsonb;
    v_storage_category_breakdown jsonb;
    v_purchase_trend jsonb;
    v_dispatch_trend jsonb;
    v_transfer_trend jsonb;
    v_material_expiry_monitor jsonb;
    v_storage_expiry_monitor jsonb;
BEGIN
    -- 1. Enforce strict server-side owner role verification
    v_auth := verify_owner_access();

    -- Effective expiry thresholds
    IF p_invoice_expiry_days <= 0 THEN p_invoice_expiry_days := 30; END IF;
    IF p_storage_expiry_days <= 0 THEN p_storage_expiry_days := 30; END IF;

    -- 2. MATERIALS METRICS
    SELECT 
        COUNT(DISTINCT material_code),
        COALESCE(SUM(quantity), 0.0),
        COUNT(*) FILTER (WHERE quantity <= 0.0001 OR quantity IS NULL),
        COUNT(*) FILTER (WHERE quantity > 0.0001 AND quantity <= reorder_level),
        COUNT(*) FILTER (WHERE expiry_date IS NOT NULL AND expiry_date >= v_today AND expiry_date <= v_today + (p_invoice_expiry_days || ' days')::INTERVAL),
        COUNT(*) FILTER (WHERE expiry_date IS NOT NULL AND expiry_date < v_today)
    INTO 
        v_total_materials,
        v_total_materials_stock,
        v_out_of_stock_cnt,
        v_low_stock_cnt,
        v_expiring_soon_cnt,
        v_expired_cnt
    FROM materials;

    -- 3. STORAGE & BATCHES METRICS
    SELECT 
        COUNT(*) FILTER (WHERE available_quantity > 0.0001),
        COUNT(*) FILTER (WHERE available_quantity <= 0.0001),
        COALESCE(SUM(available_quantity) FILTER (WHERE available_quantity > 0.0001), 0.0)
    INTO 
        v_active_batches_cnt,
        v_depleted_batches_cnt,
        v_total_storage_stock
    FROM batches;

    SELECT COUNT(*) INTO v_active_storage_products FROM storage_products;

    -- 4. INVOICES & PURCHASES METRICS
    SELECT 
        COUNT(*),
        COALESCE(SUM(final_total), 0.0),
        COUNT(*) FILTER (WHERE payment_status = 'Pending'),
        COALESCE(SUM(final_total) FILTER (WHERE payment_status = 'Pending'), 0.0),
        COUNT(*) FILTER (WHERE date = v_today),
        COALESCE(SUM(final_total) FILTER (WHERE date = v_today), 0.0),
        COUNT(*) FILTER (WHERE date >= v_today - INTERVAL '7 days'),
        COALESCE(SUM(final_total) FILTER (WHERE date >= v_today - INTERVAL '7 days'), 0.0),
        COUNT(*) FILTER (WHERE date >= date_trunc('month', v_today)),
        COALESCE(SUM(final_total) FILTER (WHERE date >= date_trunc('month', v_today)), 0.0)
    INTO 
        v_total_purchases_cnt,
        v_total_purchases_val,
        v_pending_invoices_cnt,
        v_pending_invoices_val,
        v_today_invoices_cnt,
        v_today_purchases_val,
        v_week_invoices_cnt,
        v_week_invoices_val,
        v_month_invoices_cnt,
        v_month_invoices_val
    FROM invoices;

    -- 5. DISPATCH METRICS
    SELECT 
        COUNT(*),
        COALESCE(SUM(quantity), 0.0),
        COUNT(*) FILTER (WHERE date = v_today),
        COALESCE(SUM(quantity) FILTER (WHERE date = v_today), 0.0),
        COUNT(*) FILTER (WHERE date >= v_today - INTERVAL '7 days'),
        COALESCE(SUM(quantity) FILTER (WHERE date >= v_today - INTERVAL '7 days'), 0.0),
        COUNT(*) FILTER (WHERE date >= date_trunc('month', v_today)),
        COALESCE(SUM(quantity) FILTER (WHERE date >= date_trunc('month', v_today)), 0.0)
    INTO 
        v_total_dispatched_cnt,
        v_total_dispatched_qty,
        v_today_dispatch_cnt,
        v_today_dispatch_qty,
        v_week_dispatch_cnt,
        v_week_dispatch_qty,
        v_month_dispatch_cnt,
        v_month_dispatch_qty
    FROM dispatches;

    SELECT COALESCE(SUM(returned_quantity), 0.0)
    INTO v_total_dispatch_returns
    FROM dispatch_batches;

    -- 6. TRANSFERS METRICS
    SELECT 
        COALESCE(SUM(outward), 0.0),
        COALESCE(SUM(return_units), 0.0),
        COALESCE(SUM(outward - return_units), 0.0),
        COALESCE(SUM(outward) FILTER (WHERE date = v_today), 0.0),
        COALESCE(SUM(return_units) FILTER (WHERE date = v_today), 0.0)
    INTO 
        v_total_transferred_out,
        v_total_transferred_ret,
        v_total_transferred_net,
        v_today_transfer_out,
        v_today_transfer_ret
    FROM transfers;

    -- Today's Storage Inward
    SELECT 
        COALESCE(SUM(received_quantity), 0.0),
        COUNT(*)
    INTO 
        v_today_stock_in_qty,
        v_today_new_batches_cnt
    FROM batches
    WHERE batch_date = v_today OR received_date = v_today OR created_at::date = v_today;

    -- Total Vendors
    SELECT COUNT(*) INTO v_total_vendors_cnt FROM vendors;

    -- 7. TOP LISTS
    -- Top 5 Highest Stock Materials
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_highest_stock_materials
    FROM (
        SELECT material_code, description, category, unit, quantity
        FROM materials
        WHERE quantity > 0
        ORDER BY quantity DESC
        LIMIT 5
    ) sub;

    -- Top 5 Reorder Risk Materials
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_top_reorder_risk
    FROM (
        SELECT material_code, description, category, unit, quantity, reorder_level,
               (reorder_level - quantity) AS deficit
        FROM materials
        WHERE quantity <= reorder_level AND quantity > 0
        ORDER BY (reorder_level - quantity) DESC, quantity ASC
        LIMIT 5
    ) sub;

    -- Top 5 Storage Products by Available Quantity
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_top_storage_products
    FROM (
        SELECT material_code, description, uom, SUM(available_quantity) as total_available, COUNT(*) as batch_count
        FROM batches
        WHERE available_quantity > 0.0001
        GROUP BY material_code, description, uom
        ORDER BY total_available DESC
        LIMIT 5
    ) sub;

    -- Lowest Stock Storage Products (available > 0)
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_lowest_storage_products
    FROM (
        SELECT material_code, description, uom, SUM(available_quantity) as total_available, COUNT(*) as batch_count
        FROM batches
        WHERE available_quantity > 0.0001
        GROUP BY material_code, description, uom
        ORDER BY total_available ASC
        LIMIT 5
    ) sub;

    -- Expiring Storage Batches
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_expiring_storage_products
    FROM (
        SELECT batch_no, material_code, description, available_quantity, uom, expiry_date,
               (expiry_date - v_today) as days_remaining
        FROM batches
        WHERE expiry_date IS NOT NULL 
          AND available_quantity > 0.0001
          AND expiry_date <= v_today + (p_storage_expiry_days || ' days')::INTERVAL
        ORDER BY expiry_date ASC
        LIMIT 10
    ) sub;

    -- Top Dispatched Products
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_top_dispatched_products
    FROM (
        SELECT product, material_code, units, SUM(quantity) as total_dispatched, COUNT(*) as dispatch_count
        FROM dispatches
        GROUP BY product, material_code, units
        ORDER BY total_dispatched DESC
        LIMIT 5
    ) sub;

    -- Top Dispatched Departments
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_top_departments_dispatch
    FROM (
        SELECT department, COUNT(*) as dispatch_count, SUM(quantity) as total_quantity
        FROM dispatches
        WHERE department IS NOT NULL AND department <> ''
        GROUP BY department
        ORDER BY total_quantity DESC
        LIMIT 5
    ) sub;

    -- Top Transfer Departments
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_top_departments_transfer
    FROM (
        SELECT department, SUM(outward) as outward, SUM(return_units) as returns, SUM(outward - return_units) as net_consumed
        FROM transfers
        WHERE department IS NOT NULL AND department <> ''
        GROUP BY department
        ORDER BY net_consumed DESC
        LIMIT 5
    ) sub;

    -- Most Transferred Materials
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_most_transferred_materials
    FROM (
        SELECT code, description, units, SUM(outward) as total_outward, SUM(return_units) as total_returns, SUM(outward - return_units) as net_change
        FROM transfers
        GROUP BY code, description, units
        ORDER BY total_outward DESC
        LIMIT 5
    ) sub;

    -- Recent Invoices
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_recent_purchases
    FROM (
        SELECT id, invoice_no, vendor, date, final_total, payment_status
        FROM invoices
        ORDER BY date DESC, id DESC
        LIMIT 5
    ) sub;

    -- Recent Vendors
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_recent_vendors
    FROM (
        SELECT id, name, contact, place, material
        FROM vendors
        ORDER BY id DESC
        LIMIT 5
    ) sub;

    -- Recent Dispatches
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_recent_dispatches
    FROM (
        SELECT id, date, material_code, product, quantity, units, department, location
        FROM dispatches
        ORDER BY date DESC, id DESC
        LIMIT 5
    ) sub;

    -- Category Stock Distribution (Materials)
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_category_breakdown
    FROM (
        SELECT COALESCE(NULLIF(category, ''), 'General') as category,
               SUM(quantity) as total_quantity,
               COUNT(*) as item_count
        FROM materials
        GROUP BY COALESCE(NULLIF(category, ''), 'General')
        ORDER BY total_quantity DESC
    ) sub;

    -- Storage Category / Dept Distribution
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_storage_category_breakdown
    FROM (
        SELECT COALESCE(NULLIF(department, ''), 'Finished Goods') as department,
               SUM(available_quantity) as total_quantity,
               COUNT(*) as batch_count
        FROM batches
        WHERE available_quantity > 0.0001
        GROUP BY COALESCE(NULLIF(department, ''), 'Finished Goods')
        ORDER BY total_quantity DESC
    ) sub;

    -- Purchase Trend (Last 7 Days)
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_purchase_trend
    FROM (
        SELECT date::text as date_str, COUNT(*) as count, SUM(final_total) as value
        FROM invoices
        WHERE date >= v_today - INTERVAL '30 days'
        GROUP BY date
        ORDER BY date ASC
    ) sub;

    -- Dispatch Trend (Last 30 Days)
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_dispatch_trend
    FROM (
        SELECT date::text as date_str, COUNT(*) as count, SUM(quantity) as quantity
        FROM dispatches
        WHERE date >= v_today - INTERVAL '30 days'
        GROUP BY date
        ORDER BY date ASC
    ) sub;

    -- Transfer Trend (Last 30 Days)
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_transfer_trend
    FROM (
        SELECT date::text as date_str, SUM(outward) as outward, SUM(return_units) as returns, SUM(outward - return_units) as net
        FROM transfers
        WHERE date >= v_today - INTERVAL '30 days'
        GROUP BY date
        ORDER BY date ASC
    ) sub;

    -- Expiry Monitor Breakdowns
    -- Materials Expiry
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_material_expiry_monitor
    FROM (
        SELECT 
            material_code, description, category, quantity, unit, expiry_date,
            (expiry_date - v_today) as days_remaining,
            CASE 
                WHEN expiry_date < v_today THEN 'EXPIRED'
                WHEN expiry_date = v_today THEN 'TODAY'
                WHEN expiry_date <= v_today + INTERVAL '7 days' THEN 'NEXT_7_DAYS'
                ELSE 'EXPIRING_SOON'
            END as expiry_stage
        FROM materials
        WHERE expiry_date IS NOT NULL 
          AND expiry_date <= v_today + (p_invoice_expiry_days || ' days')::INTERVAL
        ORDER BY expiry_date ASC
        LIMIT 15
    ) sub;

    -- Storage Products Expiry
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_storage_expiry_monitor
    FROM (
        SELECT 
            batch_no, material_code, description, available_quantity, uom, expiry_date,
            (expiry_date - v_today) as days_remaining,
            CASE 
                WHEN expiry_date < v_today THEN 'EXPIRED'
                WHEN expiry_date = v_today THEN 'TODAY'
                WHEN expiry_date <= v_today + INTERVAL '7 days' THEN 'NEXT_7_DAYS'
                ELSE 'EXPIRING_SOON'
            END as expiry_stage
        FROM batches
        WHERE expiry_date IS NOT NULL 
          AND available_quantity > 0.0001
          AND expiry_date <= v_today + (p_storage_expiry_days || ' days')::INTERVAL
        ORDER BY expiry_date ASC
        LIMIT 15
    ) sub;

    -- Real-time Audit Activity (Last 15 operations with 12-hour AM/PM time)
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_recent_activity
    FROM (
        SELECT 
            id,
            COALESCE(user_email, 'System') as user_email,
            operation,
            module,
            record_id,
            details,
            created_at,
            to_char(created_at AT TIME ZONE 'Asia/Kolkata', 'HH12:MI AM') as time_ampm,
            to_char(created_at, 'YYYY-MM-DD') as date_str
        FROM audit_logs
        ORDER BY created_at DESC
        LIMIT 15
    ) sub;

    -- High-Level Executive Alerts
    SELECT COALESCE(jsonb_agg(sub), '[]'::jsonb)
    INTO v_system_alerts
    FROM (
        (
            SELECT 'CRITICAL' as severity, 'Expired Raw Material' as title, 
                   description || ' (' || material_code || ') has expired on ' || expiry_date::text as message,
                   'material' as reference_type, material_code as reference_id, expiry_date::timestamptz as alert_time
            FROM materials
            WHERE expiry_date IS NOT NULL AND expiry_date < v_today AND quantity > 0
            LIMIT 3
        )
        UNION ALL
        (
            SELECT 'CRITICAL' as severity, 'Expired Storage Batch' as title,
                   'Batch ' || batch_no || ' (' || description || ') expired on ' || expiry_date::text as message,
                   'batch' as reference_type, batch_no as reference_id, expiry_date::timestamptz as alert_time
            FROM batches
            WHERE expiry_date IS NOT NULL AND expiry_date < v_today AND available_quantity > 0
            LIMIT 3
        )
        UNION ALL
        (
            SELECT 'WARNING' as severity, 'Material Below Reorder Level' as title,
                   description || ' (' || material_code || ') is at ' || quantity || ' ' || unit || ' (Reorder: ' || reorder_level || ')' as message,
                   'material' as reference_type, material_code as reference_id, NOW() as alert_time
            FROM materials
            WHERE quantity <= reorder_level AND quantity > 0
            LIMIT 3
        )
        UNION ALL
        (
            SELECT 'WARNING' as severity, 'Storage Batch Expiring Soon' as title,
                   'Batch ' || batch_no || ' (' || description || ') expires in ' || (expiry_date - v_today) || ' days' as message,
                   'batch' as reference_type, batch_no as reference_id, NOW() as alert_time
            FROM batches
            WHERE expiry_date IS NOT NULL 
              AND available_quantity > 0 
              AND expiry_date >= v_today 
              AND expiry_date <= v_today + (p_storage_expiry_days || ' days')::INTERVAL
            LIMIT 3
        )
        UNION ALL
        (
            SELECT 'INFO' as severity, 'Today Dispatch Summary' as title,
                   v_today_dispatch_cnt || ' dispatches recorded today (' || v_today_dispatch_qty || ' units)' as message,
                   'dispatch' as reference_type, 'today' as reference_id, NOW() as alert_time
            WHERE v_today_dispatch_cnt > 0
        )
        UNION ALL
        (
            SELECT 'INFO' as severity, 'Today Inward Purchases' as title,
                   v_today_invoices_cnt || ' invoices received today (₹' || ROUND(v_today_purchases_val, 2) || ')' as message,
                   'invoice' as reference_type, 'today' as reference_id, NOW() as alert_time
            WHERE v_today_invoices_cnt > 0
        )
    ) sub;

    -- Return Consolidated Master JSON
    RETURN jsonb_build_object(
        'timestamp', NOW(),
        'kpi', jsonb_build_object(
            'total_materials', v_total_materials,
            'active_storage_products', v_active_storage_products,
            'total_storage_stock', v_total_storage_stock,
            'total_purchases_val', v_total_purchases_val,
            'total_purchases_cnt', v_total_purchases_cnt,
            'total_dispatched_qty', v_total_dispatched_qty,
            'total_dispatched_cnt', v_total_dispatched_cnt,
            'total_transferred_out', v_total_transferred_out,
            'total_transferred_ret', v_total_transferred_ret,
            'total_transferred_net', v_total_transferred_net,
            'out_of_stock_cnt', v_out_of_stock_cnt,
            'low_stock_cnt', v_low_stock_cnt,
            'expiring_soon_cnt', v_expiring_soon_cnt,
            'expired_cnt', v_expired_cnt,
            'pending_invoices_cnt', v_pending_invoices_cnt,
            'pending_invoices_val', v_pending_invoices_val,
            'total_vendors_cnt', v_total_vendors_cnt,
            'active_batches_cnt', v_active_batches_cnt,
            'depleted_batches_cnt', v_depleted_batches_cnt,
            'total_materials_stock', v_total_materials_stock
        ),
        'today', jsonb_build_object(
            'today_purchases_val', v_today_purchases_val,
            'today_purchases_cnt', v_today_purchases_cnt,
            'today_stock_in_qty', v_today_stock_in_qty,
            'today_new_batches_cnt', v_today_new_batches_cnt,
            'today_dispatch_qty', v_today_dispatch_qty,
            'today_dispatch_cnt', v_today_dispatch_cnt,
            'today_transfer_out', v_today_transfer_out,
            'today_transfer_ret', v_today_transfer_ret,
            'today_closing_stock', (v_total_storage_stock + v_total_materials_stock),
            'today_invoices_cnt', v_today_invoices_cnt
        ),
        'health', jsonb_build_object(
            'healthy_stock', (v_total_materials - v_low_stock_cnt - v_out_of_stock_cnt),
            'low_stock', v_low_stock_cnt,
            'out_of_stock', v_out_of_stock_cnt,
            'expiring_soon', v_expiring_soon_cnt,
            'expired', v_expired_cnt,
            'active_batches', v_active_batches_cnt,
            'depleted_batches', v_depleted_batches_cnt
        ),
        'storage', jsonb_build_object(
            'total_storage_stock', v_total_storage_stock,
            'active_batches', v_active_batches_cnt,
            'depleted_batches', v_depleted_batches_cnt,
            'today_stock_in', v_today_stock_in_qty,
            'today_dispatch', v_today_dispatch_qty,
            'top_products', v_top_storage_products,
            'lowest_products', v_lowest_storage_products,
            'expiring_batches', v_expiring_storage_products,
            'distribution', v_storage_category_breakdown
        ),
        'materials', jsonb_build_object(
            'total_materials', v_total_materials,
            'total_quantity', v_total_materials_stock,
            'low_stock', v_low_stock_cnt,
            'out_of_stock', v_out_of_stock_cnt,
            'today_purchases', v_today_purchases_val,
            'today_transfer_out', v_today_transfer_out,
            'today_returns', v_today_transfer_ret,
            'highest_stock', v_highest_stock_materials,
            'distribution', v_category_breakdown
        ),
        'invoices', jsonb_build_object(
            'today_invoices_cnt', v_today_invoices_cnt,
            'today_invoices_val', v_today_purchases_val,
            'week_invoices_cnt', v_week_invoices_cnt,
            'week_invoices_val', v_week_invoices_val,
            'month_invoices_cnt', v_month_invoices_cnt,
            'month_invoices_val', v_month_invoices_val,
            'total_purchase_val', v_total_purchases_val,
            'pending_invoices_cnt', v_pending_invoices_cnt,
            'pending_invoices_val', v_pending_invoices_val,
            'recent_vendors', v_recent_vendors,
            'recent_purchases', v_recent_purchases,
            'purchase_trend', v_purchase_trend
        ),
        'dispatches', jsonb_build_object(
            'today_dispatch_cnt', v_today_dispatch_cnt,
            'today_dispatch_qty', v_today_dispatch_qty,
            'week_dispatch_cnt', v_week_dispatch_cnt,
            'week_dispatch_qty', v_week_dispatch_qty,
            'month_dispatch_cnt', v_month_dispatch_cnt,
            'month_dispatch_qty', v_month_dispatch_qty,
            'total_dispatch_qty', v_total_dispatched_qty,
            'top_dispatched_products', v_top_dispatched_products,
            'top_departments', v_top_departments_dispatch,
            'recent_dispatches', v_recent_dispatches,
            'returns', v_total_dispatch_returns,
            'dispatch_trend', v_dispatch_trend
        ),
        'transfers', jsonb_build_object(
            'today_transfers_out', v_today_transfer_out,
            'today_transfers_ret', v_today_transfer_ret,
            'total_transfers_out', v_total_transferred_out,
            'total_transfers_ret', v_total_transferred_ret,
            'net_consumed', v_total_transferred_net,
            'top_departments', v_top_departments_transfer,
            'most_transferred_materials', v_most_transferred_materials,
            'transfer_trend', v_transfer_trend
        ),
        'top_lists', jsonb_build_object(
            'reorder_risk', v_top_reorder_risk,
            'highest_storage', v_top_storage_products,
            'highest_materials', v_highest_stock_materials,
            'top_dispatched', v_top_dispatched_products
        ),
        'expiry_monitor', jsonb_build_object(
            'invoice_materials', v_material_expiry_monitor,
            'storage_products', v_storage_expiry_monitor,
            'invoice_threshold_days', p_invoice_expiry_days,
            'storage_threshold_days', p_storage_expiry_days
        ),
        'recent_activity', v_recent_activity,
        'alerts', v_system_alerts
    );
END;
$$;
