# Benchmark MMS — Supabase PostgreSQL Setup & Deployment Guide

This directory contains the complete database scripts for the **Benchmark Material Management System (Benchmark MMS)** mobile and tablet application.

## SQL Scripts Overview

1. **`schema.sql`**: Full DDL schema defining all 11 tables (`materials`, `invoices`, `invoice_items`, `batches`, `dispatches`, `dispatch_batches`, `transfers`, `stock_adjustments`, `category_locations`, `vendors`, `system_settings`), primary keys, foreign keys with cascade constraints, check constraints, and performance indexes.
2. **`functions.sql`**: 10 PostgreSQL Stored Procedures / RPC functions for atomic transaction safety:
   - `create_purchase`: Atomic invoice creation, line-item insertion, tax/discount calculation, and material stock update.
   - `delete_purchase`: Reverses stock allocations, deletes invoice items and invoice.
   - `create_dispatch_fifo`: Multi-batch FIFO deduction from oldest batches, allocating batch records in `dispatch_batches`.
   - `delete_dispatch`: Reverses dispatch by restoring exact allocated quantities to their respective batches.
   - `create_transfer`: Department outward/return transfer with `Net Change = Return - Outward` stock update.
   - `delete_transfer`: Reverts department transfer and restores material stock.
   - `create_stock_adjustment`: Add or FIFO subtract from oldest lots with audit logging.
   - `update_material_unit`: Atomically synchronizes unit across materials, batches, invoice_items, transfers, and dispatches.
   - `reset_daily_opening_stock`: Sets today's opening stock equal to previous closing stock.
   - `get_mur_report`: Material Utilization Report with historical backtracking calculation.
3. **`rls.sql`**: Row Level Security (RLS) policies and Realtime publications.
4. **`seed.sql`**: Initial default category shelf locations, vendors, and security pins.

## Deployment to Supabase

1. Open your [Supabase Project Dashboard](https://supabase.com/dashboard).
2. Go to the **SQL Editor**.
3. Run the scripts in the following order:
   ```sql
   -- Step 1: Run schema.sql
   -- Step 2: Run functions.sql
   -- Step 3: Run rls.sql
   -- Step 4: Run seed.sql
   ```
4. Copy your project's **URL** and **Anon / Public Key** from **Project Settings > API**.

## Configuring the Flutter Application

You can configure the application in two ways:

### Option A: Using `--dart-define` (Recommended for production CI/CD)
```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-project-ref.supabase.co \
  --dart-define=SUPABASE_PUBLISHABLE_KEY=your-anon-key
```

### Option B: Using `.env` file
Create a `.env` file in the root of `MMS APP`:
```env
SUPABASE_URL=https://your-project-ref.supabase.co
SUPABASE_PUBLISHABLE_KEY=your-anon-key
```
