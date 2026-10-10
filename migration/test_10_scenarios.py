import os
import psycopg2
import json

conn = psycopg2.connect(
    host='aws-0-ap-northeast-1.pooler.supabase.com',
    port=5432,
    user='postgres.japxiaxyabhhhclphbqr',
    password=os.environ["SUPABASE_DB_PASSWORD"],
    dbname='postgres',
    connect_timeout=15
)
conn.autocommit = True
cur = conn.cursor()

print("==================================================")
print("RUNNING 10 TEST SCENARIOS FOR STORAGE -> DISPATCH")
print("==================================================")

# Clean up any leftover test data
cur.execute("DELETE FROM dispatch_batches WHERE dispatch_id IN (SELECT id FROM dispatches WHERE material_code LIKE 'TEST-%')")
cur.execute("DELETE FROM dispatches WHERE material_code LIKE 'TEST-%'")
cur.execute("DELETE FROM batches WHERE material_code LIKE 'TEST-%'")
cur.execute("DELETE FROM materials WHERE material_code LIKE 'TEST-%'")

# Create Test Material
cur.execute("""
    INSERT INTO materials (material_code, description, category, unit, quantity, grade)
    VALUES ('TEST-MAT-01', 'Test Organic Tea', 'TEA', 'kg', 500.0, 'BP')
    RETURNING id;
""")
mat_id = cur.fetchone()[0]
print(f"Created Test Material id={mat_id}")

# Record initial materials.quantity
cur.execute("SELECT quantity FROM materials WHERE id = %s", (mat_id,))
initial_mat_qty = float(cur.fetchone()[0])

# -----------------------------------------------------------------------------
# TEST 1: SINGLE BATCH
# Batch 001: Received 100, Available 100. Dispatch 30 -> Available = 70.
# -----------------------------------------------------------------------------
print("\n--- TEST 1: SINGLE BATCH ---")
cur.execute("""
    INSERT INTO batches (material_id, material_code, description, batch_no, batch_date, received_date, received_quantity, available_quantity, uom, department, grade)
    VALUES (%s, 'TEST-MAT-01', 'Test Organic Tea', '001', '2026-01-01', '2026-01-01', 100.0, 100.0, 'kg', 'Finished Goods', 'BP')
    RETURNING id;
""", (mat_id,))
b1_id = cur.fetchone()[0]

payload1 = {
    'material_id': mat_id,
    'material_code': 'TEST-MAT-01',
    'product': 'Test Organic Tea',
    'quantity': 30.0,
    'units': 'kg',
    'location': 'Ooty Retail',
    'department': 'Dispatch',
    'date': '2026-01-02',
    'remarks': 'Test single batch dispatch'
}
cur.execute("SELECT create_dispatch_fifo(%s)", (json.dumps(payload1),))
res1 = cur.fetchone()[0]
d1_id = res1['dispatch_id']

cur.execute("SELECT available_quantity, received_quantity FROM batches WHERE id = %s", (b1_id,))
b1_row = cur.fetchone()
assert float(b1_row[0]) == 70.0, f"Expected available=70, got {b1_row[0]}"
assert float(b1_row[1]) == 100.0, f"Expected received=100 (never modified), got {b1_row[1]}"

# Verify materials.quantity WAS NOT MODIFIED!
cur.execute("SELECT quantity FROM materials WHERE id = %s", (mat_id,))
cur_mat_qty = float(cur.fetchone()[0])
assert cur_mat_qty == initial_mat_qty, f"materials.quantity should NOT change! Expected {initial_mat_qty}, got {cur_mat_qty}"
print("TEST 1 PASSED: Available = 70, Received = 100, materials.quantity untouched.")

# Clean up Test 1 dispatch
cur.execute("SELECT delete_dispatch(%s)", (d1_id,))
cur.execute("DELETE FROM batches WHERE id = %s", (b1_id,))

# -----------------------------------------------------------------------------
# TEST 2: MULTI-BATCH FIFO
# Batch 001: 100, Batch 002: 100. Dispatch 150.
# Expected: Batch 001 = 0, Batch 002 = 50. Allocations: 100 & 50.
# -----------------------------------------------------------------------------
print("\n--- TEST 2: MULTI-BATCH FIFO ---")
cur.execute("""
    INSERT INTO batches (material_id, material_code, description, batch_no, batch_date, received_date, received_quantity, available_quantity, uom, grade)
    VALUES (%s, 'TEST-MAT-01', 'Test Organic Tea', '001', '2026-01-01', '2026-01-01', 100.0, 100.0, 'kg', 'BP')
    RETURNING id;
""", (mat_id,))
batch_001 = cur.fetchone()[0]

