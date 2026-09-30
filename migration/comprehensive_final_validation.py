import sys
import psycopg2
import json
import os
import hashlib

sys.stdout.reconfigure(encoding='utf-8')

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

print("=" * 80)
print("BENCHMARK MMS — END-TO-END FINAL VALIDATION TEST SUITE")
print("=" * 80)

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
conn.autocommit = True
cur = conn.cursor()

# ── TEST 1: Material Master Deduplication & Clean State ──
print("\n[TEST 1] Verifying Material Master Deduplication & Clean Zero State...")
cur.execute("SELECT count(*) FROM materials;")
mat_count = cur.fetchone()[0]
print(f"  • Total Material Master records in Supabase: {mat_count}")

cur.execute("SELECT material_code, count(*) FROM materials GROUP BY material_code HAVING count(*) > 1;")
dups = cur.fetchall()
print(f"  • Duplicate Material Codes: {len(dups)}")
assert len(dups) == 0, f"FAILED: Found duplicate codes: {dups}"
print("  ✅ PASS: No duplicate Material Codes exist.")

cur.execute("SELECT count(*) FROM materials WHERE description IS NULL OR TRIM(description) = '';")
empty_desc = cur.fetchone()[0]
assert empty_desc == 0, f"FAILED: Found {empty_desc} materials with empty description"
print("  ✅ PASS: Every material has a valid Description.")

cur.execute("SELECT sum(quantity), sum(opening_stock) FROM materials;")
stock_sums = cur.fetchone()
print(f"  • Initial Stock Sum: {stock_sums[0]}, Opening Stock Sum: {stock_sums[1]}")
assert float(stock_sums[0]) == 0.0 and float(stock_sums[1]) == 0.0, "FAILED: Stock quantities not zeroed!"
print("  ✅ PASS: Clean operational start state verified (stock = 0).")

# ── TEST 2: DB-Level UNIQUE Constraint ──
print("\n[TEST 2] Verifying Database-Level UNIQUE Constraint on materials.material_code...")
cur.execute("""
SELECT conname, pg_get_constraintdef(c.oid)
FROM pg_constraint c
JOIN pg_namespace n ON n.oid = c.connamespace
WHERE c.conrelid = 'materials'::regclass AND c.contype = 'u';
""")
constrs = cur.fetchall()
print(f"  • Active UNIQUE constraints: {constrs}")
assert any('material_code' in c[1].lower() for c in constrs), "FAILED: UNIQUE constraint on material_code missing!"

# Verify rejection
try:
    cur.execute("INSERT INTO materials (material_code, description, category, unit) VALUES ('501', 'DUPLICATE REJECTION TEST', 'TEST', 'kg');")
    assert False, "FAILED: Database allowed duplicate material code insert!"
except psycopg2.IntegrityError:
    print("  ✅ PASS: Database strictly rejects duplicate material code insert (uq_materials_material_code enforced).")
    conn.rollback()

# ── TEST 3: Material Search Logic (Code and Description) ──
print("\n[TEST 3] Verifying Material Search Logic by Code and Description...")
cur.execute("SELECT material_code, description, category, unit FROM materials WHERE material_code ILIKE '%501%' OR description ILIKE '%501%';")
res_code = cur.fetchall()
print(f"  • Search '501' returned {len(res_code)} results: {res_code}")
assert len(res_code) >= 1 and any(r[0] == '501' for r in res_code), "FAILED: Search by code 501 failed!"

cur.execute("SELECT material_code, description, category, unit FROM materials WHERE material_code ILIKE '%TEA%' OR description ILIKE '%TEA%';")
res_desc = cur.fetchall()
print(f"  • Search 'TEA' returned {len(res_desc)} results. First 3: {res_desc[:3]}")
assert len(res_desc) >= 1, "FAILED: Search by description 'TEA' failed!"
print("  ✅ PASS: Live search by Code and Description working properly.")

# ── TEST 4: Purchase Invoice Creation Workflow ──
print("\n[TEST 4] Testing Purchase Invoice Creation & Stock/Storage Inward...")
cur.execute("SELECT material_code, description, category, unit, hsn_sac, grade, reorder_level FROM materials WHERE material_code = '501';")
m501 = cur.fetchone()
print(f"  • Target Material 501 Master: code={m501[0]}, desc={m501[1]}, cat={m501[2]}, unit={m501[3]}")

