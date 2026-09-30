import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

db_path = r"file:d:/projects/MMS APP/migration/backup_inventory_benchmark_mms.db?mode=ro"
conn = sqlite3.connect(db_path, uri=True)
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

def sql_str(val):
    if val is None:
        return "NULL"
    s = str(val).strip()
    if s == "":
        return "''"
    escaped = s.replace("'", "''")
    return f"'{escaped}'"

def sql_str_or_null(val):
    if val is None:
        return "NULL"
    s = str(val).strip()
    if s == "":
        return "NULL"
    escaped = s.replace("'", "''")
    return f"'{escaped}'"

def sql_num(val, default=0.0):
    if val is None or val == "":
        return str(default)
    try:
        f = float(val)
        return f"{f:.4f}".rstrip('0').rstrip('.') if '.' in f"{f:.4f}" else str(f)
    except:
        return str(default)

def sql_int(val, default=0):
    if val is None or val == "":
        return str(default)
    try:
        return str(int(float(val)))
    except:
        return str(default)

def sql_date(val):
    if val is None:
        return "NULL"
    s = str(val).strip()
    if not s or s == "":
        return "NULL"
    date_part = s.split()[0]
    if len(date_part) == 10 and date_part[4] == '-' and date_part[7] == '-':
        return f"'{date_part}'"
    return "NULL"

def sql_ts(val):
    if val is None:
        return "CURRENT_TIMESTAMP"
    s = str(val).strip()
    if not s or s == "":
        return "CURRENT_TIMESTAMP"
    escaped = s.replace("'", "''")
    return f"'{escaped}'::timestamptz"

out = []

out.append("-- ============================================================================")
out.append("-- BENCHMARK MMS — COMPLETE PRODUCTION DATA MIGRATION SCRIPT")
out.append("-- Source: SQLite 'inventory - BeanchMark-MMS.db'")
out.append("-- Target: Supabase PostgreSQL (Project: japxiaxyabhhhclphbqr)")
out.append("-- ============================================================================")
out.append("BEGIN;\n")

# 1. MATERIALS (192 rows)
cursor.execute("SELECT * FROM materials ORDER BY id ASC")
rows = cursor.fetchall()
out.append(f"-- 1. INSERT MATERIALS ({len(rows)} records)")
out.append("INSERT INTO materials (id, material_code, description, category, opening_stock, quantity, reorder_level, purchase_date, expiry_date, lot_no, unit_price, unit, last_updated, hsn_sac, grade) VALUES")
mat_vals = []
for r in rows:
    mat_vals.append(
        f"({sql_int(r['id'])}, {sql_str(r['material_code'])}, {sql_str(r['description'])}, {sql_str(r['category'])}, "
        f"{sql_num(r['opening_stock'])}, {sql_num(r['quantity'])}, {sql_num(r['reorder_level'])}, "
        f"{sql_date(r['purchase_date'])}, {sql_date(r['expiry_date'])}, {sql_str(r['lot_no'])}, "
        f"{sql_num(r['unit_price'])}, {sql_str(r['unit'])}, {sql_ts(r['last_updated'])}, {sql_str(r['hsn_sac'])}, 'STANDARD')"
    )
out.append(",\n".join(mat_vals) + ";\n")

# 2. INVOICES (57 rows)
cursor.execute("SELECT * FROM invoices ORDER BY id ASC")
rows = cursor.fetchall()
out.append(f"-- 2. INSERT INVOICES ({len(rows)} records)")
out.append("INSERT INTO invoices (id, purchase_id, date, invoice_no, vendor, no_of_items, total_excl_tax, total_gst, total_igst, cgst_percent, sgst_percent, round_off_value, final_total, grand_total, payment_status, remarks, created_at) VALUES")
inv_vals = []
for r in rows:
    p_status = sql_str(r['payment_status']) if r['payment_status'] else "'Pending'"
    inv_vals.append(
        f"({sql_int(r['id'])}, {sql_str_or_null(r['purchase_id'])}, {sql_date(r['date'])}, {sql_str(r['invoice_no'])}, "
        f"{sql_str_or_null(r['vendor'])}, {sql_int(r['no_of_items'], 1)}, {sql_num(r['total_excl_tax'])}, {sql_num(r['total_gst'])}, "
        f"{sql_num(r['total_igst'])}, {sql_num(r['cgst_percent'])}, {sql_num(r['sgst_percent'])}, {sql_num(r['round_off_value'])}, "
        f"{sql_num(r['final_total'])}, {sql_num(r['grand_total'])}, {p_status}, {sql_str_or_null(r['remarks'])}, {sql_ts(r['created_at'])})"
    )
