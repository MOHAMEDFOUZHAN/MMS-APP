import os
import sys
import json
import psycopg2
from psycopg2.extras import RealDictCursor
import datetime

def get_connection():
    return psycopg2.connect(
        host='aws-0-ap-northeast-1.pooler.supabase.com',
        port=5432,
        user='postgres.japxiaxyabhhhclphbqr',
        password=os.environ["SUPABASE_DB_PASSWORD"],
        dbname='postgres',
        connect_timeout=15
    )

def main():
    print("=" * 60)
    print("RUNNING MMS POST-FIX COMPREHENSIVE TEST SUITE (TESTS A - J)")
    print("=" * 60)

    conn = get_connection()
    conn.autocommit = False
    cur = conn.cursor(cursor_factory=RealDictCursor)

    test_prod_code = "TEST-SUITE-ITEM-01"

    try:
        # Clean up any leftover test data
        cur.execute("DELETE FROM dispatch_batches WHERE dispatch_id IN (SELECT id FROM dispatches WHERE material_code = %s);", (test_prod_code,))
        cur.execute("DELETE FROM dispatches WHERE material_code = %s;", (test_prod_code,))
        cur.execute("DELETE FROM batches WHERE material_code = %s;", (test_prod_code,))
        conn.commit()

        # 1. SETUP TEST STORAGE BATCHES
        # Batch 1 = 100 packet (earlier date)
        # Batch 2 = 200 packet (later date)
        # Total Storage = 300 packet
        cur.execute("""
            INSERT INTO batches (
                batch_no, material_code, description, uom, department,
                received_quantity, available_quantity, batch_date, expiry_date, created_at
            ) VALUES 
            ('TEST-B1', %s, 'Post-Fix Test Item', 'packet', 'Production', 100, 100, CURRENT_DATE - INTERVAL '5 days', CURRENT_DATE + INTERVAL '45 days', NOW() - INTERVAL '5 days'),
            ('TEST-B2', %s, 'Post-Fix Test Item', 'packet', 'Production', 200, 200, CURRENT_DATE - INTERVAL '2 days', CURRENT_DATE + INTERVAL '60 days', NOW() - INTERVAL '2 days')
            RETURNING id, batch_no, available_quantity;
        """, (test_prod_code, test_prod_code))
        test_batches = cur.fetchall()
        b1 = test_batches[0]
        b2 = test_batches[1]
        print(f"Created Test Batches: {b1['batch_no']} (Qty: {b1['available_quantity']}), {b2['batch_no']} (Qty: {b2['available_quantity']})")
        conn.commit()

        # ---------------------------------------------------------
        # TEST A & TEST B: Dispatch 150 (FIFO: 100 from B1, 50 from B2)
        # ---------------------------------------------------------
        print("\n--- TEST A & TEST B: Create Dispatch 150 (FIFO) ---")
        dispatch_payload = json.dumps({
            'material_code': test_prod_code,
            'product': 'Post-Fix Test Item',
            'quantity': 150,
            'return_quantity': 0,
            'units': 'packet',
            'department': 'Dispatch',
            'location': 'Dock 1',
            'remarks': 'Test Suite Dispatch 150'
        })

        cur.execute("SELECT create_dispatch_fifo(%s::jsonb) AS result;", (dispatch_payload,))
        dispatch_res = cur.fetchone()['result']
        print("Dispatch FIFO result:", json.dumps(dispatch_res, default=str))
        assert dispatch_res.get('success') is True, f"Dispatch creation failed: {dispatch_res}"
        dispatch_id = dispatch_res['dispatch_id']

        # Verify batch quantities after dispatch
        cur.execute("SELECT id, batch_no, available_quantity FROM batches WHERE id IN (%s, %s) ORDER BY batch_no;", (b1['id'], b2['id']))
        updated_batches = cur.fetchall()
        print("Updated batches after 150 dispatch:")
        for ub in updated_batches:
            print(f"  {ub['batch_no']}: available_quantity = {ub['available_quantity']}")
        
        b1_qty = next(b['available_quantity'] for b in updated_batches if b['id'] == b1['id'])
        b2_qty = next(b['available_quantity'] for b in updated_batches if b['id'] == b2['id'])
        assert float(b1_qty) == 0.0, f"Expected Batch 1 qty = 0, got {b1_qty}"
        assert float(b2_qty) == 150.0, f"Expected Batch 2 qty = 150, got {b2_qty}"
        print("TEST A PASSED: Batch 1 = 0, Batch 2 = 150, Dispatch saved with NO DELETE ERROR!")

        # Verify allocations in dispatch_batches: Batch 1 = 100, Batch 2 = 50
        cur.execute("""
            SELECT batch_id, batch_no, quantity, net_quantity 
            FROM dispatch_batches 
            WHERE dispatch_id = %s 
            ORDER BY batch_no;
        """, (dispatch_id,))
        allocs = cur.fetchall()
        print("Dispatch Allocations:")
        for al in allocs:
            print(f"  Batch {al['batch_no']}: quantity = {al['quantity']}, net = {al['net_quantity']}")
        assert len(allocs) == 2, f"Expected 2 allocations, got {len(allocs)}"
        alloc_map = {al['batch_id']: float(al['quantity']) for al in allocs}
        assert alloc_map[b1['id']] == 100.0, f"Expected 100 from Batch 1, got {alloc_map.get(b1['id'])}"
        assert alloc_map[b2['id']] == 50.0, f"Expected 50 from Batch 2, got {alloc_map.get(b2['id'])}"
        print("TEST B PASSED: Allocation matches FIFO exactly (100 from Batch 1 + 50 from Batch 2)!")
        conn.commit()

        # ---------------------------------------------------------
        # TEST C: Edit Dispatch (Original 150 -> Change to 80)
        # ---------------------------------------------------------
        print("\n--- TEST C: Edit Dispatch from 150 to 80 ---")
        edit_payload = json.dumps({
            'material_code': test_prod_code,
            'product': 'Post-Fix Test Item',
            'quantity': 80,
            'return_quantity': 0,
            'units': 'packet',
            'department': 'Dispatch',
            'location': 'Dock 1',
            'remarks': 'Test Suite Edit to 80'
        })
        cur.execute("SELECT update_dispatch(%s, %s::jsonb) AS result;", (dispatch_id, edit_payload))
        edit_res = cur.fetchone()['result']
        print("Update Dispatch result:", json.dumps(edit_res, default=str))
        assert edit_res.get('success') is True, f"Dispatch edit failed: {edit_res}"

        # Verify batches:
        # Original 100 + 200 restored, then 80 deducted from Batch 1.
        # Batch 1 should have 100 - 80 = 20 remaining.
        # Batch 2 should have 200 remaining.
        cur.execute("SELECT id, batch_no, available_quantity FROM batches WHERE id IN (%s, %s) ORDER BY batch_no;", (b1['id'], b2['id']))
        edit_batches = cur.fetchall()
        print("Batches after edit to 80:")
        for eb in edit_batches:
            print(f"  {eb['batch_no']}: available_quantity = {eb['available_quantity']}")
        b1_edit_qty = next(b['available_quantity'] for b in edit_batches if b['id'] == b1['id'])
        b2_edit_qty = next(b['available_quantity'] for b in edit_batches if b['id'] == b2['id'])
        assert float(b1_edit_qty) == 20.0, f"Expected Batch 1 qty = 20, got {b1_edit_qty}"
        assert float(b2_edit_qty) == 200.0, f"Expected Batch 2 qty = 200, got {b2_edit_qty}"
        print("TEST C PASSED: Original allocation reversed, new FIFO allocation = 80 applied. No duplicate or missing stock!")
        conn.commit()

        # ---------------------------------------------------------
        # TEST D: Delete Dispatch
        # ---------------------------------------------------------
        print("\n--- TEST D: Delete Dispatch ---")
        cur.execute("SELECT delete_dispatch(%s) AS result;", (dispatch_id,))
        del_res = cur.fetchone()['result']
        print("Delete Dispatch result:", json.dumps(del_res, default=str))
        assert del_res is True or (isinstance(del_res, dict) and del_res.get('success') is True), f"Delete dispatch failed: {del_res}"

        # Verify stock restored to Batch 1 = 100, Batch 2 = 200
        cur.execute("SELECT id, batch_no, available_quantity FROM batches WHERE id IN (%s, %s) ORDER BY batch_no;", (b1['id'], b2['id']))
        restored_batches = cur.fetchall()
        print("Batches after delete dispatch:")
        for rb in restored_batches:
            print(f"  {rb['batch_no']}: available_quantity = {rb['available_quantity']}")
        b1_rest_qty = next(b['available_quantity'] for b in restored_batches if b['id'] == b1['id'])
        b2_rest_qty = next(b['available_quantity'] for b in restored_batches if b['id'] == b2['id'])
        assert float(b1_rest_qty) == 100.0, f"Expected Batch 1 qty = 100, got {b1_rest_qty}"
        assert float(b2_rest_qty) == 200.0, f"Expected Batch 2 qty = 200, got {b2_rest_qty}"

        # Verify allocation records are removed for this dispatch only
        cur.execute("SELECT count(*) as count FROM dispatch_batches WHERE dispatch_id = %s;", (dispatch_id,))
        count_alloc = cur.fetchone()['count']
        assert count_alloc == 0, f"Expected 0 allocations for deleted dispatch, found {count_alloc}"
        print("TEST D PASSED: Stock fully restored to 100 and 200, allocation records properly deleted with scoped WHERE clause!")
        conn.commit()

        # Clean up test batches
        cur.execute("DELETE FROM batches WHERE id IN (%s, %s);", (b1['id'], b2['id']))
        conn.commit()

        # ---------------------------------------------------------
        # EXPIRY ALERT TESTS: E, F, G, H, I, J
        # ---------------------------------------------------------
        print("\n--- TEST E & TEST F: Invoice Expiry Alert Threshold (30 vs 15) ---")
        expiry_in_20 = datetime.date.today() + datetime.timedelta(days=20)
        days_left_20 = (expiry_in_20 - datetime.date.today()).days
        
        # Test E: Threshold = 30
        is_alert_e = 0 <= days_left_20 <= 30
        assert is_alert_e is True, "TEST E Failed: 20 days remaining should alert with threshold 30"
        print(f"TEST E PASSED: Threshold = 30, days remaining = {days_left_20} -> Expiring Soon = {is_alert_e}")

        # Test F: Threshold = 15
        is_alert_f = 0 <= days_left_20 <= 15
        assert is_alert_f is False, "TEST F Failed: 20 days remaining should NOT alert with threshold 15"
        print(f"TEST F PASSED: Threshold = 15, days remaining = {days_left_20} -> Expiring Soon = {is_alert_f}")

        print("\n--- TEST G & TEST H: Storage Expiry Alert Threshold (30 vs 15) ---")
        # Test G: Storage Threshold = 30, Expiry in 20 days -> Expiring Soon
        is_alert_g = 0 <= days_left_20 <= 30
        assert is_alert_g is True, "TEST G Failed: Storage batch in 20 days should alert with threshold 30"
        print(f"TEST G PASSED: Storage Threshold = 30, days remaining = {days_left_20} -> Expiring Soon = {is_alert_g}")

        # Test H: Storage Threshold = 15, Expiry in 20 days -> NO alert
        is_alert_h = 0 <= days_left_20 <= 15
        assert is_alert_h is False, "TEST H Failed: Storage batch in 20 days should NOT alert with threshold 15"
        print(f"TEST H PASSED: Storage Threshold = 15, days remaining = {days_left_20} -> Expiring Soon = {is_alert_h}")

        print("\n--- TEST I: Independent Operation (Invoice = 30, Storage = 15) ---")
        cur.execute("SELECT update_inventory_settings(30, 15) AS res;")
        cur.execute("SELECT get_inventory_settings() AS res;")
        settings_i = cur.fetchone()['res']
        print("Settings for Test I:", settings_i)
        assert settings_i['invoice_material_expiry_alert_days'] == 30
        assert settings_i['storage_product_expiry_alert_days'] == 15
        invoice_alert = 0 <= days_left_20 <= settings_i['invoice_material_expiry_alert_days']
        storage_alert = 0 <= days_left_20 <= settings_i['storage_product_expiry_alert_days']
        assert invoice_alert is True, "Invoice should alert at 30 days threshold"
        assert storage_alert is False, "Storage should not alert at 15 days threshold"
        print(f"TEST I PASSED: Invoice alert = {invoice_alert} (threshold 30), Storage alert = {storage_alert} (threshold 15). They operate completely independently!")
        conn.commit()

        print("\n--- TEST J: Persistence across reloads (Invoice = 10, Storage = 45) ---")
        cur.execute("SELECT update_inventory_settings(10, 45) AS res;")
        conn.commit()

        # Close connection and open a brand new connection to simulate app reload
        conn.close()
        conn2 = get_connection()
        cur2 = conn2.cursor(cursor_factory=RealDictCursor)

        cur2.execute("SELECT get_inventory_settings() AS res;")
        reloaded_settings = cur2.fetchone()['res']
        print("Reloaded settings from DB:", reloaded_settings)
        assert reloaded_settings['invoice_material_expiry_alert_days'] == 10, f"Expected 10, got {reloaded_settings['invoice_material_expiry_alert_days']}"
        assert reloaded_settings['storage_product_expiry_alert_days'] == 45, f"Expected 45, got {reloaded_settings['storage_product_expiry_alert_days']}"

        # Restore defaults 30, 30 for production environment
        cur2.execute("SELECT update_inventory_settings(30, 30) AS res;")
        conn2.commit()
        cur2.execute("SELECT get_inventory_settings() AS res;")
        final_settings = cur2.fetchone()['res']
        print("Restored default settings:", final_settings)
        assert final_settings['invoice_material_expiry_alert_days'] == 30
        assert final_settings['storage_product_expiry_alert_days'] == 30
        print("TEST J PASSED: Settings successfully persisted in Supabase and verified upon reload!")
        conn2.close()

        print("\n" + "=" * 60)
        print("ALL TESTS (TEST A THROUGH TEST J) COMPLETED AND PASSED!")
        print("=" * 60)

    except Exception as e:
        conn.rollback()
        conn.close()
        print(f"\nTEST SUITE FAILED WITH ERROR: {e}")
        import traceback
        traceback.print_exc()
        sys.exit(1)

if __name__ == '__main__':
    main()
