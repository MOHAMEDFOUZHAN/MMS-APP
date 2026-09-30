import sqlite3
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')

db_path = r"file:d:/projects/MMS APP/migration/backup_inventory_benchmark_mms.db?mode=ro"
conn = sqlite3.connect(db_path, uri=True)
cursor = conn.cursor()

cursor.execute("SELECT name, sql FROM sqlite_master WHERE type='table' ORDER BY name")
sqlite_tables = {name: sql for name, sql in cursor.fetchall() if not name.startswith("sqlite_")}

with open(r"d:\projects\MMS APP\supabase\schema.sql", "r", encoding="utf-8") as f:
    pg_schema = f.read()

print("=====================================================================")
print("COLUMN-BY-COLUMN COMPARISON: SQLITE vs POSTGRESQL SCHEMA")
print("=====================================================================")

for t, sql in sqlite_tables.items():
    cursor.execute(f"PRAGMA table_info({t})")
    sqlite_cols = {c[1]: c[2] for c in cursor.fetchall()}
    
    # Extract columns from pg_schema for table t
    pattern = rf"CREATE TABLE (?:IF NOT EXISTS )?{t}\s*\((.*?)\);"
    match = re.search(pattern, pg_schema, re.DOTALL | re.IGNORECASE)
    pg_cols = {}
    if match:
        body = match.group(1)
        for line in body.split("\n"):
            line = line.strip().rstrip(",")
            if line and not line.startswith("--") and not line.startswith("CONSTRAINT") and not line.startswith("PRIMARY KEY") and not line.startswith("FOREIGN KEY") and not line.startswith("CHECK"):
                parts = line.split()
                if len(parts) >= 2:
                    pg_cols[parts[0]] = " ".join(parts[1:])
    
    print(f"\n--- TABLE: {t} ---")
    print(f"SQLite columns ({len(sqlite_cols)}):")
    for c, typ in sqlite_cols.items():
        print(f"  {c:25} : {typ:15} | PG equivalent: {pg_cols.get(c, '*** MISSING IN PG ***')}")
    
    extra_in_pg = set(pg_cols.keys()) - set(sqlite_cols.keys())
    if extra_in_pg:
        print(f"Extra in PG schema ({len(extra_in_pg)}): {list(extra_in_pg)}")

conn.close()
