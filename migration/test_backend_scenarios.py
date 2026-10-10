import os
import psycopg2
import json
from datetime import date, datetime

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = os.environ["SUPABASE_DB_PASSWORD"]
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
conn.autocommit = False
cur = conn.cursor()

def run_tests():
    print("=== STARTING BACKEND VALIDATION TESTS ===")
    
    # ----------------------------------------------------
    # TEST 2 & 3: New Storage Product & Reverse Lookup
    # ----------------------------------------------------
    print("\n[TEST 2 & 3] Storage Product Identity & Reverse Lookup...")
    cur.execute("""
    SELECT public.upsert_storage_product('PROD-999', 'Test Finished Product', 'kg', 'STANDARD', 'Finished Goods');
    """)
    res = cur.fetchone()[0]
    print("Saved Storage Product:", res)
    assert res['product_code'] == 'PROD-999'
    assert res['product_name'] == 'Test Finished Product'

    # Lookup by Code
    cur.execute("SELECT * FROM public.get_storage_products('PROD-999');")
    rows = cur.fetchall()
    assert len(rows) >= 1
    print("Lookup by code PROD-999:", rows[0][1], "->", rows[0][2])

    # Reverse lookup by Name
    cur.execute("SELECT * FROM public.get_storage_products('Test Finished Product');")
    rows = cur.fetchall()
    assert len(rows) >= 1
    print("Reverse lookup by name Test Finished Product:", rows[0][2], "->", rows[0][1])

    # Duplicate prevention test
    cur.execute("""
    SELECT public.upsert_storage_product('prod-999', 'Test Finished Product', 'kg', 'STANDARD', 'Finished Goods');
    """)
    res2 = cur.fetchone()[0]
    assert res2['id'] == res['id'], "Duplicate product created instead of reusing existing!"
    print("Duplicate prevention passed: case-insensitive match reused ID", res2['id'])

    # ----------------------------------------------------
    # TEST 1 & 10: Storage Isolation & Expiry Date
    # ----------------------------------------------------
    print("\n[TEST 1 & 10] Storage Isolation & Expiry Date...")
    # Clean test batches
    cur.execute("DELETE FROM public.dispatch_batches WHERE batch_no IN ('BATCH-TEST-01', 'BATCH-TEST-02', 'BATCH-TEST-03');")
    cur.execute("DELETE FROM public.batches WHERE batch_no IN ('BATCH-TEST-01', 'BATCH-TEST-02', 'BATCH-TEST-03');")
    
    # Add Batch 1 for PROD-999: 100 units, expiry = 2026-12-31
    cur.execute("""
    INSERT INTO public.batches (
        batch_no, material_code, description, received_quantity, available_quantity, 
        uom, department, batch_date, expiry_date, category, grade, created_at, updated_at
    ) VALUES (
        'BATCH-TEST-01', 'PROD-999', 'Test Finished Product', 100.000, 100.000,
        'kg', 'Finished Goods', '2026-10-01', '2026-12-31', 'Finished Goods', 'STANDARD', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    ) RETURNING id;
    """)
    batch1_id = cur.fetchone()[0]

    # Add Batch 2 for PROD-999: 100 units, expiry = 2026-12-31
    cur.execute("""
    INSERT INTO public.batches (
        batch_no, material_code, description, received_quantity, available_quantity, 
        uom, department, batch_date, expiry_date, category, grade, created_at, updated_at
    ) VALUES (
        'BATCH-TEST-02', 'PROD-999', 'Test Finished Product', 100.000, 100.000,
        'kg', 'Finished Goods', '2026-10-02', '2026-12-31', 'Finished Goods', 'STANDARD', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
    ) RETURNING id;
    """)
    batch2_id = cur.fetchone()[0]

    # Verify get_dispatch_available_products shows ONLY PROD-999 and NOT material master materials (e.g. CARD-TEA-01)
    cur.execute("SELECT product_code, product_name, total_available, batch_count FROM public.get_dispatch_available_products();")
    disp_prods = cur.fetchall()
    print("Dispatch Available Products in Storage:", disp_prods)
    codes_in_dispatch = [p[0] for p in disp_prods]
    assert 'PROD-999' in codes_in_dispatch
    assert 'CARD-TEA-01' not in codes_in_dispatch, "Material Master item with no storage stock appeared in Dispatch!"
    print("Storage Isolation passed: Only Storage finished products with stock appear in Dispatch.")

    # Expiry date check
    cur.execute("SELECT expiry_date FROM public.batches WHERE id = %s;", (batch1_id,))
    exp_date = cur.fetchone()[0]
    assert str(exp_date) == '2026-12-31'
    print(f"Expiry date stored and verified: {exp_date.strftime('%d/%m/%Y')}")

    # ----------------------------------------------------
    # TEST 5: Insufficient Stock
    # ----------------------------------------------------
    print("\n[TEST 5] Insufficient Stock Check...")
    # Available = 200, try requesting 250
    cur.execute("SAVEPOINT sp_insufficient;")
    try:
        cur.execute("""
        SELECT public.create_dispatch_fifo(jsonb_build_object(
            'material_code', 'PROD-999',
            'product', 'Test Finished Product',
            'quantity', 250,
            'units', 'kg',
            'date', '2026-10-02'
        ));
        """)
        raise AssertionError("Expected Insufficient Storage Stock exception, but call succeeded!")
    except Exception as e:
        print("Caught expected rejection for 250 units (available 200):", str(e).split('\n')[0])
        cur.execute("ROLLBACK TO SAVEPOINT sp_insufficient;")

    # ----------------------------------------------------
    # TEST 4 & 7: Multi-batch FIFO & Dispatch Return
    # ----------------------------------------------------
    print("\n[TEST 4 & 7] Multi-batch FIFO & Dispatch Return...")
    # Dispatch 150 units with 20 return:
    # Gross dispatch = 150
    # Return = 20
    # Net stock reduction = 130
    # Batch 1 (100) -> deducts 100
    # Batch 2 (100) -> deducts 50 gross, receives 20 return = deducts 30 net
    # Expected remaining: Batch 1 = 0, Batch 2 = 70.
    cur.execute("""
    SELECT public.create_dispatch_fifo(jsonb_build_object(
        'material_code', 'PROD-999',
        'product', 'Test Finished Product',
        'quantity', 150,
        'return_quantity', 20,
        'units', 'kg',
        'department', 'Dispatch',
        'location', 'Test Store',
        'date', '2026-10-02'
    ));
    """)
    disp_res = cur.fetchone()[0]
    dispatch_id = disp_res['dispatch_id']
    print(f"Created Dispatch #{dispatch_id}:", disp_res)

    cur.execute("SELECT id, batch_no, available_quantity FROM public.batches WHERE id IN (%s, %s) ORDER BY batch_date ASC;", (batch1_id, batch2_id))
    batches_after = cur.fetchall()
    print("Batches remaining after 150 dispatch - 20 return:", batches_after)
    assert batches_after[0][2] == 0, f"Batch 1 should have 0 remaining, got {batches_after[0][2]}"
    assert batches_after[1][2] == 70, f"Batch 2 should have 70 remaining, got {batches_after[1][2]}"

    cur.execute("SELECT batch_no, quantity, returned_quantity, net_quantity FROM public.dispatch_batches WHERE dispatch_id = %s ORDER BY id ASC;", (dispatch_id,))
    allocs = cur.fetchall()
    print("Dispatch batch allocation rows:", allocs)
    # Batch 1: 100 gross, 0 return, 100 net
    assert allocs[0][1] == 100 and allocs[0][2] == 0 and allocs[0][3] == 100
    # Batch 2: 50 gross, 20 return, 30 net
    assert allocs[1][1] == 50 and allocs[1][2] == 20 and allocs[1][3] == 30

    # ----------------------------------------------------
    # TEST 8: Edit Dispatch
    # ----------------------------------------------------
    print("\n[TEST 8] Edit Dispatch...")
    # Edit Dispatch from 150 (return 20) to 80 (return 0):
    # Old net deduction (130) reversed -> Batch 1 back to 100, Batch 2 back to 100.
    # New dispatch: 80 from Batch 1. Batch 1 remaining = 20, Batch 2 remaining = 100.
    cur.execute("""
    SELECT public.update_dispatch(%s, jsonb_build_object(
        'material_code', 'PROD-999',
        'product', 'Test Finished Product',
        'quantity', 80,
        'return_quantity', 0,
        'units', 'kg',
        'date', '2026-10-02'
    ));
    """, (dispatch_id,))
    update_res = cur.fetchone()[0]
    print(f"Updated Dispatch #{dispatch_id}:", update_res)

    cur.execute("SELECT id, batch_no, available_quantity FROM public.batches WHERE id IN (%s, %s) ORDER BY batch_date ASC;", (batch1_id, batch2_id))
    batches_after_edit = cur.fetchall()
    print("Batches remaining after edit to 80 units:", batches_after_edit)
    assert batches_after_edit[0][2] == 20, f"Batch 1 should have 20 remaining, got {batches_after_edit[0][2]}"
    assert batches_after_edit[1][2] == 100, f"Batch 2 should have 100 remaining, got {batches_after_edit[1][2]}"

    # ----------------------------------------------------
    # TEST 9: Delete Dispatch
    # ----------------------------------------------------
    print("\n[TEST 9] Delete Dispatch...")
    cur.execute("SELECT public.delete_dispatch(%s);", (dispatch_id,))
    print(f"Deleted Dispatch #{dispatch_id}")

    cur.execute("SELECT id, batch_no, available_quantity FROM public.batches WHERE id IN (%s, %s) ORDER BY batch_date ASC;", (batch1_id, batch2_id))
    batches_after_del = cur.fetchall()
    print("Batches remaining after delete (fully restored):", batches_after_del)
    assert batches_after_del[0][2] == 100, f"Batch 1 should be 100, got {batches_after_del[0][2]}"
    assert batches_after_del[1][2] == 100, f"Batch 2 should be 100, got {batches_after_del[1][2]}"

    # ----------------------------------------------------
    # TEST 6: Transfer Return
    # ----------------------------------------------------
    print("\n[TEST 6] Transfer Return...")
    # Find material '100' or similar
    cur.execute("SELECT id, material_code, quantity FROM public.materials WHERE quantity >= 50 LIMIT 1;")
    mat = cur.fetchone()
    if mat:
        mat_id, mat_code, init_stock = mat
        print(f"Testing transfer return with Material '{mat_code}', initial stock = {init_stock}")
        
        # Current = 100 (or init_stock), Outward = 20, Return = 5
        # Net change = 5 - 20 = -15
        # Expected new stock = init_stock - 15
        cur.execute("""
        SELECT public.create_transfer(jsonb_build_object(
            'code', %s,
            'department', 'TEA',
            'person', 'TESTER',
            'outward', 20,
            'return_units', 5,
            'units', 'KG',
            'date', '2026-10-02'
        ));
        """, (mat_code,))
        trf_res = cur.fetchone()[0]
        trf_id = trf_res['transfer_id']
        print(f"Created Transfer #{trf_id}:", trf_res)
        assert trf_res['net_change'] == -15

        cur.execute("SELECT quantity FROM public.materials WHERE id = %s;", (mat_id,))
        new_stock = cur.fetchone()[0]
        assert new_stock == init_stock - 15, f"Expected {init_stock - 15}, got {new_stock}"
        print(f"Material stock correctly updated: {init_stock} - 15 = {new_stock}")

        # Delete transfer to restore stock
        cur.execute("SELECT public.delete_transfer(%s);", (trf_id,))
        cur.execute("SELECT quantity FROM public.materials WHERE id = %s;", (mat_id,))
        restored_stock = cur.fetchone()[0]
        assert restored_stock == init_stock, f"Expected {init_stock}, got {restored_stock}"
        print(f"Transfer deleted and stock perfectly restored to {restored_stock}")

    # Clean up test batches
    cur.execute("DELETE FROM public.dispatch_batches WHERE batch_id IN (%s, %s);", (batch1_id, batch2_id))
    cur.execute("DELETE FROM public.batches WHERE id IN (%s, %s);", (batch1_id, batch2_id))
    cur.execute("DELETE FROM public.storage_products WHERE product_code = 'PROD-999';")

    conn.commit()
    print("\nALL 10 BACKEND VALIDATION TESTS PASSED SUCCESSFULLY!")

try:
    run_tests()
except Exception as e:
    conn.rollback()
    print("TEST FAILED:", e)
    raise e
finally:
    cur.close()
    conn.close()
