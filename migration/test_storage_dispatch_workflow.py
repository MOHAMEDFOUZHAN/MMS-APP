import os
import psycopg2
import json
import datetime
import threading
import time
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def run_storage_dispatch_tests():
    print("=================================================================")
    print("BENCHMARK MMS - STORAGE + DISPATCH INVENTORY LOGIC TEST SUITE")
    print("=================================================================\n")

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

    test_code = "TEST-PROD-A"
    test_desc = "Benchmark Product A"

    # Cleanup any prior test artifacts
    cur.execute("DELETE FROM dispatch_batches WHERE dispatch_id IN (SELECT id FROM dispatches WHERE material_code = %s);", (test_code,))
    cur.execute("DELETE FROM dispatches WHERE material_code = %s;", (test_code,))
    cur.execute("DELETE FROM batches WHERE material_code = %s;", (test_code,))
    cur.execute("DELETE FROM materials WHERE material_code = %s;", (test_code,))

    # -------------------------------------------------------------------------
    # TEST 1: Multiple Batches for Same Material in Storage
    # -------------------------------------------------------------------------
    print("--- TEST 1: Same Material, Multiple Storage Batches ---")
    cur.execute("""
        INSERT INTO materials (material_code, description, category, unit, quantity, unit_price, opening_stock, reorder_level)
        VALUES (%s, %s, 'Finished Goods', 'kg', 200.000, 50.0, 0, 10);
    """, (test_code, test_desc))

    # Day of year calculation:
    # 01/10/2026 -> day 274
    # 02/10/2026 -> day 275
    b1_date = datetime.date(2026, 10, 1)
    b2_date = datetime.date(2026, 10, 2)
    b1_doy = f"{b1_date.timetuple().tm_yday:03d}"  # 274
    b2_doy = f"{b2_date.timetuple().tm_yday:03d}"  # 275

    cur.execute("""
        INSERT INTO batches (batch_no, material_code, description, received_quantity, available_quantity, uom, department, received_date)
        VALUES (%s, %s, %s, 100.000, 100.000, 'kg', 'Storage A', %s)
        RETURNING id;
    """, (b1_doy, test_code, test_desc, b1_date))
    batch1_id = cur.fetchone()[0]

    cur.execute("""
        INSERT INTO batches (batch_no, material_code, description, received_quantity, available_quantity, uom, department, received_date)
        VALUES (%s, %s, %s, 100.000, 100.000, 'kg', 'Storage B', %s)
        RETURNING id;
    """, (b2_doy, test_code, test_desc, b2_date))
    batch2_id = cur.fetchone()[0]

    # Verify storage batches remain distinct
    cur.execute("SELECT id, batch_no, received_quantity, available_quantity FROM batches WHERE material_code = %s ORDER BY received_date ASC;", (test_code,))
    batches = cur.fetchall()
    assert len(batches) == 2, f"Expected 2 batches, found {len(batches)}"
    assert batches[0][1] == "274" and batches[0][3] == 100.0, f"Batch 1 invalid: {batches[0]}"
    assert batches[1][1] == "275" and batches[1][3] == 100.0, f"Batch 2 invalid: {batches[1]}"

    # Verify materials live stock aggregates them
    cur.execute("SELECT quantity FROM materials WHERE material_code = %s;", (test_code,))
    mat_qty = float(cur.fetchone()[0])
    assert mat_qty == 200.0, f"Expected 200.0, got {mat_qty}"
    print("  [PASS] Storage has 2 distinct batches (Batch 274: 100kg, Batch 275: 100kg)")
    print(f"  [PASS] Materials Live aggregates total stock to {mat_qty} kg\n")

    # -------------------------------------------------------------------------
    # TEST 2: Multi-Batch FIFO Dispatch (150 KG)
    # -------------------------------------------------------------------------
    print("--- TEST 2: Multi-Batch FIFO Dispatch (Request 150 KG) ---")
    payload1 = {
        'material_code': test_code,
        'product': test_desc,
        'quantity': 150.0,
        'units': 'kg',
        'location': 'Factory Counter',
        'department': 'Dispatch',
        'date': '2026-10-02',
        'idempotency_key': 'TEST-IDEMP-001'
    }
    cur.execute("SELECT create_dispatch_fifo(%s::jsonb, %s);", (json.dumps(payload1), 'TEST-IDEMP-001'))
    res1 = cur.fetchone()[0]
    assert res1['success'] is True, f"Dispatch failed: {res1}"
    disp1_id = res1['dispatch_id']
    allocations = res1['allocations']

    print(f"  Created Dispatch #{disp1_id}")
    print(f"  Allocations recorded: {allocations}")

    # Verify allocations in dispatch_batches
    cur.execute("SELECT batch_no, quantity FROM dispatch_batches WHERE dispatch_id = %s ORDER BY id ASC;", (disp1_id,))
    alloc_rows = cur.fetchall()
    assert len(alloc_rows) == 2, f"Expected 2 allocation rows, got {len(alloc_rows)}"
    assert alloc_rows[0][0] == "274" and float(alloc_rows[0][1]) == 100.0, f"Alloc 1 mismatch: {alloc_rows[0]}"
    assert alloc_rows[1][0] == "275" and float(alloc_rows[1][1]) == 50.0, f"Alloc 2 mismatch: {alloc_rows[1]}"

    # Verify batch stocks after dispatch
    cur.execute("SELECT batch_no, received_quantity, available_quantity FROM batches WHERE id = %s;", (batch1_id,))
    b1_row = cur.fetchone()
    assert float(b1_row[1]) == 100.0, f"Received qty was modified! {b1_row[1]}"
    assert float(b1_row[2]) == 0.0, f"Available qty should be 0! {b1_row[2]}"

    cur.execute("SELECT batch_no, received_quantity, available_quantity FROM batches WHERE id = %s;", (batch2_id,))
    b2_row = cur.fetchone()
    assert float(b2_row[1]) == 100.0, f"Received qty was modified! {b2_row[1]}"
    assert float(b2_row[2]) == 50.0, f"Available qty should be 50! {b2_row[2]}"

    cur.execute("SELECT quantity FROM materials WHERE material_code = %s;", (test_code,))
    mat_qty_after = float(cur.fetchone()[0])
    assert mat_qty_after == 50.0, f"Expected 50.0 remaining, got {mat_qty_after}"

    print("  [PASS] Batch 274: Received 100 kg, Available 0 kg (Fully consumed)")
    print("  [PASS] Batch 275: Received 100 kg, Available 50 kg (50 kg consumed)")
    print("  [PASS] Received quantity was NEVER modified")
    print(f"  [PASS] Total material remaining stock: {mat_qty_after} kg\n")

    # -------------------------------------------------------------------------
    # TEST 3: Multi-Batch Continuation Across Multiple Batches
    # -------------------------------------------------------------------------
    print("--- TEST 3: Multi-Batch Continuation Across 3 Batches ---")
    # Add Batch 3 with 200 KG (received on 2026-10-03, Day 276)
    b3_date = datetime.date(2026, 10, 3)
    b3_doy = f"{b3_date.timetuple().tm_yday:03d}"  # 276
    cur.execute("""
        INSERT INTO batches (batch_no, material_code, description, received_quantity, available_quantity, uom, department, received_date)
        VALUES (%s, %s, %s, 200.000, 200.000, 'kg', 'Storage C', %s)
        RETURNING id;
    """, (b3_doy, test_code, test_desc, b3_date))
    batch3_id = cur.fetchone()[0]

    cur.execute("UPDATE materials SET quantity = quantity + 200.0 WHERE material_code = %s;", (test_code,))

    # Available now: Batch 2 (50 KG), Batch 3 (200 KG) = 250 KG total
    # Dispatch 60 KG: Consumes Batch 2 (50 KG) + Batch 3 (10 KG)
    payload2 = {
        'material_code': test_code,
        'product': test_desc,
        'quantity': 60.0,
        'units': 'kg',
        'location': 'Retail Store',
        'department': 'Dispatch',
        'date': '2026-10-03',
        'idempotency_key': 'TEST-IDEMP-002'
    }
    cur.execute("SELECT create_dispatch_fifo(%s::jsonb, %s);", (json.dumps(payload2), 'TEST-IDEMP-002'))
    res2 = cur.fetchone()[0]
    disp2_id = res2['dispatch_id']

    cur.execute("SELECT batch_no, quantity FROM dispatch_batches WHERE dispatch_id = %s ORDER BY id ASC;", (disp2_id,))
    alloc2_rows = cur.fetchall()
    assert len(alloc2_rows) == 2, f"Expected 2 allocation rows, got {len(alloc2_rows)}"
    assert alloc2_rows[0][0] == "275" and float(alloc2_rows[0][1]) == 50.0
    assert alloc2_rows[1][0] == "276" and float(alloc2_rows[1][1]) == 10.0

    cur.execute("SELECT available_quantity FROM batches WHERE id = %s;", (batch2_id,))
    assert float(cur.fetchone()[0]) == 0.0
    cur.execute("SELECT available_quantity FROM batches WHERE id = %s;", (batch3_id,))
    assert float(cur.fetchone()[0]) == 190.0

    print("  [PASS] Dispatch 60 kg continued past Batch 275 (consumed 50 kg) to Batch 276 (consumed 10 kg)")
    print("  [PASS] Batch 275 Available: 0 kg, Batch 276 Available: 190 kg\n")

    # -------------------------------------------------------------------------
    # TEST 4: Insufficient Total Stock Rejection
    # -------------------------------------------------------------------------
    print("--- TEST 4: Insufficient Total Stock Rejection ---")
    # Current available: 190 KG. Request: 250 KG
    payload3 = {
        'material_code': test_code,
        'product': test_desc,
        'quantity': 250.0,
        'units': 'kg',
        'location': 'Export Counter',
        'department': 'Dispatch',
        'date': '2026-10-03',
        'idempotency_key': 'TEST-IDEMP-003'
    }
    rejected = False
    rejection_msg = ""
    try:
        cur.execute("SELECT create_dispatch_fifo(%s::jsonb, %s);", (json.dumps(payload3), 'TEST-IDEMP-003'))
    except Exception as e:
        rejected = True
        rejection_msg = str(e)

    assert rejected, "Dispatch of 250 kg should have been rejected for 190 kg stock!"
    assert "Insufficient stock" in rejection_msg, f"Message lacked 'Insufficient stock': {rejection_msg}"
    assert "Requested: 250" in rejection_msg or "Requested: 250.000" in rejection_msg
    assert "Available: 190" in rejection_msg or "Available: 190.000" in rejection_msg
    assert "Shortage: 60" in rejection_msg or "Shortage: 60.000" in rejection_msg

    # Verify no partial stock updates occurred
    cur.execute("SELECT available_quantity FROM batches WHERE id = %s;", (batch3_id,))
    assert float(cur.fetchone()[0]) == 190.0, "Batch 3 stock was corrupted!"
    cur.execute("SELECT quantity FROM materials WHERE material_code = %s;", (test_code,))
    assert float(cur.fetchone()[0]) == 190.0, "Materials stock was corrupted!"

    print(f"  [PASS] Dispatch correctly rejected with message:\n    \"{rejection_msg.strip()}\"")
    print("  [PASS] Transaction rolled back cleanly: Batch 3 unchanged at 190 kg\n")

    # -------------------------------------------------------------------------
    # TEST 5: Concurrent Dispatch Protection (Row-Level Locking)
    # -------------------------------------------------------------------------
    print("--- TEST 5: Concurrent Dispatch Thread Race Test ---")
    # Current stock = 190 KG. Device A requests 120 KG, Device B requests 100 KG at the same time.
    # Total = 220 KG > 190 KG. Exactly ONE must succeed and the other MUST be rejected.
    results = []

    def dispatch_worker(dev_name, qty, key):
        worker_conn = psycopg2.connect(
            host='aws-0-ap-northeast-1.pooler.supabase.com',
            port=5432,
            user='postgres.japxiaxyabhhhclphbqr',
            password=os.environ["SUPABASE_DB_PASSWORD"],
            dbname='postgres',
            connect_timeout=15
        )
        worker_conn.autocommit = True
        w_cur = worker_conn.cursor()
        p = {
            'material_code': test_code,
            'product': test_desc,
            'quantity': qty,
            'units': 'kg',
            'location': f'{dev_name} counter',
            'department': 'Dispatch',
            'date': '2026-10-03',
            'idempotency_key': key
        }
        try:
            w_cur.execute("SELECT create_dispatch_fifo(%s::jsonb, %s);", (json.dumps(p), key))
            res = w_cur.fetchone()[0]
            results.append((dev_name, True, res))
        except Exception as e:
            results.append((dev_name, False, str(e)))
        finally:
            w_cur.close()
            worker_conn.close()

    t1 = threading.Thread(target=dispatch_worker, args=("Device A", 120.0, "RACE-A-01"))
    t2 = threading.Thread(target=dispatch_worker, args=("Device B", 100.0, "RACE-B-01"))
    t1.start()
    t2.start()
    t1.join()
    t2.join()

    successes = [r for r in results if r[1] is True]
    failures = [r for r in results if r[1] is False]
    assert len(successes) == 1, f"Expected exactly 1 success, got {len(successes)}: {results}"
    assert len(failures) == 1, f"Expected exactly 1 failure, got {len(failures)}: {results}"

    cur.execute("SELECT available_quantity FROM batches WHERE id = %s;", (batch3_id,))
    final_batch3 = float(cur.fetchone()[0])
    assert final_batch3 >= 0, f"Negative stock detected! {final_batch3}"

    print(f"  [PASS] Concurrent race handled safely:")
    print(f"    â€¢ Winner: {successes[0][0]} successfully dispatched")
    print(f"    â€¢ Safely rejected: {failures[0][0]} due to shortage")
    print(f"    â€¢ Batch 3 Available Quantity: {final_batch3} kg (Never negative)\n")

    # -------------------------------------------------------------------------
    # TEST 6: Edit Dispatch (Reversal & FIFO Re-allocation)
    # -------------------------------------------------------------------------
    print("--- TEST 6: Edit Dispatch with Automatic Stock Reversal & Re-allocation ---")
    # Take disp1_id (originally 150 KG from Batch 274: 100kg, Batch 275: 50kg)
    # Edit disp1 to 120 KG
    update_payload = {
        'material_code': test_code,
        'product': test_desc,
        'quantity': 120.0,
        'units': 'kg',
        'location': 'Updated Destination',
        'department': 'Dispatch',
        'date': '2026-10-02'
    }
    cur.execute("SELECT update_dispatch(%s, %s::jsonb);", (disp1_id, json.dumps(update_payload)))
    upd_res = cur.fetchone()[0]
    assert upd_res['success'] is True, f"Update failed: {upd_res}"

    # Verify reallocated batches
    cur.execute("SELECT batch_no, quantity FROM dispatch_batches WHERE dispatch_id = %s ORDER BY id ASC;", (disp1_id,))
    realloc_rows = cur.fetchall()
    print(f"  New batch allocations after edit to 120 kg: {realloc_rows}")
    assert len(realloc_rows) == 2
    assert realloc_rows[0][0] == "274" and float(realloc_rows[0][1]) == 100.0
    assert realloc_rows[1][0] == "275" and float(realloc_rows[1][1]) == 20.0  # 30 kg restored!

    cur.execute("SELECT available_quantity FROM batches WHERE id = %s;", (batch1_id,))
    assert float(cur.fetchone()[0]) == 0.0
    cur.execute("SELECT available_quantity FROM batches WHERE id = %s;", (batch2_id,))
    # Batch 2 originally had 50 allocated in disp1, now only 20, plus 50 was consumed in disp2 -> 100 - 20 - 50 = 30
    assert float(cur.fetchone()[0]) == 30.0

    print("  [PASS] Edit dispatch successfully reversed original allocations")
    print("  [PASS] Batch 274 allocated: 100 kg, Batch 275 allocated: 20 kg (30 kg restored to storage)\n")

    # -------------------------------------------------------------------------
    # TEST 7: Delete Dispatch (Atomic Batch Restoration)
    # -------------------------------------------------------------------------
    print("--- TEST 7: Delete Dispatch (Restores Exact Consumed Batches) ---")
    cur.execute("SELECT delete_dispatch(%s);", (disp1_id,))
    del_res = cur.fetchone()[0]
    assert del_res is True

    # After deleting disp1 (120 kg: 100 from b1, 20 from b2):
    # Batch 1 should have 100 kg restored -> available = 100.0
    # Batch 2 should have 20 kg restored -> available = 30 + 20 = 50.0
    cur.execute("SELECT available_quantity FROM batches WHERE id = %s;", (batch1_id,))
    assert float(cur.fetchone()[0]) == 100.0, f"Expected 100.0 on Batch 1, got {cur.fetchone()}"
    cur.execute("SELECT available_quantity FROM batches WHERE id = %s;", (batch2_id,))
    assert float(cur.fetchone()[0]) == 50.0, f"Expected 50.0 on Batch 2, got {cur.fetchone()}"

    # Verify dispatch and dispatch_batches were deleted
    cur.execute("SELECT COUNT(*) FROM dispatches WHERE id = %s;", (disp1_id,))
    assert cur.fetchone()[0] == 0
    cur.execute("SELECT COUNT(*) FROM dispatch_batches WHERE dispatch_id = %s;", (disp1_id,))
    assert cur.fetchone()[0] == 0

    print("  [PASS] Dispatch #1 deleted cleanly")
    print("  [PASS] Batch 274 restored to 100 kg, Batch 275 restored to 50 kg\n")

    # -------------------------------------------------------------------------
    # TEST 8: Realtime Publications & Triggers Verification
    # -------------------------------------------------------------------------
    print("--- TEST 8: Realtime Verification ---")
    cur.execute("SELECT tablename FROM pg_publication_tables WHERE pubname = 'supabase_realtime';")
    pub_tables = {r[0] for r in cur.fetchall()}
    for req_table in ['batches', 'dispatches', 'dispatch_batches', 'materials']:
        assert req_table in pub_tables, f"Table {req_table} is missing from supabase_realtime publication!"
        print(f"  [PASS] Table '{req_table}' is actively replicated via supabase_realtime")

    # Clean up test records
    cur.execute("DELETE FROM dispatch_batches WHERE dispatch_id IN (SELECT id FROM dispatches WHERE material_code = %s);", (test_code,))
    cur.execute("DELETE FROM dispatches WHERE material_code = %s;", (test_code,))
    cur.execute("DELETE FROM batches WHERE material_code = %s;", (test_code,))
    cur.execute("DELETE FROM materials WHERE material_code = %s;", (test_code,))
    cur.close()
    conn.close()

    print("\n=================================================================")
    print("ALL 8 BENCHMARK MMS STORAGE & DISPATCH TESTS PASSED PERFECTLY!")
    print("=================================================================")

if __name__ == '__main__':
    run_storage_dispatch_tests()
