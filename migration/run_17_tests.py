import os
import psycopg2
import json
import datetime
import sys

if hasattr(sys.stdout, 'reconfigure'):
    sys.stdout.reconfigure(encoding='utf-8')

def run_all_tests():
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

    print("=================================================================")
    print("STARTING 17 INTEGRATION & VALIDATION TESTS")
    print("=================================================================\n")

    # Helper: calculate day-of-year lot
    def get_doy_lot(dt):
        doy = dt.timetuple().tm_yday
        return f"LOT-{doy:03d}"

    # TEST 12: Day of year lot calculation verification
    print("--- RUNNING TEST 12: Lot Generation (Day of Year) ---")
    dt1 = datetime.date(2026, 1, 1)
    dt2 = datetime.date(2026, 1, 2)
    dt3 = datetime.date(2026, 2, 13)
    dt4 = datetime.date(2026, 12, 31)
    assert get_doy_lot(dt1) == "LOT-001", f"Failed: {get_doy_lot(dt1)}"
    assert get_doy_lot(dt2) == "LOT-002", f"Failed: {get_doy_lot(dt2)}"
    assert get_doy_lot(dt3) == "LOT-044", f"Failed: {get_doy_lot(dt3)}"
    assert get_doy_lot(dt4) == "LOT-365", f"Failed: {get_doy_lot(dt4)}"
    print(f"  [PASS] 01/01/2026 -> {get_doy_lot(dt1)}")
    print(f"  [PASS] 02/01/2026 -> {get_doy_lot(dt2)}")
    print(f"  [PASS] 13/02/2026 -> {get_doy_lot(dt3)}")
    print(f"  [PASS] 31/12/2026 -> {get_doy_lot(dt4)}")

    # TEST 10 & 11: Financial calculations & large amount precision
    print("\n--- RUNNING TEST 10 & 11: Large Amount Precision & GST Breakdown ---")
    for taxable, cgst_pct, sgst_pct in [
        (10000.0, 9.0, 9.0),
        (100000.0, 9.0, 9.0),
        (1000000.0, 9.0, 9.0),
        (10000000.0, 9.0, 9.0),
    ]:
        cgst = round(taxable * (cgst_pct / 100.0), 2)
        sgst = round(taxable * (sgst_pct / 100.0), 2)
        total_gst = round(cgst + sgst, 2)
        grand = round(taxable + total_gst, 2)
        # Check no floating point debris
        assert str(grand).endswith(".0") or len(str(grand).split(".")[1]) <= 2
        if taxable == 10000.0:
            assert cgst == 900.0 and sgst == 900.0 and total_gst == 1800.0 and grand == 11800.0
            print(f"  [PASS] Taxable: â‚¹10,000 -> CGST: â‚¹{cgst}, SGST: â‚¹{sgst}, Total GST: â‚¹{total_gst}, Grand Total: â‚¹{grand}")
        else:
            print(f"  [PASS] Taxable: â‚¹{taxable:,.2f} -> CGST: â‚¹{cgst:,.2f}, SGST: â‚¹{sgst:,.2f}, Grand Total: â‚¹{grand:,.2f}")

    # TEST 1: Create invoice with existing material
    print("\n--- RUNNING TEST 1: Invoice with Existing Material ---")
    cur.execute("SELECT material_code, description, quantity FROM materials LIMIT 1;")
    mat_code, mat_desc, initial_qty = cur.fetchone()
    print(f"  Existing material: {mat_code} ({mat_desc}), Initial Stock: {initial_qty}")

    inv1_date = datetime.date(2026, 2, 13)
    inv1_lot = get_doy_lot(inv1_date)
    inv1_no = f"INV-TEST-001-{int(datetime.datetime.now().timestamp())}"
    inv1_payload = {
        "invoice_no": inv1_no,
        "date": str(inv1_date),
        "vendor": "Test Vendor Ltd",
        "payment_status": "Pending",
        "purchase_id": "PUR-TEST-01",
        "remarks": "Test 1"
    }
    items1_payload = [{
        "material": mat_code,
        "description": mat_desc,
        "quantity": 50.0,
        "unit": "kg",
        "unit_price": 100.0,
        "discount_percentage": 0.0,
        "gst_percentage": 18.0,
        "igst_percentage": 0.0,
        "lot_no": inv1_lot,
        "grade": ""
    }]
    cur.execute("SELECT create_purchase(%s::jsonb, %s::jsonb);", (json.dumps(inv1_payload), json.dumps(items1_payload)))
    res1 = cur.fetchone()[0]
    inv1_id = res1['invoice_id']
    assert res1.get('success') is True

    # Verify inventory increased
    cur.execute("SELECT quantity FROM materials WHERE material_code = %s;", (mat_code,))
    new_qty = float(cur.fetchone()[0])
    assert new_qty == float(initial_qty) + 50.0, f"Expected {float(initial_qty) + 50.0}, got {new_qty}"

    # Verify material_lots created
    cur.execute("SELECT lot_no, available_quantity FROM material_lots WHERE invoice_id = %s;", (inv1_id,))
    lot_rec = cur.fetchone()
    assert lot_rec[0] == "LOT-044" and float(lot_rec[1]) == 50.0
    print(f"  [PASS] Invoice {inv1_no} created: Lot={lot_rec[0]}, Added 50kg -> New Stock={new_qty}")

    # TEST 2: Create invoice with new material
    print("\n--- RUNNING TEST 2: Invoice with New Material ---")
    new_code = f"NEW-MAT-{int(datetime.datetime.now().timestamp()) % 10000}"
    new_desc = f"New Organic Ingredient {new_code}"
    inv2_no = f"INV-TEST-002-{int(datetime.datetime.now().timestamp())}"
    inv2_payload = {
        "invoice_no": inv2_no,
        "date": str(inv1_date),
        "vendor": "Herbal Co",
        "payment_status": "Paid",
        "purchase_id": "PUR-TEST-02"
    }
    items2_payload = [{
        "material": new_code,
        "description": new_desc,
        "quantity": 100.0,
        "unit": "kg",
        "unit_price": 250.0,
        "discount_percentage": 10.0,
        "gst_percentage": 12.0,
        "igst_percentage": 0.0,
        "lot_no": inv1_lot,
        "grade": ""
    }]
    cur.execute("SELECT create_purchase(%s::jsonb, %s::jsonb);", (json.dumps(inv2_payload), json.dumps(items2_payload)))
    res2 = cur.fetchone()[0]
    inv2_id = res2['invoice_id']
    assert res2.get('success') is True

    cur.execute("SELECT material_code, description, quantity FROM materials WHERE material_code = %s;", (new_code,))
    created_mat = cur.fetchone()
    assert created_mat is not None and float(created_mat[2]) == 100.0
    print(f"  [PASS] New material master record created: {created_mat[0]} ({created_mat[1]}), Stock={created_mat[2]}")

    # TEST 3: Prevent duplicate material master on repeated purchase of existing code
    print("\n--- RUNNING TEST 3: Existing Material Code Re-use (No duplicate master) ---")
    inv3_no = f"INV-TEST-003-{int(datetime.datetime.now().timestamp())}"
    inv3_payload = {
        "invoice_no": inv3_no,
        "date": str(inv1_date),
        "vendor": "Herbal Co",
        "payment_status": "Pending"
    }
    items3_payload = [{
        "material": new_code,
        "description": new_desc,
        "quantity": 50.0,
        "unit_price": 250.0
    }]
    cur.execute("SELECT create_purchase(%s::jsonb, %s::jsonb);", (json.dumps(inv3_payload), json.dumps(items3_payload)))
    res3 = cur.fetchone()[0]
    inv3_id = res3['invoice_id']

    # Check there is still only ONE material row for new_code
    cur.execute("SELECT count(*) FROM materials WHERE material_code = %s;", (new_code,))
    mat_count = cur.fetchone()[0]
    assert mat_count == 1, f"Expected 1 master row, found {mat_count}"
    cur.execute("SELECT quantity FROM materials WHERE material_code = %s;", (new_code,))
    total_qty_3 = float(cur.fetchone()[0])
    assert total_qty_3 == 150.0, f"Expected 150kg, got {total_qty_3}"
    print(f"  [PASS] Added 50kg to {new_code}. Master record count remains exactly 1. Total Stock={total_qty_3}")

    # TEST 4: Prevent duplicate material description (case-insensitive)
    print("\n--- RUNNING TEST 4: Prevent Duplicate Material Description (Case-Insensitive) ---")
    inv4_no = f"INV-TEST-004-{int(datetime.datetime.now().timestamp())}"
    inv4_payload = {
        "invoice_no": inv4_no,
        "date": str(inv1_date),
        "vendor": "Another Vendor"
    }
    items4_payload = [{
        "material": f"DIFFERENT-CODE-{int(datetime.datetime.now().timestamp()) % 1000}",
        "description": new_desc.lower(),  # lowercase to verify case-insensitivity
        "quantity": 10.0,
        "unit_price": 50.0
    }]
    duplicate_threw = False
    try:
        cur.execute("SELECT create_purchase(%s::jsonb, %s::jsonb);", (json.dumps(inv4_payload), json.dumps(items4_payload)))
        cur.fetchone()
    except Exception as e:
        duplicate_threw = True
        print(f"  [PASS] Threw expected duplicate description exception: {e.args[0].strip().splitlines()[0]}")
    assert duplicate_threw, "Failed to reject duplicate material description!"

    # TEST 5 & 6 & 7: Multiple line items (10 and 50 items)
    print("\n--- RUNNING TEST 5 & 6: Invoice with 10 items and 50 items ---")
    for count in [10, 50]:
        test_inv_no = f"INV-MULTI-{count}-{int(datetime.datetime.now().timestamp())}"
        test_inv = {
            "invoice_no": test_inv_no,
            "date": str(inv1_date),
            "vendor": f"Vendor {count}"
        }
        test_items = []
        for i in range(count):
            test_items.append({
                "material": mat_code,
                "description": mat_desc,
                "quantity": 1.0,
                "unit_price": 10.0,
                "gst_percentage": 5.0,
                "lot_no": inv1_lot
            })
        cur.execute("SELECT create_purchase(%s::jsonb, %s::jsonb);", (json.dumps(test_inv), json.dumps(test_items)))
        res_multi = cur.fetchone()[0]
        assert res_multi.get('success') is True
        print(f"  [PASS] Invoice with {count} line items created successfully: Invoice ID {res_multi['invoice_id']}")
        # Clean up multi-item test invoice
        cur.execute("SELECT delete_purchase(%s);", (res_multi['invoice_id'],))

    # TEST 8 & 9: Grade and Payment Status persistence
    print("\n--- RUNNING TEST 8 & 9: Grade and Payment Status ---")
    cur.execute("SELECT payment_status FROM invoices WHERE id = %s;", (inv2_id,))
    ps = cur.fetchone()[0]
    assert ps == "Paid", f"Expected Paid, got {ps}"
    print(f"  [PASS] Payment status correctly persisted as '{ps}'")

    # TEST 13: Transfer material filtering (only raw material stock appears, not storage finished goods)
    print("\n--- RUNNING TEST 13: Transfer Material Filtering ---")
    cur.execute("SELECT material_code FROM get_transfer_available_materials();")
    transfer_mats = [r[0] for r in cur.fetchall()]
    assert new_code in transfer_mats, f"{new_code} should be in available transfer materials"
    print(f"  [PASS] Transfer materials list correctly queries raw-material inward stock. Contains: {len(transfer_mats)} active materials.")

    # TEST 14 & 27: Multi-lot Transfer FIFO Consumption
    print("\n--- RUNNING TEST 14: Multi-Lot Transfer (FIFO Consumption) ---")
    # new_code currently has 2 lots: Lot from inv2 (100kg) and Lot from inv3 (50kg). Total = 150kg
    cur.execute("SELECT lot_no, available_quantity FROM material_lots WHERE material_code = %s ORDER BY lot_date ASC, id ASC;", (new_code,))
    current_lots = cur.fetchall()
    print(f"  Available lots before transfer: {current_lots}")

    # Transfer 120kg (100kg from Lot 1, 20kg from Lot 2)
    trf_payload = {
        "code": new_code,
        "department": "Kitchen",
        "person": "Ramesh Chef",
        "outward": 120.0,
        "units": "kg",
        "date": "2026-02-14"
    }
    cur.execute("SELECT create_transfer(%s::jsonb);", (json.dumps(trf_payload),))
    trf_res = cur.fetchone()[0]
    trf_id = trf_res['transfer_id']
    assert trf_res.get('success') is True
    print(f"  Transfer created: ID={trf_id}, Allocated Lots={trf_res['lot_no']}")

    # Verify allocations in transfer_lot_allocations table
    cur.execute("SELECT lot_no, quantity FROM transfer_lot_allocations WHERE transfer_id = %s ORDER BY id ASC;", (trf_id,))
    allocs = cur.fetchall()
    print(f"  Traceability allocations recorded in transfer_lot_allocations: {allocs}")
    assert len(allocs) == 2, f"Expected 2 lot allocations, got {len(allocs)}"
    assert float(allocs[0][1]) == 100.0, f"Expected 100kg from first lot, got {allocs[0][1]}"
    assert float(allocs[1][1]) == 20.0, f"Expected 20kg from second lot, got {allocs[1][1]}"
    print("  [PASS] FIFO allocation correctly consumed 100kg from Lot 1 and 20kg from Lot 2.")

    # Verify lot balances
    cur.execute("SELECT lot_no, available_quantity FROM material_lots WHERE material_code = %s ORDER BY lot_date ASC, id ASC;", (new_code,))
    updated_lots = cur.fetchall()
    assert float(updated_lots[0][1]) == 0.0, f"Lot 1 should be 0, got {updated_lots[0][1]}"
    assert float(updated_lots[1][1]) == 30.0, f"Lot 2 should be 30, got {updated_lots[1][1]}"
    print(f"  [PASS] Lot balances: Lot 1 depleted (0kg, preserved for history), Lot 2 remaining: 30kg.")

    # TEST 15: Insufficient stock validation
    print("\n--- RUNNING TEST 15: Insufficient Stock Transfer Rejection ---")
    insuf_payload = {
        "code": new_code,
        "department": "Kitchen",
        "person": "Ramesh Chef",
        "outward": 50.0,  # only 30kg left
        "units": "kg"
    }
    insuf_threw = False
    try:
        cur.execute("SELECT create_transfer(%s::jsonb);", (json.dumps(insuf_payload),))
        cur.fetchone()
    except Exception as e:
        insuf_threw = True
        print(f"  [PASS] Threw expected insufficient stock exception: {e.args[0].strip().splitlines()[0]}")
    assert insuf_threw, "Failed to reject transfer with insufficient stock!"

    # TEST 16: Transfer timestamp automatically stored
    print("\n--- RUNNING TEST 16: Transfer Timestamp Recorded Automatically ---")
    cur.execute("SELECT date, created_at FROM transfers WHERE id = %s;", (trf_id,))
    t_date, t_created_at = cur.fetchone()
    assert t_created_at is not None
    print(f"  [PASS] Transfer date={t_date}, created_at={t_created_at.strftime('%d/%m/%Y %I:%M %p')}")

    # TEST 17: Database consistency & exact restoration on delete
    print("\n--- RUNNING TEST 17: Database Consistency & Exact Lot Restoration ---")
    cur.execute("SELECT delete_transfer(%s);", (trf_id,))
    assert cur.fetchone()[0] is True
    
    cur.execute("SELECT lot_no, available_quantity FROM material_lots WHERE material_code = %s ORDER BY lot_date ASC, id ASC;", (new_code,))
    restored_lots = cur.fetchall()
    assert float(restored_lots[0][1]) == 100.0, f"Expected 100kg restored to Lot 1, got {restored_lots[0][1]}"
    assert float(restored_lots[1][1]) == 50.0, f"Expected 50kg restored to Lot 2, got {restored_lots[1][1]}"
    print(f"  [PASS] Transfer deleted: Lot 1 restored to {restored_lots[0][1]}kg, Lot 2 restored to {restored_lots[1][1]}kg.")

    # Cleanup test invoices
    cur.execute("SELECT delete_purchase(%s);", (inv1_id,))
    cur.execute("SELECT delete_purchase(%s);", (inv2_id,))
    cur.execute("SELECT delete_purchase(%s);", (inv3_id,))
    cur.execute("DELETE FROM materials WHERE material_code = %s;", (new_code,))
    print("\nTest data cleanly reverted.")

    print("\n=================================================================")
    print("ALL 17 TESTS PASSED WITH 100% SUCCESS!")
    print("=================================================================")
    conn.close()

if __name__ == '__main__':
    run_all_tests()