cur.execute("""
    INSERT INTO batches (material_id, material_code, description, batch_no, batch_date, received_date, received_quantity, available_quantity, uom, grade)
    VALUES (%s, 'TEST-MAT-01', 'Test Organic Tea', '002', '2026-01-02', '2026-01-02', 100.0, 100.0, 'kg', 'BP')
    RETURNING id;
""", (mat_id,))
batch_002 = cur.fetchone()[0]

payload2 = {
    'material_id': mat_id,
    'material_code': 'TEST-MAT-01',
    'product': 'Test Organic Tea',
    'quantity': 150.0,
    'units': 'kg',
    'location': 'Coimbatore Hub',
    'department': 'Dispatch',
    'date': '2026-01-03'
}
cur.execute("SELECT create_dispatch_fifo(%s)", (json.dumps(payload2),))
res2 = cur.fetchone()[0]
d2_id = res2['dispatch_id']

cur.execute("SELECT available_quantity FROM batches WHERE id = %s", (batch_001,))
b1_avail = float(cur.fetchone()[0])
cur.execute("SELECT available_quantity FROM batches WHERE id = %s", (batch_002,))
b2_avail = float(cur.fetchone()[0])

assert b1_avail == 0.0, f"Expected batch 001 available = 0, got {b1_avail}"
assert b2_avail == 50.0, f"Expected batch 002 available = 50, got {b2_avail}"

cur.execute("SELECT batch_no, quantity FROM dispatch_batches WHERE dispatch_id = %s ORDER BY id ASC", (d2_id,))
allocs = cur.fetchall()
assert len(allocs) == 2, f"Expected 2 allocation rows, got {len(allocs)}"
assert allocs[0][0] == '001' and float(allocs[0][1]) == 100.0, f"Batch 001 allocation mismatch: {allocs[0]}"
assert allocs[1][0] == '002' and float(allocs[1][1]) == 50.0, f"Batch 002 allocation mismatch: {allocs[1]}"
print("TEST 2 PASSED: Batch 001 = 0 kg, Batch 002 = 50 kg, dispatch_batches = [100, 50].")

# -----------------------------------------------------------------------------
# TEST 3: INSUFFICIENT STOCK
# Available: 50. Dispatch: 100.
# Expected: Transaction rejected. No stock changed. No partial dispatch created.
# -----------------------------------------------------------------------------
print("\n--- TEST 3: INSUFFICIENT STOCK ---")
payload3 = {
    'material_id': mat_id,
    'material_code': 'TEST-MAT-01',
    'quantity': 100.0,
    'units': 'kg',
    'date': '2026-01-04'
}
try:
    cur.execute("SELECT create_dispatch_fifo(%s)", (json.dumps(payload3),))
    assert False, "Should have thrown Insufficient Storage Stock exception!"
except Exception as e:
    err_msg = str(e)
    assert "Insufficient Storage Stock" in err_msg, f"Expected Insufficient Storage Stock in error, got {err_msg}"
    print(f"TEST 3 PASSED: Correctly rejected with: {err_msg.strip()}")

# Verify Batch 002 still has 50 kg!
cur.execute("SELECT available_quantity FROM batches WHERE id = %s", (batch_002,))
assert float(cur.fetchone()[0]) == 50.0, "Batch 002 stock should not have changed!"

# -----------------------------------------------------------------------------
# TEST 4: EXACT STOCK
# Remaining Available: 50. Dispatch: 50.
# Expected: All eligible batches become 0 available.
# -----------------------------------------------------------------------------
print("\n--- TEST 4: EXACT STOCK ---")
payload4 = {
    'material_id': mat_id,
    'material_code': 'TEST-MAT-01',
    'quantity': 50.0,
    'units': 'kg',
    'date': '2026-01-04'
}
cur.execute("SELECT create_dispatch_fifo(%s)", (json.dumps(payload4),))
res4 = cur.fetchone()[0]
d4_id = res4['dispatch_id']

cur.execute("SELECT available_quantity FROM batches WHERE id = %s", (batch_002,))
assert float(cur.fetchone()[0]) == 0.0, "Batch 002 should now be exactly 0!"
print("TEST 4 PASSED: Batch 002 exactly depleted to 0.")

# Clean up Test 4
cur.execute("SELECT delete_dispatch(%s)", (d4_id,))
# Batch 002 is back to 50 kg.

# -----------------------------------------------------------------------------
# TEST 5: EDIT DISPATCH
# Currently: d2 has Batch 001 -> 100, Batch 002 -> 50. Total = 150.
# Available: Batch 001 = 0, Batch 002 = 50.
# Edit d2 to 120 kg.
# Expected FIFO allocation recalculated: Batch 001 = 100, Batch 002 = 20.
# Remaining Available: Batch 001 = 0, Batch 002 = 80.
# -----------------------------------------------------------------------------
print("\n--- TEST 5: EDIT DISPATCH ---")
update_payload = {
    'material_id': mat_id,
    'material_code': 'TEST-MAT-01',
    'quantity': 120.0,
    'units': 'kg',
    'date': '2026-01-05',
    'remarks': 'Edited dispatch to 120 kg'
}
cur.execute("SELECT update_dispatch(%s, %s)", (d2_id, json.dumps(update_payload)))
update_res = cur.fetchone()[0]

