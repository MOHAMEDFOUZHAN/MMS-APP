"""
Benchmark MMS - Over-The-Air (OTA) Release Publisher
Usage:
    python publish_update.py
    python publish_update.py --build --notes "Fixed printing and sync"
    python publish_update.py --apk "build/app/outputs/flutter-apk/app-release.apk" --notes "Bug fixes"
"""

import os
import sys
import re
import argparse
import subprocess
import shutil
import time
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import psycopg2

if hasattr(sys.stdout, 'reconfigure'):
    try:
        sys.stdout.reconfigure(encoding='utf-8')
    except Exception:
        pass

SUPABASE_URL = "https://japxiaxyabhhhclphbqr.supabase.co"
SUPABASE_KEY = "sb_publishable_mFHcuugJQo1XBVXxtt1c5Q_HIoCGFVa"
BUCKET_NAME = "app-releases"

# DB Config
PROJECT_REF = 'japxiaxyabhhhclphbqr'
PASSWORD = os.environ.get("SUPABASE_DB_PASSWORD", "mapleconnect2307")
HOST = 'aws-0-ap-northeast-1.pooler.supabase.com'
PORT = 5432
USER = f'postgres.{PROJECT_REF}'
DBNAME = 'postgres'


def get_pubspec_version():
    pubspec_path = os.path.join(os.path.dirname(__file__), 'pubspec.yaml')
    if not os.path.exists(pubspec_path):
        print("[ERROR] pubspec.yaml not found.")
        sys.exit(1)

    with open(pubspec_path, 'r', encoding='utf-8') as f:
        content = f.read()

    match = re.search(r'^version:\s*([0-9\.]+)\+([0-9]+)', content, re.MULTILINE)
    if not match:
        print("[ERROR] Could not parse version from pubspec.yaml")
        sys.exit(1)

    version_name = match.group(1)
    version_code = int(match.group(2))
    return version_name, version_code


def build_flutter_apk(clean=False, universal=False):
    flutter_bin = r"D:\flutter\bin\flutter.bat"
    if not os.path.exists(flutter_bin):
        flutter_bin = "flutter"

    if clean:
        print("\n[BUILD] Running fresh flutter clean and flutter pub get...", flush=True)
        subprocess.run([flutter_bin, "clean"], cwd=os.path.dirname(__file__))
        subprocess.run([flutter_bin, "pub", "get"], cwd=os.path.dirname(__file__))

    print("\n[BUILD] Cleaning old APK outputs to prevent stale releases...", flush=True)
    out_dir = os.path.join(os.path.dirname(__file__), "build", "app", "outputs", "flutter-apk")
    if os.path.exists(out_dir):
        for f in os.listdir(out_dir):
            if f.endswith(".apk") or f.endswith(".sha1"):
                try:
                    os.remove(os.path.join(out_dir, f))
                except Exception:
                    pass

    root_dir = os.path.dirname(__file__)
    for f in os.listdir(root_dir):
        if f.lower().endswith(".apk"):
            try:
                os.remove(os.path.join(root_dir, f))
            except Exception:
                pass

    if not os.path.exists(r"D:\tmp"):
        try:
            os.makedirs(r"D:\tmp", exist_ok=True)
        except Exception:
            pass

    if universal:
        print("[BUILD] Compiling universal release APK with Flutter (supports arm64, armeabi-v7a, and x86)...", flush=True)
        cmd = [flutter_bin, "build", "apk"]
    else:
        print("[BUILD] Compiling fresh release APK with Flutter (--split-per-abi)...", flush=True)
        cmd = [flutter_bin, "build", "apk", "--split-per-abi"]

    result = subprocess.run(cmd, cwd=os.path.dirname(__file__))
    if result.returncode != 0:
        print("[ERROR] Flutter build failed.", flush=True)
        sys.exit(1)
    print("[BUILD] Build successful!", flush=True)


def clear_old_ota(current_version_code=None):
    """Deletes old APKs from Supabase Storage and prunes older versions from app_versions."""
    print("\n[OTA-CLEAN] Checking Supabase Storage bucket for old APKs...", flush=True)
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
    }
    try:
        res = requests.post(
            f"{SUPABASE_URL}/storage/v1/object/list/{BUCKET_NAME}",
            headers=headers,
            json={"prefix": "", "limit": 100},
            timeout=15
        )
        if res.status_code == 200:
            files = res.json()
            keep_file = f"mms_app_v{current_version_code}.apk" if current_version_code else None
            to_delete = [f["name"] for f in files if "name" in f and f["name"] != keep_file]
            if to_delete:
                print(f"[OTA-CLEAN] Removing {len(to_delete)} old APK(s) from storage: {to_delete}", flush=True)
                del_res = requests.delete(
                    f"{SUPABASE_URL}/storage/v1/object/{BUCKET_NAME}",
                    headers=headers,
                    json={"prefixes": to_delete},
                    timeout=30
                )
                print(f"[OTA-CLEAN] Storage delete response: {del_res.status_code} {del_res.text}", flush=True)
            else:
                print("[OTA-CLEAN] No old APKs to remove from storage.", flush=True)
    except Exception as e:
        print(f"[WARN] Failed to clean old storage objects: {e}", flush=True)

    if current_version_code:
        try:
            print(f"[OTA-CLEAN] Pruning older database version records (< {current_version_code})...", flush=True)
            conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
            cur = conn.cursor()
            cur.execute("DELETE FROM public.app_versions WHERE version_code < %s;", (current_version_code,))
            conn.commit()
            print(f"[OTA-CLEAN] Cleaned {cur.rowcount} older version records.", flush=True)
            cur.close()
            conn.close()
        except Exception as e:
            print(f"[WARN] Failed to prune older app_versions records: {e}", flush=True)


