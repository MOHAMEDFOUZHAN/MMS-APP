import sys
import psycopg2
import json
import re
from collections import defaultdict
from difflib import SequenceMatcher

sys.stdout.reconfigure(encoding='utf-8')

PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = 'mapleconnect2307'
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'

conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
cur = conn.cursor()

def clean_spaces(text):
    if not text:
        return ""
    return re.sub(r'\s+', ' ', str(text)).strip()

def normalize_text(text):
    if not text:
        return ""
    return clean_spaces(text).upper()

# Scan materials
cur.execute("SELECT id, material_code, description, category, unit, grade, hsn_sac FROM materials ORDER BY id")
materials = cur.fetchall()

report = {
    "total_records_scanned": len(materials),
    "category_audit": [],
    "unit_audit": [],
    "grade_audit": [],
    "description_audit": [],
    "code_audit": [],
    "proposed_corrections": []
}

# 1. Category Audit
cats = sorted(list(set(m[3] for m in materials if m[3])))
for c in cats:
    norm = normalize_text(c)
    status = "SAFE"
    suggested = norm
    reason = "Already correct"
    
    if c != norm:
        if c.strip().upper() == norm and c != c.upper():
            reason = "Case difference"
            status = "SAFE"
        elif clean_spaces(c) != c:
            reason = "Spacing difference"
            status = "SAFE"
    elif c == "chocolater":
        suggested = "CHOCOLATE"
        reason = "Obvious spelling error (extra 'r')"
        status = "REVIEW"
    
    # Specific known spelling check
    if norm == "CHOCOLATER":
        suggested = "CHOCOLATE"
        reason = "Obvious spelling error for CHOCOLATE"
        status = "CONFIRMED_TYPO"

    report["category_audit"].append({
        "original": c,
        "suggested": suggested,
        "reason": reason,
        "status": status
    })

# 2. Unit Audit
units = sorted(list(set(m[4] for m in materials if m[4])))
for u in units:
    norm = normalize_text(u)
    # Check packet vs pkt
    suggested = norm
    reason = "Case normalization" if u != norm else "Already correct"
    if u in ["Pkt", "packet"]:
        suggested = "PKT"
        reason = "Unit symbol standardization"
    report["unit_audit"].append({
        "original": u,
        "suggested": suggested,
        "reason": reason,
        "status": "SAFE"
    })

# 3. Description Audit
descs = sorted(list(set(m[2] for m in materials if m[2])))
for d in descs:
    norm = normalize_text(d)
    if d != norm:
        report["description_audit"].append({
            "original": d,
            "suggested": norm,
            "reason": "Case & spacing normalization",
            "status": "SAFE"
        })

with open(r"d:\projects\MMS APP\migration\text_standardization_report.json", "w", encoding="utf-8") as f:
    json.dump(report, f, indent=2)

print(f"Report generated successfully with {len(report['category_audit'])} categories, {len(report['unit_audit'])} units, {len(report['description_audit'])} descriptions needing normalization.")

cur.close()
conn.close()
