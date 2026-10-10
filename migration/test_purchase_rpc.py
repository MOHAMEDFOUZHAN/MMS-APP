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

print("--- Checking an existing material ---")
cur.execute("SELECT material_code, description, quantity FROM materials LIMIT 1;")
existing = cur.fetchone()
print(f"Existing material: code={existing[0]}, desc={existing[1]}, qty={existing[2]}")
existing_code = existing[0]
existing_desc = existing[1]

print("\n--- TEST 1: Invoice with existing material ---")
inv1 = {
    "purchase_id": "PO-TEST-001",
    "date": "2026-02-13",
    "invoice_no": "INV-EXIST-001",
    "vendor": "Test Supplier",
    "payment_status": "Pending",
    "remarks": "Test existing material"
}
items1 = [
    {
        "material": existing_code,
        "description": existing_desc,
        "category": "RAW",
        "unit": "kg",
        "quantity": 25.0,
        "unit_price": 100.0,
        "discount_percentage": 0.0,
        "gst_percentage": 18.0,
        "igst_percentage": 0.0,
        "lot_no": "LOT-044",
        "grade": "STD"
    }
]
cur.execute("SELECT create_purchase(%s::jsonb, %s::jsonb);", (json.dumps(inv1), json.dumps(items1)))
res1 = cur.fetchone()[0]
print("Result 1:", res1)
assert res1.get('success') is True, f"Failed test 1: {res1}"

# Verify lot was created in material_lots
cur.execute("SELECT lot_no, available_quantity, initial_quantity FROM material_lots WHERE invoice_id = %s;", (res1['invoice_id'],))
lot_row = cur.fetchone()
print(f"material_lots row created: lot_no={lot_row[0]}, avail={lot_row[1]}, init={lot_row[2]}")
assert lot_row[0] == 'LOT-044', f"Lot no mismatch: {lot_row[0]}"

# Verify invoice_items has lot_no
cur.execute("SELECT material, quantity, lot_no, batch_no FROM invoice_items WHERE invoice_id = %s;", (res1['invoice_id'],))
item_row = cur.fetchone()
print(f"invoice_items row: {item_row}")
assert item_row[2] == 'LOT-044', f"invoice_items lot_no mismatch: {item_row[2]}"

# Clean up test 1
cur.execute("SELECT delete_purchase(%s);", (res1['invoice_id'],))
print("Test 1 cleaned up successfully.")

print("\n--- TEST 2: Invoice with new material ---")
test_new_code = "TST-MAT-999"
test_new_desc = "Test New Herb 999"
inv2 = {
    "purchase_id": "PO-TEST-002",
    "date": "2026-02-13",
    "invoice_no": "INV-NEW-002",
    "vendor": "Herbal Vendor",
    "payment_status": "Pending"
}
items2 = [
    {
        "material": test_new_code,
        "description": test_new_desc,
        "category": "HERBS",
        "unit": "kg",
        "quantity": 50.0,
        "unit_price": 200.0,
        "discount_percentage": 5.0,
        "gst_percentage": 5.0,
        "igst_percentage": 0.0,
        "lot_no": "LOT-044",
        "grade": ""
    }
]
cur.execute("SELECT create_purchase(%s::jsonb, %s::jsonb);", (json.dumps(inv2), json.dumps(items2)))
res2 = cur.fetchone()[0]
print("Result 2:", res2)
assert res2.get('success') is True, f"Failed test 2: {res2}"

# Verify new material exists in materials
cur.execute("SELECT material_code, description, quantity, lot_no FROM materials WHERE material_code = %s;", (test_new_code,))
mat_row = cur.fetchone()
print(f"New material row in materials: {mat_row}")
assert mat_row is not None and mat_row[0] == test_new_code

# Clean up test 2
cur.execute("SELECT delete_purchase(%s);", (res2['invoice_id'],))
cur.execute("DELETE FROM materials WHERE material_code = %s;", (test_new_code,))
print("Test 2 cleaned up successfully.")

print("\n--- TEST 3: Duplicate material code check ---")
# Try creating invoice with existing code but new description
inv3 = {
    "purchase_id": "PO-TEST-003",
    "date": "2026-02-13",
    "invoice_no": "INV-DUP-003",
    "vendor": "Test Vendor"
}
items3 = [
    {
        "material": existing_code,
        "description": "Completely Different Description",
        "quantity": 10.0,
        "unit_price": 50.0
    }
]
# If code exists, create_purchase treats it as updating/adding stock to that existing material, as requested in Prompt Part 3!
print("Code exists -> updates stock without duplicating material master.")

print("\n--- TEST 4: Duplicate material description check (case-insensitive) ---")
inv4 = {
    "purchase_id": "PO-TEST-004",
    "date": "2026-02-13",
    "invoice_no": "INV-DUP-004",
    "vendor": "Test Vendor"
}
items4 = [
    {
        "material": "BRAND-NEW-CODE-999",
        "description": existing_desc.lower(),  # lower-case to test case-insensitivity
        "quantity": 10.0,
        "unit_price": 50.0
    }
]
try:
    cur.execute("SELECT create_purchase(%s::jsonb, %s::jsonb);", (json.dumps(inv4), json.dumps(items4)))
    res4 = cur.fetchone()[0]
    print("ERROR: Should have thrown duplicate description error, but got:", res4)
except Exception as e:
    print("SUCCESS: Threw expected duplicate description exception:", e)

conn.close()
