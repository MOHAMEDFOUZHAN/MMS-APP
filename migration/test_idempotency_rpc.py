import psycopg2
import json

conn = psycopg2.connect(host='aws-0-ap-northeast-1.pooler.supabase.com', port=5432, user='postgres.japxiaxyabhhhclphbqr', password='mapleconnect2307', dbname='postgres', connect_timeout=15)
conn.autocommit = True
cur = conn.cursor()

# Test idempotency on create_stock_adjustment
test_key = "TEST-IDEMP-ADJ-001"
# Clear test key if exists
cur.execute("DELETE FROM idempotency_keys WHERE idempotency_key = %s;", (test_key,))
cur.execute("DELETE FROM stock_adjustments WHERE reason = 'Idempotency Test';",)

# Get an existing material code
cur.execute("SELECT material_code, quantity FROM materials LIMIT 1;")
mat = cur.fetchone()
code = mat[0]
initial_qty = float(mat[1])
print(f"Testing adjustment idempotency on material: {code}, initial qty: {initial_qty}")

# First call with test_key
cur.execute("""
SELECT create_stock_adjustment(
    %s, 'add', 5.0, 'Idempotency Test', 'Tester', %s
);
""", (code, test_key))
res1 = cur.fetchone()[0]
print("Call 1 result:", res1)

# Check stock after call 1
cur.execute("SELECT quantity FROM materials WHERE material_code = %s;", (code,))
qty_after_1 = float(cur.fetchone()[0])
print(f"Qty after call 1: {qty_after_1} (increased by 5.0: {qty_after_1 == initial_qty + 5.0})")

# Second call with SAME test_key (simulating offline retry / duplicate network packet)
cur.execute("""
SELECT create_stock_adjustment(
    %s, 'add', 5.0, 'Idempotency Test', 'Tester', %s
);
""", (code, test_key))
res2 = cur.fetchone()[0]
print("Call 2 result (duplicate key):", res2)

# Check stock after call 2 - MUST REMAIN EXACTLY THE SAME!
cur.execute("SELECT quantity FROM materials WHERE material_code = %s;", (code,))
qty_after_2 = float(cur.fetchone()[0])
print(f"Qty after call 2: {qty_after_2} (MUST BE SAME as call 1: {qty_after_2 == qty_after_1})")

if qty_after_2 == qty_after_1:
    print("SUCCESS: Idempotency strictly prevented duplicate inventory write!")
else:
    print("FAILURE: Duplicate write occurred!")

# Clean up test adjustment
cur.execute("""
SELECT create_stock_adjustment(
    %s, 'subtract', 5.0, 'Reverting Idempotency Test', 'Tester', NULL
);
""", (code,))
cur.execute("DELETE FROM stock_adjustments WHERE reason ILIKE '%Idempotency Test%';")
cur.execute("DELETE FROM idempotency_keys WHERE idempotency_key = %s;", (test_key,))
print("Cleaned up test data.")

cur.close()
conn.close()
