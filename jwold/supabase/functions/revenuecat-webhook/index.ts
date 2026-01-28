//
//  revenuecat-webhook/index.ts
//  Just Walk - Supabase Edge Function
//
//  Webhook listener for RevenueCat subscription events.
//  Updates is_pro status in profiles table based on subscription state.
//
//  Events handled:
//  - INITIAL_PURCHASE: User subscribes for the first time
//  - RENEWAL: Subscription auto-renews
//  - CANCELLATION: User cancels (still active until period ends)
//  - EXPIRATION: Subscription period ends
//  - BILLING_ISSUE: Payment failed
//  - PRODUCT_CHANGE: User changed subscription tier
//  - TRANSFER: Subscription transferred between users
//

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.0";

// ============================================
// Types
// ============================================

interface RevenueCatEvent {
  api_version: string;
  event: {
    type: string;
    id: string;
    app_id: string;
    app_user_id: string; // This is the Supabase UUID we synced
    original_app_user_id: string;
    aliases: string[];
    subscriber_attributes?: Record<string, { value: string; updated_at_ms: number }>;
    entitlement_ids?: string[];
    entitlement_id?: string;
    product_id?: string;
    period_type?: string;
    purchased_at_ms?: number;
    expiration_at_ms?: number;
    store?: string;
    environment?: string;
    is_family_share?: boolean;
    country_code?: string;
    currency?: string;
    price?: number;
    price_in_purchased_currency?: number;
    tax_percentage?: number;
    commission_percentage?: number;
    takehome_percentage?: number;
    offer_code?: string;
    transaction_id?: string;
    original_transaction_id?: string;
    is_trial_conversion?: boolean;
    cancel_reason?: string;
    expiration_reason?: string;
    new_product_id?: string;
    presented_offering_id?: string;
  };
}

// Events that grant Pro access
const PRO_GRANTING_EVENTS = [
  "INITIAL_PURCHASE",
  "RENEWAL",
  "PRODUCT_CHANGE",
  "UNCANCELLATION",
  "SUBSCRIPTION_PAUSED", // Still has access during pause in some cases
];

// Events that revoke Pro access
const PRO_REVOKING_EVENTS = [
  "EXPIRATION",
  "BILLING_ISSUE", // Revoke on billing issue (grace period handled by RevenueCat)
];

// Events that may or may not affect access (depends on context)
const CONDITIONAL_EVENTS = [
  "CANCELLATION", // User cancelled but still has access until period ends
  "TRANSFER", // Need to handle both users
];

// ============================================
// Edge Function Handler
// ============================================

