import requests

SUPABASE_URL = 'https://japxiaxyabhhhclphbqr.supabase.co'
ANON_KEY = 'sb_publishable_mFHcuugJQo1XBVXxtt1c5Q_HIoCGFVa'

print("--- 1. Testing Owner Login & Access ---")
owner_login = requests.post(
    f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
    headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
    json={"email": "owner@benchmarkmms.com", "password": "admin123"}
)
print("Owner login status:", owner_login.status_code)
owner_token = owner_login.json().get("access_token")
print("Owner token obtained:", bool(owner_token))

# Call verify_owner_access as Owner
verify_res = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/verify_owner_access",
    headers={"apikey": ANON_KEY, "Authorization": f"Bearer {owner_token}", "Content-Type": "application/json"},
    json={}
)
print("verify_owner_access status as Owner:", verify_res.status_code)
print("verify_owner_access response:", verify_res.json())

# Call get_owner_dashboard_summary as Owner
dashboard_res = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/get_owner_dashboard_summary",
    headers={"apikey": ANON_KEY, "Authorization": f"Bearer {owner_token}", "Content-Type": "application/json"},
    json={}
)
print("get_owner_dashboard_summary status as Owner:", dashboard_res.status_code)
data = dashboard_res.json()
print("Top KPI Keys:", list(data.get('kpi', {}).keys()))
print("Total Materials:", data.get('kpi', {}).get('total_materials'))
print("Total Storage Stock:", data.get('kpi', {}).get('total_storage_stock'))
print("Total Purchases Value:", data.get('kpi', {}).get('total_purchases_val'))
print("Today Snapshot:", data.get('today'))
print("Health:", data.get('health'))

print("\n--- 2. Testing Non-Owner (Operator/BM) Rejection ---")
bm_login = requests.post(
    f"{SUPABASE_URL}/auth/v1/token?grant_type=password",
    headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
    json={"email": "bm@benchmarkmms.com", "password": "2307"}
)
print("BM login status:", bm_login.status_code)
bm_token = bm_login.json().get("access_token")

# Call verify_owner_access as BM
bm_verify = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/verify_owner_access",
    headers={"apikey": ANON_KEY, "Authorization": f"Bearer {bm_token}", "Content-Type": "application/json"},
    json={}
)
print("verify_owner_access status as BM:", bm_verify.status_code)
print("verify_owner_access response as BM (Should be 400/403/Access Denied):", bm_verify.json())

# Call get_owner_dashboard_summary as BM
bm_dash = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/get_owner_dashboard_summary",
    headers={"apikey": ANON_KEY, "Authorization": f"Bearer {bm_token}", "Content-Type": "application/json"},
    json={}
)
print("get_owner_dashboard_summary status as BM:", bm_dash.status_code)
print("get_owner_dashboard_summary response as BM (Should be 400/403/Access Denied):", bm_dash.json())

print("\n--- 3. Testing Anonymous (Unauthenticated) Rejection ---")
anon_verify = requests.post(
    f"{SUPABASE_URL}/rest/v1/rpc/verify_owner_access",
    headers={"apikey": ANON_KEY, "Content-Type": "application/json"},
    json={}
)
print("verify_owner_access status as Anon:", anon_verify.status_code)
print("verify_owner_access response as Anon:", anon_verify.json())