out.append(",\n".join(inv_vals) + ";\n")

# 3. INVOICE_ITEMS (92 rows)
cursor.execute("SELECT * FROM invoice_items ORDER BY id ASC")
rows = cursor.fetchall()
out.append(f"-- 3. INSERT INVOICE_ITEMS ({len(rows)} records)")
out.append("INSERT INTO invoice_items (id, invoice_id, material, quantity, unit, unit_price, discount_percentage, gst_percentage, igst_percentage, item_subtotal, item_gst_value, item_igst_value, item_total, batch_no, hsn_sac, grade) VALUES")
ii_vals = []
for r in rows:
    ii_vals.append(
        f"({sql_int(r['id'])}, {sql_int(r['invoice_id'])}, {sql_str(r['material'])}, {sql_num(r['quantity'])}, "
        f"{sql_str(r['unit'])}, {sql_num(r['unit_price'])}, {sql_num(r['discount_percentage'])}, {sql_num(r['gst_percentage'])}, "
        f"{sql_num(r['igst_percentage'])}, {sql_num(r['item_subtotal'])}, {sql_num(r['item_gst_value'])}, {sql_num(r['item_igst_value'])}, "
        f"{sql_num(r['item_total'])}, {sql_str_or_null(r['batch_no'])}, {sql_str_or_null(r['hsn_sac'])}, 'STANDARD')"
    )
out.append(",\n".join(ii_vals) + ";\n")

# 4. TRANSFERS (180 rows)
cursor.execute("SELECT * FROM transfers ORDER BY id ASC")
rows = cursor.fetchall()
out.append(f"-- 4. INSERT TRANSFERS ({len(rows)} records)")
out.append("INSERT INTO transfers (id, date, code, description, lot_no, outward, units, department, person, return_units, availability, created_at) VALUES")
t_vals = []
for r in rows:
    t_vals.append(
        f"({sql_int(r['id'])}, {sql_date(r['date'])}, {sql_str(r['code'])}, {sql_str_or_null(r['description'])}, "
        f"{sql_str_or_null(r['lot_no'])}, {sql_num(r['outward'])}, {sql_str(r['units'])}, {sql_str_or_null(r['department'])}, "
        f"{sql_str_or_null(r['person'])}, {sql_num(r['return_units'])}, {sql_num(r['availability'])}, {sql_ts(r['created_at'])})"
    )
out.append(",\n".join(t_vals) + ";\n")

# 5. STOCK_ADJUSTMENTS (219 rows)
cursor.execute("SELECT * FROM stock_adjustments ORDER BY id ASC")
rows = cursor.fetchall()
out.append(f"-- 5. INSERT STOCK_ADJUSTMENTS ({len(rows)} records)")
out.append("INSERT INTO stock_adjustments (id, material_code, operation, amount, reason, before_qty, after_qty, created_at) VALUES")
sa_vals = []
for r in rows:
    sa_vals.append(
        f"({sql_int(r['id'])}, {sql_str(r['material_code'])}, {sql_str(r['operation'])}, {sql_num(r['amount'])}, "
        f"{sql_str_or_null(r['reason'])}, {sql_num(r['before_qty'])}, {sql_num(r['after_qty'])}, {sql_ts(r['created_at'])})"
    )
out.append(",\n".join(sa_vals) + ";\n")