serve(async (req: Request) => {
  // Only accept POST requests
  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { "Content-Type": "application/json" },
    });
  }

  // ============================================
  // 1. Verify Authorization Header
  // ============================================
  const authHeader = req.headers.get("Authorization");
  const expectedToken = Deno.env.get("REVENUECAT_WEBHOOK_SECRET");

  if (!expectedToken) {
    console.error("❌ REVENUECAT_WEBHOOK_SECRET not configured");
    return new Response(JSON.stringify({ error: "Server misconfiguration" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  // RevenueCat sends: "Bearer <your_secret>"
  const providedToken = authHeader?.replace("Bearer ", "");

  if (!providedToken || providedToken !== expectedToken) {
    console.error("❌ Unauthorized webhook request - invalid token");
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }

  // ============================================
  // 2. Parse Webhook Payload
  // ============================================
  let payload: RevenueCatEvent;

  try {
    payload = await req.json();
  } catch (error) {
    console.error("❌ Failed to parse webhook payload:", error);
    return new Response(JSON.stringify({ error: "Invalid JSON payload" }), {
      status: 400,
      headers: { "Content-Type": "application/json" },
    });
  }

  const { event } = payload;
  const eventType = event.type;
  const appUserId = event.app_user_id; // This is the Supabase UUID
  const entitlementId = event.entitlement_id || event.entitlement_ids?.[0];

  console.log(`📥 RevenueCat Event: ${eventType}`);
  console.log(`   User ID: ${appUserId}`);
  console.log(`   Entitlement: ${entitlementId}`);
  console.log(`   Product: ${event.product_id}`);
  console.log(`   Environment: ${event.environment}`);

  // ============================================
  // 3. Validate User ID (must be valid UUID)
  // ============================================
  const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

  if (!uuidRegex.test(appUserId)) {
    // Anonymous user or non-Supabase user - log but don't fail
    console.warn(`⚠️ Non-UUID app_user_id: ${appUserId} - skipping profile update`);
    return new Response(JSON.stringify({
      success: true,
      message: "Event received but user not linked to Supabase profile"
    }), {
      status: 200,
      headers: { "Content-Type": "application/json" },
    });
  }

  // ============================================
  // 4. Initialize Supabase Client (Service Role)
  // ============================================
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const supabaseServiceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !supabaseServiceKey) {
    console.error("❌ Supabase credentials not configured");
    return new Response(JSON.stringify({ error: "Server misconfiguration" }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const supabase = createClient(supabaseUrl, supabaseServiceKey, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
    },
  });

  // ============================================
  // 5. Determine Pro Status Based on Event
  // ============================================
  let shouldUpdatePro = false;
  let newProStatus: boolean | null = null;

  if (PRO_GRANTING_EVENTS.includes(eventType)) {
    // Grant Pro access
    shouldUpdatePro = true;
    newProStatus = true;
    console.log(`✅ Granting Pro access for event: ${eventType}`);
  } else if (PRO_REVOKING_EVENTS.includes(eventType)) {
    // Revoke Pro access
    shouldUpdatePro = true;
    newProStatus = false;
    console.log(`🚫 Revoking Pro access for event: ${eventType}`);
  } else if (eventType === "CANCELLATION") {
    // Cancellation doesn't immediately revoke - user has access until expiration
    // We'll just log it; EXPIRATION event will handle the actual revocation
    console.log(`ℹ️ Subscription cancelled - access continues until expiration`);
    shouldUpdatePro = false;
  } else if (eventType === "TRANSFER") {
    // Transfer event - need to handle in a special way
    // The new owner gets Pro, the old owner loses it
    // For now, just grant to the new user (app_user_id)
    shouldUpdatePro = true;
    newProStatus = true;
    console.log(`🔄 Subscription transferred to user: ${appUserId}`);
  } else {
    // Other events (TEST, SUBSCRIBER_ALIAS, etc.) - just acknowledge
    console.log(`ℹ️ Event ${eventType} received - no profile update needed`);
    shouldUpdatePro = false;
  }

  // ============================================
  // 6. Update Supabase Profile
  // ============================================
  if (shouldUpdatePro && newProStatus !== null) {
    try {
      const { data, error } = await supabase
        .from("profiles")
        .update({
          is_pro: newProStatus,
          updated_at: new Date().toISOString(),
        })
        .eq("id", appUserId)
        .select("id, is_pro")
        .single();

      if (error) {
        // Check if it's a "no rows found" error
        if (error.code === "PGRST116") {
          console.warn(`⚠️ No profile found for user: ${appUserId}`);
          // Don't fail - the profile might not exist yet
          return new Response(JSON.stringify({
            success: true,
            message: "Event processed but profile not found",
            user_id: appUserId,
          }), {
            status: 200,
            headers: { "Content-Type": "application/json" },
          });
        }

        throw error;
      }

      console.log(`✅ Profile updated: ${data.id} -> is_pro: ${data.is_pro}`);

      return new Response(JSON.stringify({
        success: true,
        event_type: eventType,
        user_id: appUserId,
        is_pro: newProStatus,
      }), {
        status: 200,
        headers: { "Content-Type": "application/json" },
      });

    } catch (error) {
      console.error(`❌ Failed to update profile:`, error);
      return new Response(JSON.stringify({
        error: "Failed to update profile",
        details: error instanceof Error ? error.message : "Unknown error",
      }), {
        status: 500,
        headers: { "Content-Type": "application/json" },
      });
    }
  }

  // ============================================
  // 7. Return Success for Non-Update Events
  // ============================================
  return new Response(JSON.stringify({
    success: true,
    event_type: eventType,
    message: "Event acknowledged",
  }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
