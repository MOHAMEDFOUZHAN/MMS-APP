import os
import psycopg2
import json
from datetime import datetime, timezone, timedelta

def test_section_16():
    print("Testing Section 16 Final Validation Scenario...")
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

    test_prod_code = f"TEST_SEC16_PROD"
    test_prod_name = "Product A"

    # Clean up any existing test records
    cur.execute("DELETE FROM public.dispatch_batches WHERE dispatch_id IN (SELECT id FROM public.dispatches WHERE material_code = %s);", (test_prod_code,))
    cur.execute("DELETE FROM public.dispatches WHERE material_code = %s;", (test_prod_code,))
    cur.execute("DELETE FROM public.batches WHERE material_code = %s;", (test_prod_code,))
    cur.execute("DELETE FROM public.storage_products WHERE product_code = %s;", (test_prod_code,))

    # Create storage product
    cur.execute("""
        INSERT INTO public.storage_products (product_code, product_name, category, grade, uom)
        VALUES (%s, %s, 'Finished Goods', 'STANDARD', 'packet');
    """, (test_prod_code, test_prod_name))

    # 1. Create Batch 275 at 09:00 AM on 02/10/2026 (100 packet)
    # Using local time 09:00 AM (+05:30)
    tz = timezone(timedelta(hours=5, minutes=30))
    time_9am = datetime(2026, 10, 2, 9, 0, 0, tzinfo=tz)
    time_2pm = datetime(2026, 10, 2, 14, 0, 0, tzinfo=tz)

    cur.execute("""
        INSERT INTO public.batches (
            batch_no, material_code, description, category, grade,
            received_quantity, available_quantity, uom, department,
            batch_date, received_date, received_at
        ) VALUES (
            '275', %s, %s, 'Finished Goods', 'STANDARD',
            100, 100, 'packet', 'Finished Goods',
            '2026-10-02', '2026-10-02', %s
        ) RETURNING id;
    """, (test_prod_code, test_prod_name, time_9am))
    batch_9am_id = cur.fetchone()[0]

    # 2. Create Batch 275 at 02:00 PM on 02/10/2026 (200 packet)
    cur.execute("""
        INSERT INTO public.batches (
            batch_no, material_code, description, category, grade,
            received_quantity, available_quantity, uom, department,
            batch_date, received_date, received_at
        ) VALUES (
            '275', %s, %s, 'Finished Goods', 'STANDARD',
            200, 200, 'packet', 'Finished Goods',
            '2026-10-02', '2026-10-02', %s
        ) RETURNING id;
    """, (test_prod_code, test_prod_name, time_2pm))
    batch_2pm_id = cur.fetchone()[0]

    print(f"Created Batch 275 at 09:00 AM (ID: {batch_9am_id}, Qty: 100)")
    print(f"Created Batch 275 at 02:00 PM (ID: {batch_2pm_id}, Qty: 200)")

    # 3. Preview Dispatch 150
    cur.execute("""
        SELECT public.get_storage_dispatch_preview(
            p_material_code => %s,
            p_requested_quantity => 150
        );
    """, (test_prod_code,))
    preview = cur.fetchone()[0]
    print("\nPreview Allocations:")
    for alloc in preview.get('fifo_allocations', []):
        print(f"  Batch {alloc['batch_no']} (ID: {alloc['batch_id']}): allocated {alloc['allocated_quantity']}")

    # 4. Execute Dispatch 150 via create_dispatch_fifo
    dispatch_payload = {
        'date': '2026-10-02',
        'material_code': test_prod_code,
        'product': test_prod_name,
        'quantity': 150,
        'return_quantity': 0,
        'units': 'packet',
        'department': 'Dispatch',
        'location': 'Warehouse A',
        'remarks': 'Test Section 16'
    }
    cur.execute("""
        SELECT public.create_dispatch_fifo(
            p_dispatch => %s::jsonb
        );
    """, (json.dumps(dispatch_payload),))
    res = cur.fetchone()[0]
    print(f"\nDispatch result: success={res.get('success')}, dispatch_id={res.get('dispatch_id')}")

    # 5. Check remaining batch stock
    cur.execute("SELECT id, batch_no, received_at, received_quantity, available_quantity FROM public.batches WHERE id IN (%s, %s) ORDER BY received_at ASC;", (batch_9am_id, batch_2pm_id))
    rows = cur.fetchall()
    print("\nBatch Stock After Dispatch 150:")
    for r in rows:
        print(f"  ID {r[0]}: Batch {r[1]} received_at {r[2]} -> Received {r[3]}, Available {r[4]}")

    b9am = [r for r in rows if r[0] == batch_9am_id][0]
    b2pm = [r for r in rows if r[0] == batch_2pm_id][0]

    assert b9am[4] == 0, f"Expected 09:00 AM batch to have 0 available, got {b9am[4]}"
    assert b2pm[4] == 150, f"Expected 02:00 PM batch to have 150 available, got {b2pm[4]}"
    print("\nFIFO VERIFICATION PASSED:")
    print("  09:00 AM batch (100) -> 100 consumed, 0 remaining")
    print("  02:00 PM batch (200) -> 50 consumed, 150 remaining")

    # 6. Current Stock View: should only return batches where available_quantity > 0
    cur.execute("SELECT id, batch_no, available_quantity FROM public.batches WHERE material_code = %s AND available_quantity > 0.0001;", (test_prod_code,))
    current_stock = cur.fetchall()
    print(f"\nCurrent Stock records (available > 0): {len(current_stock)}")
    for cs in current_stock:
        print(f"  Batch {cs[1]} (ID {cs[0]}): {cs[2]} available")
    assert len(current_stock) == 1 and current_stock[0][0] == batch_2pm_id, "Current stock must ONLY contain the 02:00 PM batch!"

    # 7. All History View: should return BOTH records
    cur.execute("SELECT id, batch_no, received_quantity, available_quantity FROM public.batches WHERE material_code = %s ORDER BY received_at ASC;", (test_prod_code,))
    all_history = cur.fetchall()
    print(f"\nAll History records (all batches preserved): {len(all_history)}")
    for h in all_history:
        print(f"  Batch {h[1]} (ID {h[0]}): Received {h[2]}, Available {h[3]}")
    assert len(all_history) == 2, "All history must preserve BOTH records!"

    # Clean up test records
    cur.execute("DELETE FROM public.dispatch_batches WHERE dispatch_id IN (SELECT id FROM public.dispatches WHERE material_code = %s);", (test_prod_code,))
    cur.execute("DELETE FROM public.dispatches WHERE material_code = %s;", (test_prod_code,))
    cur.execute("DELETE FROM public.batches WHERE material_code = %s;", (test_prod_code,))
    cur.execute("DELETE FROM public.storage_products WHERE product_code = %s;", (test_prod_code,))
    print("\nALL SECTION 16 TESTS PASSED CLEANLY!")

if __name__ == '__main__':
    test_section_16()
