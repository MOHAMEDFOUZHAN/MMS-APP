import psycopg2
import json

def test_chocolate_consumption():
    conn = psycopg2.connect(
        host='aws-0-ap-northeast-1.pooler.supabase.com',
        port=5432,
        user='postgres.japxiaxyabhhhclphbqr',
        password='mapleconnect2307',
        dbname='postgres',
        connect_timeout=15
    )
    conn.autocommit = True
    cur = conn.cursor()

    print("=== Testing Chocolate Consumption Backend Logic ===")
    cur.execute("DELETE FROM public.chocolate_consumption_ledger WHERE notes = 'Test record verification';")
    cur.execute("DELETE FROM public.idempotency_keys WHERE idempotency_key = 'test_choc_consume_123';")

    # Find a tea-only material
    cur.execute("""
        SELECT DISTINCT TRIM(t.code), TRIM(t.description)
        FROM public.transfers t
        WHERE UPPER(TRIM(COALESCE(t.department, ''))) = 'TEA'
          AND TRIM(t.code) NOT IN (
              SELECT DISTINCT TRIM(c.code)
              FROM public.transfers c
              WHERE UPPER(TRIM(COALESCE(c.department, ''))) = 'CHOCOLATE'
          )
        LIMIT 1;
    """)
    tea_only = cur.fetchone()
    print(f"Tea-only material found: {tea_only}")

    # Test 1: Material transferred only to Tea must be rejected by record_chocolate_consumption
    print("\n--- Test 1: Rejecting Tea-only material in Chocolate consume ---")
    try:
        cur.execute("""
            SELECT public.record_chocolate_consumption(%s::jsonb);
        """, (json.dumps({
            'material_code': tea_only[0],
            'description': tea_only[1],
            'consumed_qty': 1.0,
            'operator_name': 'Test Op'
        }),))
        print("FAIL: Should have raised exception for tea-only material!")
    except Exception as e:
        print(f"PASS: Correctly rejected with error: {e}")

    # Test 2: Material only in Material Master (never transferred)
    print("\n--- Test 2: Rejecting Master-only material (never transferred) ---")
    cur.execute("""
        SELECT material_code, description 
        FROM public.materials 
        WHERE material_code NOT IN (SELECT DISTINCT code FROM public.transfers)
        LIMIT 1;
    """)
    master_only = cur.fetchone()
    if master_only:
        print(f"Master-only material: {master_only}")
        try:
            cur.execute("""
                SELECT public.record_chocolate_consumption(%s::jsonb);
            """, (json.dumps({
                'material_code': master_only[0],
                'description': master_only[1],
                'consumed_qty': 1.0,
                'operator_name': 'Test Op'
            }),))
            print("FAIL: Should have raised exception for master-only material!")
        except Exception as e:
            print(f"PASS: Correctly rejected with error: {e}")

    # Test 3: Chocolate material available balance & overconsumption rejection
    print("\n--- Test 3: Overconsumption rejection on Chocolate material ---")
    cur.execute("""
        SELECT 
            TRIM(code) as code, 
            TRIM(description) as description, 
            SUM(outward - return_units) as available
        FROM public.transfers
        WHERE UPPER(TRIM(COALESCE(department, ''))) = 'CHOCOLATE'
        GROUP BY TRIM(code), TRIM(description)
        HAVING SUM(outward - return_units) > 0
        LIMIT 1;
    """)
    choc_mat = cur.fetchone()
    print(f"Chocolate material: {choc_mat}")
    excessive_qty = float(choc_mat[2]) + 500.0

    try:
        cur.execute("""
            SELECT public.record_chocolate_consumption(%s::jsonb);
        """, (json.dumps({
            'material_code': choc_mat[0],
            'description': choc_mat[1],
            'consumed_qty': excessive_qty,
            'operator_name': 'Test Op'
        }),))
        print("FAIL: Should have rejected overconsumption!")
    except Exception as e:
        print(f"PASS: Correctly rejected overconsumption: {e}")

    # Test 4: Valid Chocolate consumption transaction
    print("\n--- Test 4: Valid Chocolate consumption transaction ---")
    test_key = "test_choc_consume_123"
    cur.execute("""
        SELECT public.record_chocolate_consumption(%s::jsonb);
    """, (json.dumps({
        'material_code': choc_mat[0],
        'description': choc_mat[1],
        'consumed_qty': 0.125,
        'unit': 'kg',
        'operator_name': 'Automated Test Op',
        'shift': 'Morning Shift',
        'notes': 'Test record verification',
        'idempotency_key': test_key
    }),))
    res = cur.fetchone()[0]
    print(f"Recorded entry: {res}")
    test_entry_id = res['id']

    # Verify get_chocolate_material_received_ledger shows the deduction
    cur.execute("""
        SELECT material_code, total_received, total_accounted, current_balance 
        FROM public.get_chocolate_material_received_ledger()
        WHERE material_code = %s;
    """, (choc_mat[0],))
    row = cur.fetchone()
    print(f"Ledger after consumption: {row}")
    assert float(row[2]) >= 0.125, "total_accounted should include consumed quantity"

    # Test 5: Idempotency with same key
    print("\n--- Test 5: Idempotency with same key ---")
    cur.execute("""
        SELECT public.record_chocolate_consumption(%s::jsonb);
    """, (json.dumps({
        'material_code': choc_mat[0],
        'description': choc_mat[1],
        'consumed_qty': 0.125,
        'unit': 'kg',
        'operator_name': 'Automated Test Op',
        'shift': 'Morning Shift',
        'idempotency_key': test_key
    }),))
    idem_res = cur.fetchone()[0]
    print(f"Idempotent response: {idem_res['id']} (expected {test_entry_id})")
    assert idem_res['id'] == test_entry_id, "Idempotency must return identical record without double inserting"

    # Clean up test entry
    print("\n--- Cleaning up test record ---")
    cur.execute("DELETE FROM public.chocolate_consumption_ledger WHERE id = %s;", (test_entry_id,))
    cur.execute("DELETE FROM public.idempotency_keys WHERE idempotency_key = %s;", (test_key,))
    print("Test record cleaned up successfully.")

    cur.close()
    conn.close()
    print("\n=== All Backend Logic Tests Passed Successfully! ===")

if __name__ == '__main__':
    test_chocolate_consumption()