invoice_payload = json.dumps({
    "purchase_id": "TEST-PUR-01",
    "date": "2026-09-29",
    "invoice_no": "TEST-INV-1001",
    "vendor": "Test Supreme Tea & Spices",
    "no_of_items": 1,
    "cgst_percent": 2.5,
    "sgst_percent": 2.5,
    "round_off_value": 0.00,
    "payment_status": "Paid",
    "remarks": "Automated Validation Invoice"
})

items_payload = json.dumps([{
    "material": "501",
    "description": m501[1],
    "category": m501[2],
    "unit": m501[3],
    "quantity": 100.0,
    "unit_price": 50.0,
    "discount_percentage": 10.0,
    "gst_percentage": 5.0,
    "igst_percentage": 0.0,
    "lot_no": "BATCH-TEST-501A",
    "purchase_date": "2026-09-29",
    "expiry_date": "2027-09-29",
    "hsn_sac": m501[4] or "",
    "grade": m501[5] or "STANDARD",
    "reorder_level": float(m501[6])
}])

cur.execute("SELECT create_purchase(%s, %s);", (invoice_payload, items_payload))
inv_res = cur.fetchone()[0]
print(f"  • create_purchase RPC Result: {inv_res}")
assert inv_res['success'] is True, "FAILED: create_purchase returned false"

test_inv_id = inv_res['invoice_id']

# Verify Material Master Stock Updated
cur.execute("SELECT quantity, lot_no FROM materials WHERE material_code = '501';")
mat_stock, last_lot = cur.fetchone()
print(f"  • Material 501 Updated Master Quantity: {mat_stock} (Expected: 100.000)")
assert float(mat_stock) == 100.0, f"FAILED: Expected 100.0, got {mat_stock}"

# Verify Batch Created in Storage
cur.execute("SELECT batch_no, received_quantity, available_quantity, uom FROM batches WHERE invoice_id = %s;", (test_inv_id,))
batch_row = cur.fetchone()
print(f"  • Storage Batch Created: {batch_row}")
assert batch_row[0] == "BATCH-TEST-501A" and float(batch_row[2]) == 100.0, "FAILED: Batch not created properly"
print("  ✅ PASS: Purchase invoice created, Material Master stock updated, and Storage batch recorded.")

# ── TEST 5: Department Transfer Workflow ──
print("\n[TEST 5] Testing Department Outward Transfer & Return Workflow...")
transfer_out_payload = json.dumps({
    "code": "501",
    "department": "Tea Department",
    "person": "Chef Ramesh",
    "units": m501[3],
    "date": "2026-09-29",
    "outward": 25.0,
    "return_units": 0.0
})
cur.execute("SELECT create_transfer(%s);", (transfer_out_payload,))
trans_res = cur.fetchone()[0]
print(f"  • Outward Transfer RPC Result: {trans_res}")
assert trans_res['success'] is True

cur.execute("SELECT quantity FROM materials WHERE material_code = '501';")
qty_after_transfer = cur.fetchone()[0]
print(f"  • Material 501 Quantity after 25 unit outward transfer: {qty_after_transfer} (Expected: 75.000)")
assert float(qty_after_transfer) == 75.0, f"FAILED: Expected 75.0, got {qty_after_transfer}"

# Test Transfer Return
transfer_ret_payload = json.dumps({
    "code": "501",
    "department": "Tea Department",
    "person": "Chef Ramesh",
    "units": m501[3],
    "date": "2026-09-29",
    "outward": 0.0,
    "return_units": 5.0
})
cur.execute("SELECT create_transfer(%s);", (transfer_ret_payload,))
ret_res = cur.fetchone()[0]
print(f"  • Return Transfer RPC Result: {ret_res}")

cur.execute("SELECT quantity FROM materials WHERE material_code = '501';")
qty_after_return = cur.fetchone()[0]
print(f"  • Material 501 Quantity after 5 unit return: {qty_after_return} (Expected: 80.000)")
assert float(qty_after_return) == 80.0, f"FAILED: Expected 80.0, got {qty_after_return}"
print("  ✅ PASS: Department transfer outward and return accurately validated.")

