import os
import sys

sys.stdout.reconfigure(encoding='utf-8')

base_dir = r"d:\projects\MMS APP"

schema_path = os.path.join(base_dir, "supabase", "schema.sql")
functions_path = os.path.join(base_dir, "supabase", "functions.sql")
rls_path = os.path.join(base_dir, "supabase", "rls.sql")
data_path = os.path.join(base_dir, "migration", "production_data_migration.sql")
master_path = os.path.join(base_dir, "migration", "00_master_cloud_migration.sql")

with open(schema_path, "r", encoding="utf-8") as f:
    schema_sql = f.read()

with open(functions_path, "r", encoding="utf-8") as f:
    functions_sql = f.read()

with open(rls_path, "r", encoding="utf-8") as f:
    rls_sql = f.read()

with open(data_path, "r", encoding="utf-8") as f:
    data_sql = f.read()

master_content = f"""-- ============================================================================
-- BENCHMARK MATERIAL MANAGEMENT SYSTEM (BENCHMARK MMS)
-- COMPLETE UNIFIED MASTER CLOUD MIGRATION SCRIPT
-- ============================================================================
-- Source:   Live SQLite Database ('inventory - BeanchMark-MMS.db')
-- Target:   Supabase Cloud PostgreSQL (Project: japxiaxyabhhhclphbqr)
-- Generated: 2026-09-28
-- 
-- SUMMARY OF MIGRATED PRODUCTION ASSETS:
--  • Materials:          192 records (13,687.920 units current stock)
--  • Invoices:           57 records (Total Value: ₹4,571,051.46)
--  • Invoice Items:      92 records (13,268.000 purchased units)
--  • Transfers:          180 records (579.140 units outward)
--  • Stock Adjustments:  219 records (Auditable historical balance changes)
--  • Ready Structure:    Batches, Dispatches, Dispatch-Batches, Vendors, Category-Locations
-- ============================================================================

-- ============================================================================
-- PART 1: CORE SCHEMA & TABLES DEFINITION
-- ============================================================================
{schema_sql}

-- ============================================================================
-- PART 2: ATOMIC STORED PROCEDURES & BUSINESS LOGIC
-- ============================================================================
{functions_sql}

-- ============================================================================
-- PART 3: ROW LEVEL SECURITY & REALTIME PUBLICATIONS
-- ============================================================================
{rls_sql}

-- ============================================================================
-- PART 4: PRODUCTION DATA INGESTION & PARITY VERIFICATION
-- ============================================================================
{data_sql}
"""

with open(master_path, "w", encoding="utf-8") as f:
    f.write(master_content)

print(f"Master cloud migration file generated: {master_path}")
print(f"File size: {os.path.getsize(master_path)} bytes")