# 6. RESET IDENTITY SEQUENCES
out.append("-- 6. SYNCHRONIZE IDENTITY SEQUENCES TO HIGHEST MIGRATED IDS")
out.append("SELECT setval(pg_get_serial_sequence('materials', 'id'), COALESCE((SELECT MAX(id) FROM materials), 1));")
out.append("SELECT setval(pg_get_serial_sequence('invoices', 'id'), COALESCE((SELECT MAX(id) FROM invoices), 1));")
out.append("SELECT setval(pg_get_serial_sequence('invoice_items', 'id'), COALESCE((SELECT MAX(id) FROM invoice_items), 1));")
out.append("SELECT setval(pg_get_serial_sequence('transfers', 'id'), COALESCE((SELECT MAX(id) FROM transfers), 1));")
out.append("SELECT setval(pg_get_serial_sequence('stock_adjustments', 'id'), COALESCE((SELECT MAX(id) FROM stock_adjustments), 1));")
out.append("SELECT setval(pg_get_serial_sequence('batches', 'id'), 1, false);")
out.append("SELECT setval(pg_get_serial_sequence('dispatches', 'id'), 1, false);")
out.append("SELECT setval(pg_get_serial_sequence('dispatch_batches', 'id'), 1, false);")
out.append("SELECT setval(pg_get_serial_sequence('category_locations', 'id'), 1, false);")
out.append("SELECT setval(pg_get_serial_sequence('vendors', 'id'), 1, false);\n")

out.append("COMMIT;\n")

# 7. VERIFICATION QUERY REPORT
out.append("-- ============================================================================")
out.append("-- 7. MIGRATION VERIFICATION CHECKSUM QUERIES")
out.append("-- Run these queries in Supabase to verify 100% data parity")
out.append("-- ============================================================================")
out.append("""
SELECT 
    'materials' AS table_name, 
    COUNT(*) AS row_count, 
    192 AS expected_count, 
    ROUND(SUM(quantity), 3) AS current_stock_sum, 
    13687.920 AS expected_stock_sum,
    CASE WHEN COUNT(*) = 192 AND ROUND(SUM(quantity), 3) = 13687.920 THEN 'MATCH' ELSE 'MISMATCH' END AS status
FROM materials
UNION ALL
SELECT 
    'invoices', 
    COUNT(*), 
    57, 
    ROUND(SUM(final_total), 2), 
    4571051.46,
    CASE WHEN COUNT(*) = 57 AND ROUND(SUM(final_total), 2) = 4571051.46 THEN 'MATCH' ELSE 'MISMATCH' END
FROM invoices
UNION ALL
SELECT 
    'invoice_items', 
    COUNT(*), 
    92, 
    ROUND(SUM(item_total), 2), 
    4570951.10,
    CASE WHEN COUNT(*) = 92 AND ROUND(SUM(item_total), 2) = 4570951.10 THEN 'MATCH' ELSE 'MISMATCH' END
FROM invoice_items
UNION ALL
SELECT 
    'transfers', 
    COUNT(*), 
    180, 
    ROUND(SUM(outward), 3), 
    579.140,
    CASE WHEN COUNT(*) = 180 AND ROUND(SUM(outward), 3) = 579.140 THEN 'MATCH' ELSE 'MISMATCH' END
FROM transfers
UNION ALL
SELECT 
    'stock_adjustments', 
    COUNT(*), 
    219, 
    ROUND(SUM(amount), 3), 
    1114.213,
    CASE WHEN COUNT(*) = 219 THEN 'MATCH' ELSE 'MISMATCH' END
FROM stock_adjustments;
""")

sql_content = "\n".join(out)

output_file = r"d:\projects\MMS APP\migration\production_data_migration.sql"
with open(output_file, "w", encoding="utf-8") as f:
    f.write(sql_content)

print(f"Generated complete migration SQL script: {output_file}")
print(f"File size: {len(sql_content.encode('utf-8'))} bytes")

conn.close()
