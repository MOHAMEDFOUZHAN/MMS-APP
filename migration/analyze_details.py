import sqlite3
import json

db_path = r"file:d:/projects/MMS APP/migration/backup_inventory_benchmark_mms.db?mode=ro"
conn = sqlite3.connect(db_path, uri=True)
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

print("=====================================================================")
print("DEEP ANALYSIS OF PRODUCTION SQLITE DATABASE")
print("=====================================================================")

tables = ["materials", "invoices", "invoice_items", "batches", "dispatches", "dispatch_batches", "transfers", "stock_adjustments", "category_locations", "vendors"]

for t in tables:
    cursor.execute(f"SELECT COUNT(*) FROM {t}")
    cnt = cursor.fetchone()[0]
    cursor.execute(f"PRAGMA table_info({t})")
    cols = cursor.fetchall()
    col_desc = [f"{c['name']} ({c['type']}{' NOT NULL' if c['notnull'] else ''}{' PK' if c['pk'] else ''})" for c in cols]
    print(f"\nTABLE: {t.upper()} (Total rows: {cnt})")
    print("  Columns:\n    " + "\n    ".join(col_desc))
    
    cursor.execute(f"PRAGMA foreign_key_list({t})")
    fks = cursor.fetchall()
    if fks:
        print("  Foreign Keys:")
        for fk in fks:
            print(f"    {fk['from']} -> {fk['table']}({fk['to']}) ON DELETE {fk['on_delete']} ON UPDATE {fk['on_update']}")
            
    cursor.execute(f"PRAGMA index_list({t})")
    idxs = cursor.fetchall()
    if idxs:
        print("  Indexes:")
        for idx in idxs:
            print(f"    {idx['name']} (unique={idx['unique']})")

print("\n=====================================================================")
print("INTEGRITY & RELATIONSHIP CHECKS")
print("=====================================================================")

# Check 1: Invoices vs Invoice Items
cursor.execute("""
    SELECT ii.id, ii.invoice_id, ii.material, ii.quantity 
    FROM invoice_items ii 
    LEFT JOIN invoices i ON ii.invoice_id = i.id 
    WHERE i.id IS NULL
""")
orphan_items = cursor.fetchall()
print(f"1. Orphan invoice_items (no matching invoice): {len(orphan_items)}")
for oi in orphan_items:
    print(f"   Orphan Item ID {oi['id']}, Invoice ID {oi['invoice_id']}, Material {oi['material']}")

# Check 2: Invoice Items vs Materials
cursor.execute("""
    SELECT DISTINCT ii.material 
    FROM invoice_items ii 
    LEFT JOIN materials m ON ii.material = m.material_code 
    WHERE m.material_code IS NULL
""")
unmatched_mat_in_items = cursor.fetchall()
print(f"2. Invoice items with materials not in materials table: {len(unmatched_mat_in_items)}")
for m in unmatched_mat_in_items:
    print(f"   Unmatched material code in invoice_items: '{m[0]}'")

# Check 3: Transfers vs Materials
cursor.execute("""
    SELECT DISTINCT t.code 
    FROM transfers t 
    LEFT JOIN materials m ON t.code = m.material_code 
    WHERE m.material_code IS NULL
""")
unmatched_mat_in_transfers = cursor.fetchall()
print(f"3. Transfers with material code not in materials table: {len(unmatched_mat_in_transfers)}")
for m in unmatched_mat_in_transfers:
    print(f"   Unmatched material code in transfers: '{m[0]}'")

# Check 4: Stock Adjustments vs Materials
cursor.execute("""
    SELECT DISTINCT sa.material_code 
    FROM stock_adjustments sa 
    LEFT JOIN materials m ON sa.material_code = m.material_code 
    WHERE m.material_code IS NULL
""")
unmatched_mat_in_sa = cursor.fetchall()
print(f"4. Stock adjustments with material code not in materials table: {len(unmatched_mat_in_sa)}")
for m in unmatched_mat_in_sa:
    print(f"   Unmatched material code in stock adjustments: '{m[0]}'")