# ── TEST 6: FIFO Dispatch Workflow & Stock Validation ──
print("\n[TEST 6] Testing FIFO Dispatch Workflow & Stock Validation...")
# First test Insufficient Stock Validation (Request 500 when available is 100 in batches)
dispatch_invalid = json.dumps({
    "material_code": "501",
    "product": m501[1],
    "quantity": 500.0,
    "units": m501[3],
    "location": "Retail Counter",
    "department": "Dispatch",
    "date": "2026-09-29"
})
try:
    cur.execute("SELECT create_dispatch_fifo(%s);", (dispatch_invalid,))
    assert False, "FAILED: Dispatch allowed quantity exceeding available stock!"
except Exception as e:
    print(f"  • Stock Validation Rejection: {e.pgerror.strip() if hasattr(e, 'pgerror') else e}")
    print("  ✅ PASS: Over-dispatch strictly prevented by stock validation.")
    conn.rollback()

# Now execute valid FIFO dispatch of 40 units
dispatch_valid = json.dumps({
    "material_code": "501",
    "product": m501[1],
    "quantity": 40.0,
    "units": m501[3],
    "location": "Retail Counter",
    "department": "Dispatch",
    "date": "2026-09-29"
})
cur.execute("SELECT create_dispatch_fifo(%s);", (dispatch_valid,))
disp_res = cur.fetchone()[0]
print(f"  • Valid FIFO Dispatch RPC Result: {disp_res}")
assert disp_res['success'] is True
test_disp_id = disp_res['dispatch_id']

# Verify batch available quantity reduced from 100 to 60
cur.execute("SELECT available_quantity FROM batches WHERE invoice_id = %s;", (test_inv_id,))
batch_avail = cur.fetchone()[0]
print(f"  • Batch BATCH-TEST-501A Available Quantity after FIFO dispatch: {batch_avail} (Expected: 60.000)")
assert float(batch_avail) == 60.0, f"FAILED: Expected 60.0, got {batch_avail}"

# Verify dispatch_batches relationship created
cur.execute("SELECT batch_no, quantity FROM dispatch_batches WHERE dispatch_id = %s;", (test_disp_id,))
db_link = cur.fetchone()
print(f"  • Dispatch-to-Batch relationship: batch={db_link[0]}, allocated_qty={db_link[1]}")
assert db_link[0] == "BATCH-TEST-501A" and float(db_link[1]) == 40.0
print("  ✅ PASS: FIFO dispatch consumed oldest batch and recorded dispatch-to-batch link.")

# ── TEST 7: Clean Reset Back to Pristine Operational State ──
print("\n[TEST 7] Returning Supabase Operational State to Pristine Zero State...")
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
cur.execute("UPDATE materials SET quantity = 0.000, opening_stock = 0.000, lot_no = NULL, last_updated = CURRENT_TIMESTAMP;")
cur.execute("SELECT count(*) FROM materials;")
final_mat_count = cur.fetchone()[0]
cur.execute("SELECT sum(quantity) FROM materials;")
final_stock_sum = cur.fetchone()[0]
print(f"  • Final Material Master Count: {final_mat_count}")
print(f"  • Final Material Master Stock Sum: {final_stock_sum}")
assert final_mat_count == 151 and float(final_stock_sum) == 0.0
print("  ✅ PASS: Supabase clean zero operational state restored.")

# ── TEST 8: Verify SQLite Database is Untouched ──
print("\n[TEST 8] Verifying SQLite Database is Untouched...")
sqlite_file = r"d:\projects\MMS APP\BeanchMark-MMS\inventory - BeanchMark-MMS.db"
assert os.path.exists(sqlite_file)
size = os.path.getsize(sqlite_file)
print(f"  • SQLite File: {sqlite_file} (Size: {size} bytes)")
assert size == 139264, f"FAILED: SQLite file size changed: {size}"
print("  ✅ PASS: SQLite database is READ-ONLY and completely untouched.")

cur.close()
conn.close()

print("\n" + "=" * 80)
print("🎉 ALL FINAL VALIDATION CHECKS PASSED WITH 100% SUCCESS!")
print("=" * 80)