def upload_apk(apk_path, version_name, version_code):
    filename = f"mms_app_v{version_code}.apk"
    upload_url = f"{SUPABASE_URL}/storage/v1/object/{BUCKET_NAME}/{filename}"
    public_url = f"{SUPABASE_URL}/storage/v1/object/public/{BUCKET_NAME}/{filename}"

    total_size = os.path.getsize(apk_path)
    file_size_mb = total_size / (1024 * 1024)
    print(f"\n[UPLOAD] Uploading APK ({file_size_mb:.1f} MB) to Supabase Storage: {filename}...", flush=True)

    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/vnd.android.package-archive",
        "x-upsert": "true",
    }

    with open(apk_path, "rb") as f:
        apk_data = f.read()

    max_retries = 5
    for attempt in range(1, max_retries + 1):
        try:
            print(f"[UPLOAD] Attempt {attempt}/{max_retries} ({file_size_mb:.1f} MB)...", flush=True)
            resp = requests.post(upload_url, headers=headers, data=apk_data, timeout=300)
            if resp.status_code in (200, 201):
                print("[UPLOAD] Upload complete!", flush=True)
                print(f"[URL] Public URL: {public_url}", flush=True)
                return public_url
            else:
                print(f"[WARN] Attempt {attempt} returned HTTP {resp.status_code}: {resp.text}", flush=True)
        except Exception as e:
            print(f"[WARN] Attempt {attempt} encountered connection issue: {e}", flush=True)

        if attempt < max_retries:
            backoff = 3 * attempt
            print(f"[RETRY] Waiting {backoff}s before retry...", flush=True)
            time.sleep(backoff)

    print("[ERROR] Failed to upload APK after all retries.", flush=True)
    sys.exit(1)


def update_database_version(version_code, version_name, public_url, release_notes, is_mandatory):
    print("\n[DATABASE] Updating app_versions registry in Supabase database...", flush=True)
    conn = psycopg2.connect(host=HOST, port=PORT, user=USER, password=PASSWORD, dbname=DBNAME, connect_timeout=15)
    cur = conn.cursor()

    cur.execute("""
    INSERT INTO public.app_versions (platform, version_code, version_name, apk_url, release_notes, is_mandatory, updated_at)
    VALUES ('android', %s, %s, %s, %s, %s, now());
    """, (version_code, version_name, public_url, release_notes, is_mandatory))

    conn.commit()
    cur.close()
    conn.close()
    print("[DATABASE] Database updated successfully!", flush=True)


def main():
    parser = argparse.ArgumentParser(description="Publish a new OTA update for Benchmark MMS")
    parser.add_argument("--build", action="store_true", default=True, help="Compile the Flutter APK before uploading (default: True)")
    parser.add_argument("--no-build", action="store_true", help="Skip compilation and upload existing APK")
    parser.add_argument("--clean", action="store_true", default=False, help="Run flutter clean and pub get before compilation")
    parser.add_argument("--clear-old-ota", action="store_true", default=True, help="Remove old APKs from Supabase Storage and prune old DB records")
    parser.add_argument("--apk", type=str, default="", help="Path to existing APK file")
    parser.add_argument("--notes", type=str, default="", help="Release notes / changelog")
    parser.add_argument("--mandatory", action="store_true", help="Force mandatory update on clients")
    parser.add_argument("--split", action="store_true", default=False, help="Build split-per-abi APKs instead of universal APK")
    args = parser.parse_args()

    version_name, version_code = get_pubspec_version()
    print("=" * 60)
    print(f"  Benchmark MMS - OTA Release Publisher")
    print(f"  Target Version: {version_name} (Build {version_code})")
    print("=" * 60)

    should_build = not args.no_build if not args.apk else False

    apk_path = args.apk
    if not apk_path:
        arm64_apk = os.path.join(os.path.dirname(__file__), "build", "app", "outputs", "flutter-apk", "app-arm64-v8a-release.apk")
        universal_apk = os.path.join(os.path.dirname(__file__), "build", "app", "outputs", "flutter-apk", "app-release.apk")
        if should_build or (not os.path.exists(arm64_apk) and not os.path.exists(universal_apk)):
            build_flutter_apk(clean=args.clean, universal=False)

        if os.path.exists(arm64_apk):
            apk_path = arm64_apk
        elif os.path.exists(universal_apk):
            apk_path = universal_apk
        else:
            apk_path = arm64_apk

    if not os.path.exists(apk_path):
        print(f"[ERROR] APK not found at '{apk_path}'. Run with --build to compile.")
        sys.exit(1)

    root_dir = os.path.dirname(__file__)
    for target_name in ["Benchmark MMS.apk", "Benchmark_MMS.apk", f"Benchmark_MMS_v{version_name}.apk"]:
        target_path = os.path.join(root_dir, target_name)
        try:
            shutil.copyfile(apk_path, target_path)
            print(f"[LOCAL] Saved output to: {target_name}")
        except Exception as e:
            print(f"[WARN] Failed copying to {target_name}: {e}")

    notes = args.notes
    if not notes:
        notes = f"Benchmark MMS update {version_name}. Performance improvements and fixes."

    public_url = upload_apk(apk_path, version_name, version_code)
    update_database_version(version_code, version_name, public_url, notes, args.mandatory)

    if args.clear_old_ota:
        clear_old_ota(current_version_code=version_code)

    print("\n" + "=" * 60)
    print("[SUCCESS] Update published successfully!")
    print(f"[VERSION] Version: {version_name} (Build {version_code})")
    print(f"[NOTES] Notes: {notes}")
    print("[INFO] When your client opens the app on their tablet, they will receive the update prompt.")
    print("=" * 60 + "\n")


if __name__ == "__main__":
    main()