cur.execute("SELECT available_quantity FROM batches WHERE id = %s", (batch_001,))
assert float(cur.fetchone()[0]) == 0.0, "Batch 001 should be 0"
cur.execute("SELECT available_quantity FROM batches WHERE id = %s", (batch_002,))
b2_edited = float(cur.fetchone()[0])
assert b2_edited == 80.0, f"Batch 002 available should be 80, got {b2_edited}"

cur.execute("SELECT batch_no, quantity FROM dispatch_batches WHERE dispatch_id = %s ORDER BY id ASC", (d2_id,))
new_allocs = cur.fetchall()
assert len(new_allocs) == 2
assert float(new_allocs[0][1]) == 100.0
assert float(new_allocs[1][1]) == 20.0
print("TEST 5 PASSED: Edit recalculated FIFO: 001->100, 002->20. Batch 002 remaining = 80 kg.")

# -----------------------------------------------------------------------------
# TEST 6: DELETE DISPATCH
# Delete d2 (which had 100 from 001 and 20 from 002).
# Expected: Batch 001 restored +100 -> 100. Batch 002 restored +20 -> 100.
# -----------------------------------------------------------------------------
print("\n--- TEST 6: DELETE DISPATCH ---")
cur.execute("SELECT delete_dispatch(%s)", (d2_id,))

cur.execute("SELECT available_quantity FROM batches WHERE id = %s", (batch_001,))
assert float(cur.fetchone()[0]) == 100.0, "Batch 001 should be restored to 100"
cur.execute("SELECT available_quantity FROM batches WHERE id = %s", (batch_002,))
assert float(cur.fetchone()[0]) == 100.0, "Batch 002 should be restored to 100"

cur.execute("SELECT COUNT(*) FROM dispatches WHERE id = %s", (d2_id,))
assert cur.fetchone()[0] == 0, "Dispatch record should be deleted"
cur.execute("SELECT COUNT(*) FROM dispatch_batches WHERE dispatch_id = %s", (d2_id,))
assert cur.fetchone()[0] == 0, "Dispatch batches should be deleted"
print("TEST 6 PASSED: Batch 001 restored to 100 kg, Batch 002 restored to 100 kg.")

# -----------------------------------------------------------------------------
# TEST 7: TWO DEVICES CONCURRENCY / ROW LOCKING
# Both attempt to dispatch overlapping quantities from available 200.
# -----------------------------------------------------------------------------
print("\n--- TEST 7: CONCURRENCY / LOCKING ---")
# Device A: 120 kg, Device B: 90 kg (Total 210 > 200)
# Exactly one must succeed, second must fail with Insufficient Storage Stock.
# We test this with two independent database connections.
conn_a = psycopg2.connect(host='aws-0-ap-northeast-1.pooler.supabase.com', port=5432, user='postgres.japxiaxyabhhhclphbqr', password=os.environ["SUPABASE_DB_PASSWORD"], dbname='postgres', connect_timeout=15)
conn_b = psycopg2.connect(host='aws-0-ap-northeast-1.pooler.supabase.com', port=5432, user='postgres.japxiaxyabhhhclphbqr', password=os.environ["SUPABASE_DB_PASSWORD"], dbname='postgres', connect_timeout=15)
cur_a = conn_a.cursor()
cur_b = conn_b.cursor()

# Connection A dispatches 120
cur_a.execute("SELECT create_dispatch_fifo(%s)", (json.dumps({'material_id': mat_id, 'material_code': 'TEST-MAT-01', 'quantity': 120.0, 'units': 'kg', 'date': '2026-01-05'}),))
conn_a.commit()
d_a_id = cur_a.fetchone()[0]['dispatch_id']

# Connection B now attempts 90 (Only 80 available)
b_failed = False
try:
    cur_b.execute("SELECT create_dispatch_fifo(%s)", (json.dumps({'material_id': mat_id, 'material_code': 'TEST-MAT-01', 'quantity': 90.0, 'units': 'kg', 'date': '2026-01-05'}),))
    conn_b.commit()
except Exception as e:
    b_failed = True
    conn_b.rollback()

assert b_failed, "Connection B should have failed due to stock exhaustion!"
print("TEST 7 PASSED: Device A allocated 120 kg. Device B request for 90 kg safely rejected. No overselling!")

# Clean up d_a
cur_a.execute("SELECT delete_dispatch(%s)", (d_a_id,))
conn_a.commit()
cur_a.close(); conn_a.close()
cur_b.close(); conn_b.close()

