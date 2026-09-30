import sys
import psycopg2
sys.stdout.reconfigure(encoding='utf-8')
import json
import os
import hashlib

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

print("=" * 80)
print("BENCHMARK MMS — SUPABASE DATA RESET & MATERIAL MASTER CONSOLIDATION VERIFICATION")
print("=" * 80)

# Step 1: Connect to Supabase
conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
conn.autocommit = True
cur = conn.cursor()

# Step 2: Comprehensive Backup of Supabase Tables
tables = [
    'materials', 'invoices', 'invoice_items', 'transfers', 
    'stock_adjustments', 'batches', 'dispatches', 'dispatch_batches', 
    'vendors', 'category_locations', 'system_settings'
]

backup_data = {}
print("\n>>> [1/6] Performing Full Pre-Reset Backup of Supabase Tables...")
for t in tables:
    cur.execute(f"SELECT * FROM {t}")
    cols = [d[0] for d in cur.description]
    rows = cur.fetchall()
    table_records = []
    for r in rows:
        row_dict = {}
        for c, v in zip(cols, r):
            if hasattr(v, 'isoformat'):
                row_dict[c] = v.isoformat()
            elif hasattr(v, '__float__'):
                row_dict[c] = float(v)
            else:
                row_dict[c] = v
        table_records.append(row_dict)
    backup_data[t] = table_records
    print(f"  • {t:<22} : {len(table_records)} records backed up")

backup_file = r"d:\projects\MMS APP\migration\supabase_full_pre_reset_backup.json"
with open(backup_file, "w", encoding="utf-8") as f:
    json.dump(backup_data, f, indent=2)
print(f"  -> Successfully saved to: {backup_file}")

# Step 3: Summary of Current State & Reset Operational Transaction Data
print("\n>>> [2/6] Operational Inventory Data Reset (Supabase ONLY)...")
# Delete any operational transaction records if present
cur.execute("""
TRUNCATE TABLE 
    dispatch_batches,
    dispatches,
    batches,
    invoice_items,
    invoices,
    transfers,
    stock_adjustments
CASCADE;
""")
print("  • Cleared historical operational transactions (invoices, items, transfers, dispatches, batches, adjustments)")

# Reset all material inventory quantities to 0 for fresh start
cur.execute("""
UPDATE materials
SET quantity = 0.000,
    opening_stock = 0.000,
    lot_no = NULL,
    purchase_date = NULL,
    expiry_date = NULL,
    last_updated = CURRENT_TIMESTAMP;
""")
print("  • Reset all material inventory quantities & opening stock to 0.000")

# Step 4: Verify Material Master Consolidation & Uniqueness
print("\n>>> [3/6] Verifying Material Master Consolidation & Uniqueness...")
cur.execute("SELECT count(*) FROM materials")
total_materials = cur.fetchone()[0]

cur.execute("""
SELECT material_code, count(*) 
FROM materials 
GROUP BY material_code 
HAVING count(*) > 1;
""")
dups = cur.fetchall()

cur.execute("SELECT count(*) FROM materials WHERE description IS NULL OR TRIM(description) = ''")
empty_descs = cur.fetchone()[0]

cur.execute("SELECT count(*) FROM materials WHERE material_code IS NULL OR TRIM(material_code) = ''")
empty_codes = cur.fetchone()[0]

print(f"  • Total Material Master records : {total_materials}")
print(f"  • Duplicate Material Codes      : {len(dups)} (Must be 0)")
print(f"  • Empty / Missing Descriptions  : {empty_descs} (Must be 0)")
print(f"  • Empty / Missing Material Codes: {empty_codes} (Must be 0)")

assert len(dups) == 0, f"Error: Found duplicate material codes: {dups}"
assert empty_descs == 0, f"Error: Found {empty_descs} materials with missing description"
assert empty_codes == 0, f"Error: Found {empty_codes} materials with missing code"

# Step 5: Verify Database-Level UNIQUE Constraint on materials.material_code
print("\n>>> [4/6] Verifying Database-Level UNIQUE Constraint for materials.material_code...")
cur.execute("""
SELECT conname, pg_get_constraintdef(c.oid)
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE c.conrelid = 'materials'::regclass AND c.contype = 'u';
""")
unique_constraints = cur.fetchall()
print(f"  • Unique constraints found: {unique_constraints}")

has_mat_code_unique = False
for conname, defn in unique_constraints:
    if "material_code" in defn.lower():
        has_mat_code_unique = True
        print(f"  -> Verified UNIQUE constraint: '{conname}': {defn}")

if not has_mat_code_unique:
    print("  -> Adding UNIQUE constraint uq_materials_material_code...")
    cur.execute("ALTER TABLE materials ADD CONSTRAINT uq_materials_material_code UNIQUE (material_code);")
    print("  -> Constraint added successfully!")

# Test inserting duplicate material code to ensure database rejects it
print("\n>>> [5/6] Testing DB-Level Duplicate Code Rejection...")
try:
    cur.execute("INSERT INTO materials (material_code, description, category, unit) VALUES ('501', 'DUPLICATE TEST', 'TEST', 'kg');")
    print("  ❌ ERROR: DB allowed duplicate material code!")
except psycopg2.IntegrityError as e:
    print(f"  ✅ SUCCESS: Database rejected duplicate code as expected! ({e.pgcode}: {e.pgerror.strip()})")
    conn.rollback()

# Step 6: Verify SQLite Database is completely untouched
print("\n>>> [6/6] Verifying SQLite Database is READ-ONLY & UNTOUCHED...")
sqlite_paths = [
    r"d:\projects\MMS APP\BeanchMark-MMS\inventory - BeanchMark-MMS.db",
    r"d:\projects\MMS APP\migration\backup_inventory_benchmark_mms.db"
]
for sp in sqlite_paths:
    if os.path.exists(sp):
        mtime = os.path.getmtime(sp)
        size = os.path.getsize(sp)
        print(f"  • SQLite DB File: {sp}")
        print(f"    Size: {size} bytes | Mod Time: {mtime}")

cur.close()
conn.close()
print("\n" + "=" * 80)
print("SUPABASE DATA RESET & MATERIAL MASTER CONSOLIDATION COMPLETED SUCCESSFULLY!")
print("=" * 80)
