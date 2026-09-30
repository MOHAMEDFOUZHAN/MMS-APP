import sqlite3
import sys

sys.stdout.reconfigure(encoding='utf-8')

db_path = r"file:d:/projects/MMS APP/migration/backup_inventory_benchmark_mms.db?mode=ro"
conn = sqlite3.connect(db_path, uri=True)
conn.row_factory = sqlite3.Row
cursor = conn.cursor()

def sql_quote(val):
    if val is None:
        return "NULL"
    if isinstance(val, (int, float)):
        return str(val)
    # String / text
    s = str(val).strip()
    if s == "":
        return "NULL"
    # Escape single quotes
    escaped = s.replace("'", "''")
    return f"'{escaped}'"

def sql_date(val):
    if val is None:
        return "NULL"
    s = str(val).strip()
    if not s or s == "":
        return "NULL"
    # If date is like '2026-08-03'
    date_part = s.split()[0]
    if len(date_part) == 10 and date_part[4] == '-' and date_part[7] == '-':
        return f"'{date_part}'"
    return "NULL"

def sql_timestamp(val):
    if val is None:
        return "CURRENT_TIMESTAMP"
    s = str(val).strip()
    if not s or s == "":
        return "CURRENT_TIMESTAMP"
    escaped = s.replace("'", "''")
    return f"'{escaped}'::timestamptz"

print("Extracting production data from SQLite...")

# 1. Materials
cursor.execute("SELECT * FROM materials ORDER BY id ASC")
materials_rows = cursor.fetchall()

# 2. Invoices
cursor.execute("SELECT * FROM invoices ORDER BY id ASC")
invoices_rows = cursor.fetchall()

# 3. Invoice Items
cursor.execute("SELECT * FROM invoice_items ORDER BY id ASC")
invoice_items_rows = cursor.fetchall()

# 4. Transfers
cursor.execute("SELECT * FROM transfers ORDER BY id ASC")
transfers_rows = cursor.fetchall()

# 5. Stock Adjustments
cursor.execute("SELECT * FROM stock_adjustments ORDER BY id ASC")
stock_adjustments_rows = cursor.fetchall()

conn.close()

print(f"Extracted:")
print(f"  materials:         {len(materials_rows)}")
print(f"  invoices:          {len(invoices_rows)}")
print(f"  invoice_items:     {len(invoice_items_rows)}")
print(f"  transfers:         {len(transfers_rows)}")
print(f"  stock_adjustments: {len(stock_adjustments_rows)}")
