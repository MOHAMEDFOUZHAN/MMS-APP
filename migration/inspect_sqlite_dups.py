import sqlite3
import os

candidates = [
    r"d:\projects\MMS APP\BeanchMark-MMS\inventory - BeanchMark-MMS.db",
    r"d:\projects\Beanchmark - OCR\inventory - BeanchMark-MMS.db",
    r"d:\projects\MMS APP\migration\backup_inventory_benchmark_mms.db"
]

for p in candidates:
    if not os.path.exists(p):
        print(f"NOT FOUND: {p}")
        continue
    print(f"\nChecking: {p} (size: {os.path.getsize(p)} bytes)")
    try:
        # Open read-only
        conn = sqlite3.connect(p)
        cur = conn.cursor()
        cur.execute("SELECT name FROM sqlite_master WHERE type='table';")
        tables = [r[0] for r in cur.fetchall()]
        print("  Tables:", tables)
        if "materials" in tables:
            cur.execute("SELECT count(*) FROM materials")
            print("  Total materials:", cur.fetchone()[0])
            cur.execute("SELECT material_code, count(*) FROM materials GROUP BY material_code HAVING count(*) > 1")
            dups = cur.fetchall()
            print(f"  Duplicate material codes: {len(dups)}")
            for d in dups:
                print("   Dup code:", d)
                cur.execute("SELECT id, material_code, description, category, grade, unit, hsn_sac, reorder_level, quantity FROM materials WHERE material_code = ?", (d[0],))
                for row in cur.fetchall():
                    print("     ", row)
        conn.close()
    except Exception as e:
        print("  Error:", e)
