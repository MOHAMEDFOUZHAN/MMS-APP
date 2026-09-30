import sqlite3
import json

db_path = r"file:d:/projects/MMS APP/migration/backup_inventory_benchmark_mms.db?mode=ro"
conn = sqlite3.connect(db_path, uri=True)
cursor = conn.cursor()

# 1. Get all tables
cursor.execute("SELECT name, sql FROM sqlite_master WHERE type='table' ORDER BY name")
tables = cursor.fetchall()

report = {}

print("==================================================")
print("SQLITE PRODUCTION DATABASE SCHEMA AUDIT")
print("==================================================")

for table_name, ddl in tables:
    if table_name.startswith("sqlite_"):
        continue
    
    # Row count
    cursor.execute(f'SELECT COUNT(*) FROM "{table_name}"')
    count = cursor.fetchone()[0]
    
    # Table info: cid, name, type, notnull, dflt_value, pk
    cursor.execute(f'PRAGMA table_info("{table_name}")')
    cols = cursor.fetchall()
    
    # Foreign keys
    cursor.execute(f'PRAGMA foreign_key_list("{table_name}")')
    fks = cursor.fetchall()
    
    # Indexes
    cursor.execute(f'PRAGMA index_list("{table_name}")')
    indexes = cursor.fetchall()
    
    # Sample 1 row
    cursor.execute(f'SELECT * FROM "{table_name}" LIMIT 1')
    sample = cursor.fetchone()
    
    report[table_name] = {
        "count": count,
        "ddl": ddl,
        "columns": [
            {"id": c[0], "name": c[1], "type": c[2], "notnull": c[3], "default": c[4], "pk": c[5]}
            for c in cols
        ],
        "foreign_keys": [
            {"id": f[0], "seq": f[1], "table": f[2], "from": f[3], "to": f[4], "on_update": f[5], "on_delete": f[6]}
            for f in fks
        ],
        "indexes": [
            {"seq": idx[0], "name": idx[1], "unique": idx[2], "origin": idx[3], "partial": idx[4]}
            for idx in indexes
        ],
        "sample": sample
    }
    
    print(f"Table: {table_name:25} | Records: {count:6}")

print("\nDetailed DDLs and records captured in JSON audit file.\n")

with open(r"d:\projects\MMS APP\migration\sqlite_audit.json", "w", encoding="utf-8") as f:
    json.dump(report, f, indent=2, default=str)

print("Saved audit to d:\\projects\\MMS APP\\migration\\sqlite_audit.json")
conn.close()