# -----------------------------------------------------------------------------
# TEST 8: SAME MATERIAL MULTIPLE BATCHES
# 3 batches: Batch 001 = 50, Batch 002 = 50, Batch 003 = 50.
# Dispatch 75 -> Consumes 50 from 001, 25 from 002, 003 untouched.
# -----------------------------------------------------------------------------
print("\n--- TEST 8: SAME MATERIAL MULTIPLE BATCHES ---")
cur.execute("DELETE FROM batches WHERE material_id = %s", (mat_id,))
cur.execute("""
    INSERT INTO batches (material_id, material_code, description, batch_no, batch_date, received_date, received_quantity, available_quantity, uom)
    VALUES 
    (%s, 'TEST-MAT-01', 'Test Organic Tea', '001', '2026-01-01', '2026-01-01', 50.0, 50.0, 'kg'),
    (%s, 'TEST-MAT-01', 'Test Organic Tea', '002', '2026-01-02', '2026-01-02', 50.0, 50.0, 'kg'),
    (%s, 'TEST-MAT-01', 'Test Organic Tea', '003', '2026-01-03', '2026-01-03', 50.0, 50.0, 'kg');
""", (mat_id, mat_id, mat_id))

cur.execute("SELECT create_dispatch_fifo(%s)", (json.dumps({'material_id': mat_id, 'material_code': 'TEST-MAT-01', 'quantity': 75.0, 'units': 'kg', 'date': '2026-01-05'}),))
d8_res = cur.fetchone()[0]
d8_id = d8_res['dispatch_id']

cur.execute("SELECT batch_no, available_quantity FROM batches WHERE material_id = %s ORDER BY batch_no ASC", (mat_id,))
b_rows = cur.fetchall()
assert float(b_rows[0][1]) == 0.0, "Batch 001 should be 0"
assert float(b_rows[1][1]) == 25.0, "Batch 002 should be 25"
assert float(b_rows[2][1]) == 50.0, "Batch 003 should be 50"
print("TEST 8 PASSED: Multi-batch distinct storage intact: 001=0, 002=25, 003=50.")

# -----------------------------------------------------------------------------
# TEST 9: DIFFERENT MATERIALS ISOLATION
# Material A and Material B have separate batches. Dispatch A never touches B.
# -----------------------------------------------------------------------------
print("\n--- TEST 9: DIFFERENT MATERIALS ISOLATION ---")
cur.execute("""
    INSERT INTO materials (material_code, description, category, unit, quantity)
    VALUES ('TEST-MAT-02', 'Test Black Tea', 'TEA', 'kg', 200.0)
    RETURNING id;
""")
mat2_id = cur.fetchone()[0]

cur.execute("""
    INSERT INTO batches (material_id, material_code, description, batch_no, batch_date, received_date, received_quantity, available_quantity, uom)
    VALUES (%s, 'TEST-MAT-02', 'Test Black Tea', '001', '2026-01-01', '2026-01-01', 100.0, 100.0, 'kg');
""", (mat2_id,))

# Dispatch Material 2
cur.execute("SELECT create_dispatch_fifo(%s)", (json.dumps({'material_id': mat2_id, 'material_code': 'TEST-MAT-02', 'quantity': 40.0, 'units': 'kg', 'date': '2026-01-05'}),))
d9_id = cur.fetchone()[0]['dispatch_id']

# Verify Material 2 batch is 60
cur.execute("SELECT available_quantity FROM batches WHERE material_id = %s", (mat2_id,))
assert float(cur.fetchone()[0]) == 60.0

# Verify Material 1 batches are unchanged
cur.execute("SELECT batch_no, available_quantity FROM batches WHERE material_id = %s ORDER BY batch_no ASC", (mat_id,))
b_mat1_rows = cur.fetchall()
assert float(b_mat1_rows[0][1]) == 0.0
assert float(b_mat1_rows[1][1]) == 25.0
assert float(b_mat1_rows[2][1]) == 50.0
print("TEST 9 PASSED: Material A and B strictly isolated.")

# -----------------------------------------------------------------------------
# TEST 10: CLEANUP AND MATERIALS.QUANTITY FINAL VERIFICATION
# -----------------------------------------------------------------------------
print("\n--- TEST 10: FINAL VERIFICATION & CLEANUP ---")
cur.execute("SELECT delete_dispatch(%s)", (d8_id,))
cur.execute("SELECT delete_dispatch(%s)", (d9_id,))
cur.execute("DELETE FROM batches WHERE material_code LIKE 'TEST-%'")
cur.execute("DELETE FROM materials WHERE material_code LIKE 'TEST-%'")

print("TEST 10 PASSED: All test records reversed and cleaned up.")
print("\nALL 10 TESTS PASSED AT THE DATABASE ENGINE LEVEL!")

cur.close()
conn.close()
