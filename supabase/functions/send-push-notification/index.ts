// ==============================================================================
// Supabase Edge Function: send-push-notification
// Sends Firebase Cloud Messaging (FCM) v1 Push Notifications for Benchmark MMS
// ==============================================================================

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.38.4";

interface WebhookPayload {
  type: "INSERT" | "UPDATE" | "DELETE";
  table: string;
  schema: string;
  record: {
    id: number;
    title: string;
    message: string;
    type?: string;
    severity?: string;
    reference_type?: string;
    reference_id?: string;
    user_id?: string;
  };
}

serve(async (req: Request) => {
  try {
    if (req.method !== "POST") {
      return new Response(JSON.stringify({ error: "Method not allowed" }), {
        status: 405,
        headers: { "Content-Type": "application/json" },
      });
    }

    const payload: WebhookPayload = await req.json();
    const record = payload.record;

    if (!record || !record.title) {
      return new Response(JSON.stringify({ message: "No notification content" }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });
    }

    // Initialize Supabase admin client
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseServiceKey);

    // Fetch target device tokens
    let query = supabase.from("device_tokens").select("token");
    if (record.user_id) {
      query = query.eq("user_id", record.user_id);
    }

    const { data: tokensData, error: tokensError } = await query;

    if (tokensError || !tokensData || tokensData.length === 0) {
      return new Response(
        JSON.stringify({ message: "No registered device tokens found" }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    const tokens = tokensData.map((t: { token: string }) => t.token);

    // FCM Server Key or Service Account credentials
    const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");

    if (!fcmServerKey) {
      return new Response(
        JSON.stringify({
          warning: "FCM_SERVER_KEY not configured. Tokens retrieved successfully.",
          tokenCount: tokens.length,
          title: record.title,
        }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // Dispatch FCM Legacy / HTTP notification
    const fcmPromises = tokens.map((token: string) =>
      fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `key=${fcmServerKey}`,
        },
        body: JSON.stringify({
          to: token,
          notification: {
            title: record.title,
            body: record.message,
            icon: "ic_launcher",
            click_action: "FLUTTER_NOTIFICATION_CLICK",
          },
          data: {
            ref_type: record.reference_type ?? "",
            ref_id: record.reference_id ?? "",
            alert_type: record.type ?? "",
          },
        }),
      })
    );

    const responses = await Promise.all(fcmPromises);
    const successCount = responses.filter((r) => r.ok).length;

    return new Response(
      JSON.stringify({
        success: true,
        sentCount: successCount,
        totalTokens: tokens.length,
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    return new Response(JSON.stringify({ error: message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }
});
