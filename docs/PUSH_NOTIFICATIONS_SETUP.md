# Benchmark MMS — Push Notification Architecture & Guide

Benchmark MMS is configured with a hybrid **Native Local Notifications + Firebase Cloud Messaging (FCM) Ready** architecture.

---

## 1. Active Native System Push Notifications (Working Now)

The app now uses `flutter_local_notifications` integrated with native Android system services and Supabase Realtime:

1. **Native Status Bar Alerts**:
   - Notifications appear in the Android notification drawer and status bar with sound, vibration, high priority, and app icons.
   - Notification Channels configured:
     - `mms_stock_alerts` (Importance: Max, Sound, Vibration) — Low stock, depleted stock, expiring batches.
     - `mms_invoices` (Importance: High) — Inward invoices, dispatches, material transfers.
     - `mms_system` (Importance: Default) — System sync and background alerts.

2. **Realtime Supabase Push Triggers**:
   - Whenever a new record is added to `notifications`, `invoices`, `transfers`, or `dispatches` via Supabase Realtime, the app instantly pops up a native heads-up system notification.

3. **Smart Tap-to-Navigate**:
   - Tapping on a system notification automatically routes the user to the exact screen and item:
     - `material:<id>` -> Filters Materials screen by material
     - `batch:<id>` -> Navigates to Storage & Batches screen
     - `invoice:<id>` -> Navigates to Inward Invoices screen
     - `transfer:<id>` -> Navigates to Transfers screen
     - `dispatch:<id>` -> Navigates to Dispatch screen

4. **One-Click Test Button**:
   - Open the **Notifications & Alerts** bottom sheet (bell icon in the header) and tap the new **Notification Test** icon (bell with plus) to verify native notifications on your device.

---

## 2. Enabling FCM (Firebase Cloud Messaging) for Terminated State

To receive remote server push notifications even when the app is completely terminated (swiped away from recent apps):

### Step 1: Firebase Project Setup
1. Go to [Firebase Console](https://console.firebase.google.com).
2. Create or select your Firebase project.
3. Click **Add App** -> **Android**.
4. Set Android package name to:
   ```
   com.benchmark.mms_app
   ```
5. Download `google-services.json`.
6. Place `google-services.json` in:
   ```
   android/app/google-services.json
   ```

### Step 2: Supabase Database Migration
1. Open your **Supabase Dashboard** -> **SQL Editor**.
2. Run the script provided in:
   `supabase/06_push_notifications.sql`
3. This creates the `device_tokens` table with Row Level Security (RLS).

### Step 3: Supabase Edge Function & Webhook
1. Deploy the Edge Function located at:
   `supabase/functions/send-push-notification/index.ts`
   ```bash
   supabase functions deploy send-push-notification
   ```
2. Add your Firebase Server Key in Supabase Dashboard -> **Edge Functions** -> **Secrets**:
   ```
   FCM_SERVER_KEY=<your_fcm_server_key_or_service_account>
   ```
3. Set up a Webhook in Supabase:
   - **Table**: `notifications`
   - **Events**: `INSERT`
   - **URL**: `https://<your-project-ref>.supabase.co/functions/v1/send-push-notification`

---

## 3. Permissions Configured
The following permissions are added to `android/app/src/main/AndroidManifest.xml`:
- `android.permission.POST_NOTIFICATIONS` (Android 13+)
- `android.permission.VIBRATE`
- `android.permission.RECEIVE_BOOT_COMPLETED`
- `android.permission.WAKE_LOCK`
