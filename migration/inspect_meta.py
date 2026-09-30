import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

db_path = r"file:d:/projects/MMS APP/migration/backup_inventory_benchmark_mms.db?mode=ro"
conn = sqlite3.connect(db_path, uri=True)
cursor = conn.cursor()

cursor.execute("SELECT DISTINCT vendor FROM invoices WHERE vendor IS NOT NULL AND TRIM(vendor) != '' ORDER BY vendor")
vendors = [r[0] for r in cursor.fetchall()]
print(f"Distinct vendors in invoices: {len(vendors)}")
for v in vendors:
    print(f" - {v}")

cursor.execute("SELECT DISTINCT category FROM materials WHERE category IS NOT NULL ORDER BY category")
cats = [r[0] for r in cursor.fetchall()]
print(f"\nDistinct categories in materials: {len(cats)}")
for c in cats:
    print(f" - {c}")

cursor.execute("SELECT DISTINCT unit FROM materials WHERE unit IS NOT NULL ORDER BY unit")
units = [r[0] for r in cursor.fetchall()]
print(f"\nDistinct units in materials: {units}")

cursor.execute("SELECT DISTINCT department FROM transfers WHERE department IS NOT NULL ORDER BY department")
depts = [r[0] for r in cursor.fetchall()]
print(f"\nDistinct departments in transfers: {depts}")

conn.close()
