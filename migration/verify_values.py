import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

db_path = r"file:d:/projects/MMS APP/migration/backup_inventory_benchmark_mms.db?mode=ro"
conn = sqlite3.connect(db_path, uri=True)
conn.row_factory = sqlite3.Row
c = conn.cursor()

print("--- Checking invoices payment_status ---")
c.execute("SELECT DISTINCT payment_status FROM invoices")
print("payment_status:", [r[0] for r in c.fetchall()])

print("\n--- Checking invoices invoice_no duplicates ---")
c.execute("SELECT invoice_no, COUNT(*) FROM invoices GROUP BY invoice_no HAVING COUNT(*) > 1")
dup_inv = c.fetchall()
print("Duplicate invoice_no:", len(dup_inv))
for d in dup_inv:
    print(f"  {d[0]}: {d[1]} times")

print("\n--- Checking stock_adjustments operation and amounts ---")
c.execute("SELECT operation, COUNT(*), MIN(amount), MAX(amount) FROM stock_adjustments GROUP BY operation")
for r in c.fetchall():
    print(f"  operation '{r[0]}': {r[1]} rows, min amount = {r[2]}, max amount = {r[3]}")

print("\n--- Checking materials dates for invalid formats ---")
c.execute("SELECT id, purchase_date, expiry_date, last_updated FROM materials WHERE (purchase_date IS NOT NULL AND purchase_date != '') OR (expiry_date IS NOT NULL AND expiry_date != '') LIMIT 5")
for r in c.fetchall():
    print(dict(r))

print("\n--- Checking materials empty string dates ---")
c.execute("SELECT COUNT(*) FROM materials WHERE purchase_date = ''")
print("purchase_date = '':", c.fetchone()[0])
c.execute("SELECT COUNT(*) FROM materials WHERE expiry_date = ''")
print("expiry_date = '':", c.fetchone()[0])

print("\n--- Checking transfers date format ---")
c.execute("SELECT DISTINCT date FROM transfers WHERE length(date) != 10 LIMIT 5")
odd_dates = c.fetchall()
print("Non-10-char dates in transfers:", len(odd_dates))

print("\n--- Checking invoice_items invoice_id foreign key references ---")
c.execute("SELECT DISTINCT invoice_id FROM invoice_items WHERE invoice_id NOT IN (SELECT id FROM invoices)")
missing_inv = c.fetchall()
print("Unmatched invoice_id in invoice_items:", len(missing_inv))

conn.close()
