import os
import sys
import requests

sys.stdout.reconfigure(encoding='utf-8')

SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://japxiaxyabhhhclphbqr.supabase.co")
SUPABASE_KEY = os.environ.get("SUPABASE_PUBLISHABLE_KEY", "sb_publishable_mFHcuugJQo1XBVXxtt1c5Q_HIoCGFVa")

headers = {
    "apikey": SUPABASE_KEY,
    "Authorization": f"Bearer {SUPABASE_KEY}",
    "Range": "0-1000",
    "Prefer": "count=exact"
}

def get_table_data(table_name, select_cols="*"):
    url = f"{SUPABASE_URL}/rest/v1/{table_name}?select={select_cols}"
    resp = requests.get(url, headers=headers)
    if resp.status_code == 200:
        # Check range header for total count e.g. "0-91/92"
        content_range = resp.headers.get("Content-Range", "")
        total_count = None
        if "/" in content_range:
            try:
                total_count = int(content_range.split("/")[1])
            except:
                pass
        return resp.json(), total_count
    return None, None

def verify():
    print("=" * 78)
    print("BENCHMARK MMS — SUPABASE MIGRATION VERIFICATION AUDIT")
    print(f"Target URL: {SUPABASE_URL}")
    print("=" * 78)

    checks = [
        ("materials", 192, "quantity", 13687.92),
        ("invoices", 57, "final_total", 4571051.46),
        ("invoice_items", 92, "item_total", 4570951.10),
        ("transfers", 180, "outward", 579.14),
        ("stock_adjustments", 219, "amount", 4529.747),
        ("batches", 0, None, None),
        ("dispatches", 0, None, None),
        ("dispatch_batches", 0, None, None),
        ("category_locations", 0, None, None),
        ("vendors", 0, None, None),
    ]

    report = []
    all_matched = True

    print(f"{'Table':<20} | {'Expected':>8} | {'Supabase':>8} | {'Diff':>6} | {'Sum Check':>14} | {'Status':>8}")
    print("-" * 78)

    for table, exp_count, sum_col, exp_sum in checks:
        rows, total_count = get_table_data(table)
        if rows is None:
            print(f"{table:<20} | {exp_count:>8} | {'N/A':>8} | {'N/A':>6} | {'Table missing':>14} | {'PENDING':>8}")
            all_matched = False
            continue

        act_count = total_count if total_count is not None else len(rows)
        diff = act_count - exp_count
        status = "MATCH" if diff == 0 else "MISMATCH"

        sum_status = "N/A"
        if sum_col and rows:
            try:
                actual_sum = sum(float(r.get(sum_col) or 0) for r in rows)
                if abs(actual_sum - exp_sum) < 0.01:
                    sum_status = "OK"
                else:
                    sum_status = f"DIFF({actual_sum:.2f})"
                    status = "MISMATCH"
            except Exception as e:
                sum_status = "ERR"

        if status != "MATCH":
            all_matched = False

        print(f"{table:<20} | {exp_count:>8} | {act_count:>8} | {diff:>6} | {sum_status:>14} | {status:>8}")

    print("-" * 78)
    if all_matched:
        print(">> ALL PRODUCTION TABLES VERIFIED WITH 100% PARITY!")
    else:
        print(">> Migration is pending execution on the cloud database or some tables mismatch.")

if __name__ == "__main__":
    verify()
