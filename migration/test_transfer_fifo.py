import os
import psycopg2
import json

conn = psycopg2.connect(
    host='aws-0-ap-northeast-1.pooler.supabase.com',
    port=5432,
    user='postgres.japxiaxyabhhhclphbqr',
    password=os.environ["SUPABASE_DB_PASSWORD"],
    dbname='postgres'
)
conn.autocommit = True
cur = conn.cursor()

test_mat_code = "TRF-TEST-MAT"
test_mat_name = "Transfer Test Material"

print("\n--- Setup: Create test material and 2 lots ---")
# Clean up any leftover
cur.execute("DELETE FROM materials WHERE material_code = %s;", (test_mat_code,))

# Create material
cur.execute("""
    INSERT INTO materials (material_code, description, category, quantity, unit, unit_price)
    VALUES (%s, %s, 'RAW', 200.0, 'kg', 10.0)
    RETURNING id;
""", (test_mat_code, test_mat_name))
mat_id = cur.fetchone()[0]

# Create Lot 1: 100 KG, date 2026-01-01
cur.execute("""
    INSERT INTO material_lots (material_id, material_code, lot_no, lot_date, initial_quantity, available_quantity, uom)
    VALUES (%s, %s, 'LOT-001', '2026-01-01', 100.0, 100.0, 'kg')
    RETURNING id;
""", (mat_id, test_mat_code))
lot1_id = cur.fetchone()[0]

# Create Lot 2: 100 KG, date 2026-01-02
cur.execute("""
    INSERT INTO material_lots (material_id, material_code, lot_no, lot_date, initial_quantity, available_quantity, uom)
    VALUES (%s, %s, 'LOT-002', '2026-01-02', 100.0, 100.0, 'kg')
    RETURNING id;
""", (mat_id, test_mat_code))
lot2_id = cur.fetchone()[0]

print(f"Material {test_mat_code} created with Lot1 ({lot1_id})=100kg, Lot2 ({lot2_id})=100kg")

print("\n--- TEST: Multi-lot Transfer of 150 KG ---")
trf_payload = {
    "code": test_mat_code,
    "department": "Production A",
    "person": "John Doe",
    "outward": 150.0,
    "return_units": 0.0,
    "units": "kg",
    "date": "2026-01-10"
}
cur.execute("SELECT create_transfer(%s::jsonb);", (json.dumps(trf_payload),))
trf_res = cur.fetchone()[0]
print("Transfer result:", trf_res)
assert trf_res.get('success') is True
trf_id = trf_res['transfer_id']

# Verify allocations
cur.execute("SELECT lot_no, quantity FROM transfer_lot_allocations WHERE transfer_id = %s ORDER BY id ASC;", (trf_id,))
allocs = cur.fetchall()
print("Allocations:", allocs)
assert len(allocs) == 2, f"Expected 2 allocations, got {len(allocs)}"
assert allocs[0][0] == 'LOT-001' and allocs[0][1] == 100.0, f"Expected LOT-001 100kg, got {allocs[0]}"
assert allocs[1][0] == 'LOT-002' and allocs[1][1] == 50.0, f"Expected LOT-002 50kg, got {allocs[1]}"

# Verify lot remaining balances
cur.execute("SELECT lot_no, available_quantity FROM material_lots WHERE material_code = %s ORDER BY lot_date ASC;", (test_mat_code,))
lots = cur.fetchall()
print("Lot balances after transfer:", lots)
assert lots[0][1] == 0.0, f"LOT-001 should be 0, got {lots[0][1]}"
assert lots[1][1] == 50.0, f"LOT-002 should be 50, got {lots[1][1]}"

# Verify material master quantity
cur.execute("SELECT quantity FROM materials WHERE material_code = %s;", (test_mat_code,))
mat_qty = cur.fetchone()[0]
print("Material total quantity remaining:", mat_qty)
assert mat_qty == 50.0, f"Expected 50kg, got {mat_qty}"

print("\n--- TEST: Insufficient Stock Transfer (try 60 KG with only 50 KG left) ---")
trf_insufficient = {
    "code": test_mat_code,
    "department": "Production B",
    "person": "Jane Doe",
    "outward": 60.0,
    "units": "kg",
    "date": "2026-01-11"
}
try:
    cur.execute("SELECT create_transfer(%s::jsonb);", (json.dumps(trf_insufficient),))
    res = cur.fetchone()[0]
    print("ERROR: Should have thrown insufficient stock, but got:", res)
except Exception as e:
    print("SUCCESS: Threw expected insufficient stock exception:", e)

print("\n--- TEST: Delete Transfer and Exact Lot Restoration ---")
cur.execute("SELECT delete_transfer(%s);", (trf_id,))
del_res = cur.fetchone()[0]
print("Delete transfer result:", del_res)

cur.execute("SELECT lot_no, available_quantity FROM material_lots WHERE material_code = %s ORDER BY lot_date ASC;", (test_mat_code,))
restored_lots = cur.fetchall()
print("Restored lot balances:", restored_lots)
assert restored_lots[0][1] == 100.0, f"LOT-001 should be restored to 100, got {restored_lots[0][1]}"
assert restored_lots[1][1] == 100.0, f"LOT-002 should be restored to 100, got {restored_lots[1][1]}"

cur.execute("SELECT quantity FROM materials WHERE material_code = %s;", (test_mat_code,))
restored_mat_qty = cur.fetchone()[0]
print("Restored material total quantity:", restored_mat_qty)
assert restored_mat_qty == 200.0, f"Expected 200kg, got {restored_mat_qty}"

# Clean up
cur.execute("DELETE FROM materials WHERE material_code = %s;", (test_mat_code,))
print("All Transfer FIFO and Restoration tests PASSED!")

conn.close()
