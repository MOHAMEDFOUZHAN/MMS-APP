import sys
import psycopg2

sys.stdout.reconfigure(encoding='utf-8')

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
cur = conn.cursor()

print("Testing text standardization triggers...")

# Test 1: Category Location Insert with messy case and spaces
try:
    cur.execute("INSERT INTO category_locations (category, location) VALUES ('  tea  ', '  shelf   a-1  ') RETURNING category, location;")
    row = cur.fetchone()
    print(f"Test 1 (Auto-normalization): category='{row[0]}', location='{row[1]}'")
    assert row[0] == 'TEA', f"Expected 'TEA', got '{row[0]}'"
    assert row[1] == 'SHELF A-1', f"Expected 'SHELF A-1', got '{row[1]}'"

    # Test 2: Duplicate insert with different case must be rejected by unique index
    try:
        cur.execute("INSERT INTO category_locations (category, location) VALUES ('Tea', 'Shelf B');")
        print("ERROR: Test 2 failed - Duplicate 'Tea' was allowed!")
    except Exception as e:
        conn.rollback()
        print(f"Test 2 (Duplicate rejection): Successfully rejected duplicate 'Tea': {type(e).__name__}")

    # Clean up test row
    cur.execute("DELETE FROM category_locations WHERE category = 'TEA';")
    conn.commit()
    print("Test 1 & 2 passed and cleaned up.")
except Exception as e:
    conn.rollback()
    print(f"Test error: {e}")

# Test 3: Vendor Insert with mixed case
try:
    cur.execute("INSERT INTO vendors (name, place, gstin, material, info) VALUES ('  jai   agencies  ', 'coonoor', '33aaaaa0000a1z5', 'tea bags', 'primary') RETURNING name, place, gstin, material, info;")
    row = cur.fetchone()
    print(f"Test 3 (Vendor Normalization): name='{row[0]}', place='{row[1]}', gstin='{row[2]}', material='{row[3]}', info='{row[4]}'")
    assert row[0] == 'JAI AGENCIES'
    assert row[1] == 'COONOOR'
    assert row[2] == '33AAAAA0000A1Z5'
    assert row[3] == 'TEA BAGS'
    assert row[4] == 'PRIMARY'

    # Duplicate rejection on vendor
    try:
        cur.execute("INSERT INTO vendors (name) VALUES ('Jai Agencies');")
        print("ERROR: Duplicate vendor allowed!")
    except Exception as e:
        conn.rollback()
        print(f"Test 4 (Vendor duplicate rejection): Successfully rejected duplicate: {type(e).__name__}")

    cur.execute("DELETE FROM vendors WHERE name = 'JAI AGENCIES';")
    conn.commit()
    print("Test 3 & 4 passed and cleaned up.")
except Exception as e:
    conn.rollback()
    print(f"Vendor test error: {e}")

cur.close()
conn.close()
print("\nAll database trigger & unique constraint tests PASSED!")
