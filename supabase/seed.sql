-- ============================================================================
-- BENCHMARK MMS — SEED DATA
-- Default Categories, Shelf Locations, Vendors & Factory Configuration
-- ============================================================================

-- 1. Default Shelf Locations
INSERT INTO category_locations (category, location) VALUES
('Tea Packaging', 'Shelf A-1 (Ground Floor)'),
('Chocolate Raw Materials', 'Rack B-3 (Climate Controlled)'),
('Essential Oils', 'Bin C-2 (Ventilated Rack)'),
('Kitchen Spices', 'Shelf D-1 (Dry Storage)'),
('Cleaning Supplies', 'Rack E-4 (Utility Bay)'),
('General Consumables', 'Shelf F-1 (Front Store)')
ON CONFLICT (category) DO UPDATE SET location = EXCLUDED.location;

-- 2. Default Vendors
INSERT INTO vendors (name, contact, place, pincode, gstin, material, info) VALUES
('Jai Agencies', '+91 98421 54321', 'Coimbatore', '641001', '33AAAAA0000A1Z5', 'Tea Filter Paper, Boxes', 'Primary supplier for tea packaging materials'),
('Nilgiri Agro Supplies', '+91 94432 12345', 'Ooty', '643001', '33BBBBB1111B2Z6', 'Cocoa Butter, Vanilla Extract', 'Chocolate ingredient supplier'),
('Southern Essence Corp', '+91 97890 67890', 'Cochin', '682001', '32CCCCC2222C3Z7', 'Eucalyptus Oil, Citronella', 'Distillation raw oils')
ON CONFLICT DO NOTHING;

-- 3. Default System Settings
INSERT INTO system_settings (key, value) VALUES
('security', '{"stock_adjustment_pin": "1234", "new_material_pin": "1234", "admin_pin": "9999"}'::JSONB),
('factory_info', '{"name": "Benchmark MMS Factory", "address": "Ooty Road, Nilgiris, Tamil Nadu", "departments": ["Tea", "Chocolate", "Kitchen", "General", "Packaging"]}'::JSONB),
('mailer_config', '{"auto_mailer_enabled": true, "recipient_emails": ["manager@benchmarktea.com"], "send_time": "18:00"}'::JSONB)
ON CONFLICT (key) DO UPDATE SET value = EXCLUDED.value;
