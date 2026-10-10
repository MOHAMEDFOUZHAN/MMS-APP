import os
import psycopg2
import psycopg2.extras
from datetime import datetime, date, timedelta
import sys

def run_tests():
    print("=== STARTING MMS STORAGE, FIFO TIMESTAMP & DAILY MATERIAL VERIFICATION ===")
    conn = psycopg2.connect(
        host='aws-0-ap-northeast-1.pooler.supabase.com',
        port=5432,
        user='postgres.japxiaxyabhhhclphbqr',
        password=os.environ["SUPABASE_DB_PASSWORD"],
        dbname='postgres',
        connect_timeout=15
    )
    conn.autocommit = False
    cur = conn.cursor(cursor_factory=psycopg2.extras.DictCursor)

    try:
        # TEST 1: Same-Day FIFO Ordering with exact timestamp
        print("\n--- TEST 1: Same-Day FIFO Ordering with exact timestamp ---")
        test_product = 'TEST_FIFO_PROD_99'
        test_code = 'FG-FIFO-99'
        cur.execute("""
            SELECT public.upsert_storage_product(%s, %s, 'packet', 'STANDARD', 'Finished Goods');
        """, (test_code, test_product))

        # Create two batches with identical batch number on same day but different timestamps
        d1 = datetime(2026, 10, 2, 9, 0, 0)
        d2 = datetime(2026, 10, 2, 14, 0, 0)

        cur.execute("""
            INSERT INTO public.batches (
                material_code, description, batch_no, batch_date, received_date,
                received_quantity, available_quantity, uom, department,
                received_at, created_at
            ) VALUES 
            (%s, %s, '275', '2026-10-02', '2026-10-02', 100.0, 100.0, 'packet', 'Finished Goods', %s, %s)
            RETURNING id;
        """, (test_code, test_product, d1, d1))
        batch1_id = cur.fetchone()['id']

        cur.execute("""
            INSERT INTO public.batches (
                material_code, description, batch_no, batch_date, received_date,
                received_quantity, available_quantity, uom, department,
                received_at, created_at
            ) VALUES 
            (%s, %s, '275', '2026-10-02', '2026-10-02', 200.0, 200.0, 'packet', 'Finished Goods', %s, %s)
            RETURNING id;
        """, (test_code, test_product, d2, d2))
        batch2_id = cur.fetchone()['id']

        print(f"Created Batch 1 (09:00 AM) ID: {batch1_id}, Batch 2 (02:00 PM) ID: {batch2_id}")

        # Check get_storage_dispatch_preview returns them in timestamp order
        cur.execute("""
            SELECT public.get_storage_dispatch_preview(p_material_code := %s, p_requested_quantity := 150.0);
        """, (test_code,))
        res = cur.fetchone()[0]
        preview_allocs = res.get('fifo_allocations', [])
        print("Dispatch preview allocations:")
        for r in preview_allocs:
            print(f"  Batch {r['batch_no']} (ID {r['batch_id']}): allocated={r['allocated_quantity']}, batch_remaining={r['batch_remaining']}")
        
        assert len(preview_allocs) == 2, f"Expected 2 batches in preview, got {len(preview_allocs)}"
        assert preview_allocs[0]['batch_id'] == batch1_id, f"Expected batch1 first, got {preview_allocs[0]['batch_id']}"
        assert float(preview_allocs[0]['allocated_quantity']) == 100.0, f"Expected 100.0 from batch1, got {preview_allocs[0]['allocated_quantity']}"
        assert preview_allocs[1]['batch_id'] == batch2_id, f"Expected batch2 second, got {preview_allocs[1]['batch_id']}"
        assert float(preview_allocs[1]['allocated_quantity']) == 50.0, f"Expected 50.0 from batch2, got {preview_allocs[1]['allocated_quantity']}"
        print("PASS: Dispatch preview correctly ordered same-day entries by timestamp!")

        # Perform actual dispatch of 150 packet
        cur.execute("""
            SELECT public.create_dispatch_fifo(
                jsonb_build_object(
                    'date', '2026-10-02',
                    'material_code', %s,
                    'product', %s,
                    'quantity', 150.0,
                    'units', 'packet',
                    'location', 'Warehouse A',
                    'department', 'Dispatch',
                    'remarks', 'Test FIFO dispatch'
                )
            );
        """, (test_code, test_product))
        dispatch_res = cur.fetchone()[0]
        dispatch_id = dispatch_res['dispatch_id']
        print(f"Created Dispatch #{dispatch_id}, success: {dispatch_res.get('success')}")

        # Verify batch quantities
        cur.execute("SELECT id, received_quantity, available_quantity FROM public.batches WHERE id IN (%s, %s) ORDER BY id;", (batch1_id, batch2_id))
        rows = cur.fetchall()
        b1_stat = [r for r in rows if r['id'] == batch1_id][0]
        b2_stat = [r for r in rows if r['id'] == batch2_id][0]
        print(f"After dispatch: Batch 1 available={b1_stat['available_quantity']}, Batch 2 available={b2_stat['available_quantity']}")
        assert b1_stat['available_quantity'] == 0.0, f"Expected 0.0 available for batch 1, got {b1_stat['available_quantity']}"
        assert b2_stat['available_quantity'] == 150.0, f"Expected 150.0 available for batch 2, got {b2_stat['available_quantity']}"
        print("PASS: Batch quantities updated accurately!")

        # TEST 2: Storage Current View vs All History
        print("\n--- TEST 2: Storage Current View vs All History ---")
        # Current Storage query: available_quantity > 0.0001
        cur.execute("""
            SELECT id, batch_no, available_quantity FROM public.batches 
            WHERE material_code = %s AND available_quantity > 0.0001;
        """, (test_code,))
        current_view_batches = cur.fetchall()
        current_ids = [r['id'] for r in current_view_batches]
        print(f"Current Stock batches: {current_ids}")
        assert batch1_id not in current_ids, "Batch 1 (qty 0) MUST NOT appear in current stock view!"
        assert batch2_id in current_ids, "Batch 2 (qty 150) MUST appear in current stock view!"

        # All History query: all batches
        cur.execute("""
            SELECT id, batch_no, available_quantity FROM public.batches 
            WHERE material_code = %s ORDER BY id;
        """, (test_code,))
        all_history_batches = cur.fetchall()
        history_ids = [r['id'] for r in all_history_batches]
        print(f"All History batches: {history_ids}")
        assert batch1_id in history_ids, "Batch 1 MUST remain in all history!"
        assert batch2_id in history_ids, "Batch 2 MUST remain in all history!"
        print("PASS: Current Stock hides 0-qty batch while All History retains it permanently!")

        # TEST 3: Materials Live Continuous Daily Opening/Closing Chain
        print("\n--- TEST 3: Materials Live Daily Opening/Closing Chain ---")
        test_mat_code = 'RAW-TEST-DAILY-99'
        cur.execute("""
            INSERT INTO public.materials (material_code, description, category, unit, opening_stock, quantity)
            VALUES (%s, 'Test Daily Material', 'Test Cat', 'kg', 100.0, 100.0)
            ON CONFLICT (material_code) DO NOTHING
            RETURNING id;
        """, (test_mat_code,))
        mat_res = cur.fetchone()
        if mat_res:
            mat_id = mat_res['id']
        else:
            cur.execute("SELECT id FROM public.materials WHERE material_code = %s;", (test_mat_code,))
            mat_id = cur.fetchone()['id']

        # Clean prior test transactions for this material
        cur.execute("DELETE FROM public.invoice_items WHERE material = %s;", (test_mat_code,))
        cur.execute("DELETE FROM public.invoices WHERE invoice_no IN ('INV-DAY-1', 'INV-DAY-2');")
        cur.execute("DELETE FROM public.transfers WHERE code = %s;", (test_mat_code,))

        # Day 1: 2026-09-01
        # Purchase = 30
        # Transfer Out = 10
        # Return In = 5
        # Expected Closing = 100 + 30 - 10 + 5 = 125
        cur.execute("""
            INSERT INTO public.invoices (invoice_no, date, vendor, grand_total, payment_status)
            VALUES ('INV-DAY-1', '2026-09-01', 'Test Vendor', 300.0, 'Paid')
            RETURNING id;
        """)
        inv_id = cur.fetchone()['id']
        cur.execute("""
            INSERT INTO public.invoice_items (invoice_id, material, quantity, unit, unit_price, item_total)
            VALUES (%s, %s, 30.0, 'kg', 10.0, 300.0);
        """, (inv_id, test_mat_code))

        # Transfer Out = 10 on Day 1
        cur.execute("""
            INSERT INTO public.transfers (date, code, description, outward, return_units, department, person)
            VALUES ('2026-09-01', %s, 'Test Daily Material', 10.0, 0.0, 'Production', 'Worker A');
        """, (test_mat_code,))

        # Return In = 5 on Day 1
        cur.execute("""
            INSERT INTO public.transfers (date, code, description, outward, return_units, department, person)
            VALUES ('2026-09-01', %s, 'Test Daily Material', 0.0, 5.0, 'Production', 'Worker A');
        """, (test_mat_code,))

        # Query summary for Day 1 (2026-09-01)
        cur.execute("""
            SELECT * FROM public.get_live_materials_summary(
                p_search := %s,
                p_from_date := '2026-09-01',
                p_to_date := '2026-09-01'
            );
        """, (test_mat_code,))
        day1 = cur.fetchone()
        print("Day 1 (2026-09-01) Summary:")
        print(f"  Opening: {day1['opening_stock']}, Purchased: {day1['purchased']}, Transfer Out: {day1['transfer_out']}, Return In: {day1['return_in']}, Closing: {day1['closing_stock']}")
        assert float(day1['opening_stock']) == 100.0, f"Expected opening 100.0, got {day1['opening_stock']}"
        assert float(day1['purchased']) == 30.0, f"Expected purchased 30.0, got {day1['purchased']}"
        assert float(day1['transfer_out']) == 10.0, f"Expected transfer out 10.0, got {day1['transfer_out']}"
        assert float(day1['return_in']) == 5.0, f"Expected return in 5.0, got {day1['return_in']}"
        assert float(day1['closing_stock']) == 125.0, f"Expected closing 125.0, got {day1['closing_stock']}"

        # Query summary for Day 2 (2026-09-02) with NO new transactions yet
        cur.execute("""
            SELECT * FROM public.get_live_materials_summary(
                p_search := %s,
                p_from_date := '2026-09-02',
                p_to_date := '2026-09-02'
            );
        """, (test_mat_code,))
        day2 = cur.fetchone()
        print("\nDay 2 (2026-09-02) Summary (Before any Day 2 transactions):")
        print(f"  Opening: {day2['opening_stock']}, Purchased: {day2['purchased']}, Transfer Out: {day2['transfer_out']}, Return In: {day2['return_in']}, Closing: {day2['closing_stock']}")
        assert float(day2['opening_stock']) == 125.0, f"Expected opening 125.0, got {day2['opening_stock']}"
        assert float(day2['purchased']) == 0.0, f"Expected purchased 0.0, got {day2['purchased']}"
        assert float(day2['transfer_out']) == 0.0, f"Expected transfer out 0.0, got {day2['transfer_out']}"
        assert float(day2['return_in']) == 0.0, f"Expected return in 0.0, got {day2['return_in']}"
        assert float(day2['closing_stock']) == 125.0, f"Expected closing 125.0, got {day2['closing_stock']}"
        print("PASS: Day 2 Opening equals Day 1 Closing (125.0), and daily in/out reset to 0.0!")

        # Now simulate Day 2 purchase of 20
        cur.execute("""
            INSERT INTO public.invoices (invoice_no, date, vendor, grand_total, payment_status)
            VALUES ('INV-DAY-2', '2026-09-02', 'Test Vendor', 200.0, 'Paid')
            RETURNING id;
        """)
        inv2_id = cur.fetchone()['id']
        cur.execute("""
            INSERT INTO public.invoice_items (invoice_id, material, quantity, unit, unit_price, item_total)
            VALUES (%s, %s, 20.0, 'kg', 10.0, 200.0);
        """, (inv2_id, test_mat_code))

        cur.execute("""
            SELECT * FROM public.get_live_materials_summary(
                p_search := %s,
                p_from_date := '2026-09-02',
                p_to_date := '2026-09-02'
            );
        """, (test_mat_code,))
        day2_after = cur.fetchone()
        print("\nDay 2 (2026-09-02) Summary (After 20 purchase):")
        print(f"  Opening: {day2_after['opening_stock']}, Purchased: {day2_after['purchased']}, Transfer Out: {day2_after['transfer_out']}, Return In: {day2_after['return_in']}, Closing: {day2_after['closing_stock']}")
        assert float(day2_after['opening_stock']) == 125.0
        assert float(day2_after['purchased']) == 20.0
        assert float(day2_after['closing_stock']) == 145.0
        print("PASS: Day 2 Closing updated to 145.0!")

        # Query summary for Day 3 (2026-09-03)
        cur.execute("""
            SELECT * FROM public.get_live_materials_summary(
                p_search := %s,
                p_from_date := '2026-09-03',
                p_to_date := '2026-09-03'
            );
        """, (test_mat_code,))
        day3 = cur.fetchone()
        print("\nDay 3 (2026-09-03) Summary:")
        print(f"  Opening: {day3['opening_stock']}, Purchased: {day3['purchased']}, Transfer Out: {day3['transfer_out']}, Return In: {day3['return_in']}, Closing: {day3['closing_stock']}")
        assert float(day3['opening_stock']) == 145.0, f"Expected opening 145.0, got {day3['opening_stock']}"
        assert float(day3['purchased']) == 0.0
        assert float(day3['transfer_out']) == 0.0
        assert float(day3['return_in']) == 0.0
        assert float(day3['closing_stock']) == 145.0
        print("PASS: Day 3 continuous chain verified successfully!")

        # Clean up test records
        cur.execute("DELETE FROM public.dispatch_batches WHERE dispatch_id = %s;", (dispatch_id,))
        cur.execute("DELETE FROM public.dispatches WHERE id = %s;", (dispatch_id,))
        cur.execute("DELETE FROM public.batches WHERE id IN (%s, %s);", (batch1_id, batch2_id))
        cur.execute("DELETE FROM public.storage_products WHERE product_code = %s;", (test_code,))
        cur.execute("DELETE FROM public.invoice_items WHERE material = %s;", (test_mat_code,))
        cur.execute("DELETE FROM public.invoices WHERE invoice_no IN ('INV-DAY-1', 'INV-DAY-2');")
        cur.execute("DELETE FROM public.transfers WHERE code = %s;", (test_mat_code,))
        cur.execute("DELETE FROM public.materials WHERE material_code = %s;", (test_mat_code,))
        conn.commit()

        print("\n=== ALL DATABASE TESTS PASSED WITH 100% SUCCESS ===")

    except Exception as e:
        conn.rollback()
        print(f"\nERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)
    finally:
        cur.close()
        conn.close()

if __name__ == '__main__':
    run_tests()