# Check 5: Materials multi-lot check
cursor.execute("""
    SELECT material_code, COUNT(*) as cnt 
    FROM materials 
    GROUP BY material_code 
    HAVING cnt > 1
""")
multi_lots = cursor.fetchall()
print(f"5. Materials with multiple lots: {len(multi_lots)}")
for ml in multi_lots[:10]:
    print(f"   Material {ml['material_code']} has {ml['cnt']} lots")

# Check 6: Check for NULL primary keys or IDs
for t in ["materials", "invoices", "invoice_items", "transfers", "stock_adjustments"]:
    cursor.execute(f"SELECT COUNT(*) FROM {t} WHERE id IS NULL")
    null_pks = cursor.fetchone()[0]
    print(f"6. Table {t} NULL primary keys: {null_pks}")

# Check 7: Date formats inspection
print("\nSample Dates Inspection:")
cursor.execute("SELECT DISTINCT purchase_date, expiry_date, last_updated FROM materials WHERE purchase_date IS NOT NULL LIMIT 5")
print("  materials dates:", [dict(r) for r in cursor.fetchall()])

cursor.execute("SELECT DISTINCT date, created_at FROM invoices LIMIT 5")
print("  invoices dates:", [dict(r) for r in cursor.fetchall()])

cursor.execute("SELECT DISTINCT date FROM transfers LIMIT 5")
print("  transfers dates:", [dict(r) for r in cursor.fetchall()])

cursor.execute("SELECT DISTINCT created_at FROM stock_adjustments LIMIT 5")
print("  stock_adjustments dates:", [dict(r) for r in cursor.fetchall()])

# Check 8: Numeric summary / Aggregates
print("\n=====================================================================")
print("TOTAL PRODUCTION INVENTORY & FINANCIAL AGGREGATES")
print("=====================================================================")
cursor.execute("SELECT SUM(quantity), SUM(opening_stock) FROM materials")
m_sum = cursor.fetchone()
print(f"Materials Total Current Stock: {m_sum[0]:.4f}")
print(f"Materials Total Opening Stock: {m_sum[1]:.4f}")

cursor.execute("SELECT SUM(quantity), SUM(item_total) FROM invoice_items")
ii_sum = cursor.fetchone()
print(f"Invoice Items Total Quantity:  {ii_sum[0]:.4f}")
print(f"Invoice Items Total Item Total: {ii_sum[1]:.2f}")

cursor.execute("SELECT SUM(final_total), SUM(grand_total), SUM(total_gst), SUM(total_igst) FROM invoices")
inv_sum = cursor.fetchone()
print(f"Invoices Sum Final Total:       {inv_sum[0]:.2f}")
print(f"Invoices Sum Grand Total:       {inv_sum[1]:.2f}")
print(f"Invoices Sum Total GST:         {inv_sum[2]:.2f}")
print(f"Invoices Sum Total IGST:        {inv_sum[3]:.2f}")

cursor.execute("SELECT SUM(outward), SUM(return_units) FROM transfers")
t_sum = cursor.fetchone()
print(f"Transfers Total Outward:        {t_sum[0]:.4f}")
print(f"Transfers Total Returns:        {t_sum[1]:.4f}")

cursor.execute("SELECT SUM(amount) FROM stock_adjustments WHERE LOWER(operation) = 'add'")
sa_add = cursor.fetchone()[0] or 0.0
cursor.execute("SELECT SUM(amount) FROM stock_adjustments WHERE LOWER(operation) = 'subtract'")
sa_sub = cursor.fetchone()[0] or 0.0
print(f"Stock Adjustments Total Added:    {sa_add:.4f}")
print(f"Stock Adjustments Total Subtracted:{sa_sub:.4f}")

conn.close()
