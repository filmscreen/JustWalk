# RevenueCat Webhook - Supabase Edge Function

This Edge Function listens for RevenueCat webhook events and syncs subscription status to the `profiles` table.

## Events Handled

| Event Type | Action |
|------------|--------|
| `INITIAL_PURCHASE` | Sets `is_pro = true` |
| `RENEWAL` | Sets `is_pro = true` |
| `PRODUCT_CHANGE` | Sets `is_pro = true` |
| `UNCANCELLATION` | Sets `is_pro = true` |
| `EXPIRATION` | Sets `is_pro = false` |
| `BILLING_ISSUE` | Sets `is_pro = false` |
| `CANCELLATION` | No change (access until expiration) |
| `TRANSFER` | Sets `is_pro = true` for new owner |

## Prerequisites

1. Supabase CLI installed (`npm install -g supabase`)
2. Supabase project linked (`supabase link --project-ref YOUR_PROJECT_REF`)
3. RevenueCat account with webhooks enabled

## Deployment Steps

### 1. Generate a Webhook Secret

Create a secure random string to authenticate RevenueCat requests:

```bash
# Generate a 32-character secret
openssl rand -base64 32
```

Example output: `K7xm9P2qR4vL1nW8cY3hZ6jB0fE5tA9s`

### 2. Set Environment Variables

```bash
# Set the webhook secret in Supabase
supabase secrets set REVENUECAT_WEBHOOK_SECRET="your_generated_secret_here"
```

Note: `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` are automatically available in Edge Functions.

### 3. Deploy the Function

```bash
# Navigate to project root
cd /path/to/Just\ Walk

# Deploy the function
supabase functions deploy revenuecat-webhook --no-verify-jwt
```

The `--no-verify-jwt` flag is required because RevenueCat sends its own authentication header, not a Supabase JWT.

### 4. Get the Function URL

After deployment, the function URL will be:

```
https://<your-project-ref>.supabase.co/functions/v1/revenuecat-webhook
```

### 5. Configure RevenueCat Webhook

1. Go to **RevenueCat Dashboard** → **Your App** → **Integrations** → **Webhooks**
2. Click **+ New Webhook**
3. Configure:
   - **Webhook URL**: `https://<your-project-ref>.supabase.co/functions/v1/revenuecat-webhook`
   - **Authorization Header**: `Bearer your_generated_secret_here`
   - **Events to send**: Select all subscription events (or at minimum: INITIAL_PURCHASE, RENEWAL, EXPIRATION, BILLING_ISSUE, CANCELLATION)
4. Click **Save**

### 6. Test the Webhook

Use the RevenueCat dashboard's "Send Test Webhook" feature:

1. In the webhook configuration, click **Send Test Webhook**
2. Check Supabase Dashboard → Edge Functions → Logs for the response

## Verification

### Check Edge Function Logs

```bash
# View real-time logs
supabase functions logs revenuecat-webhook --tail
```

### Manual Test with cURL

```bash
curl -X POST \
  https://<your-project-ref>.supabase.co/functions/v1/revenuecat-webhook \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer your_generated_secret_here" \
  -d '{
    "api_version": "1.0",
    "event": {
      "type": "INITIAL_PURCHASE",
      "id": "test-event-123",
      "app_user_id": "00000000-0000-0000-0000-000000000000",
      "entitlement_ids": ["pro"],
      "product_id": "com.justwalk.pro.annual",
      "environment": "SANDBOX"
    }
  }'
```

## Troubleshooting

### 401 Unauthorized
- Verify the `Authorization` header matches exactly: `Bearer <secret>`
- Check that `REVENUECAT_WEBHOOK_SECRET` is set correctly in Supabase secrets

### 500 Server Error
- Check Edge Function logs for detailed error messages
- Verify `profiles` table exists with `is_pro` column

### Profile Not Updated
- Ensure `app_user_id` in RevenueCat matches the Supabase user UUID
- Verify the profile exists in the `profiles` table
- Check that the iOS app is calling `SubscriptionManager.shared.syncUserIdentity()` on sign-in

## Security Notes

1. **Never expose the webhook secret** in client-side code
2. **Use HTTPS only** - Supabase Edge Functions enforce this
3. **Validate UUID format** to prevent injection attacks
4. **Service role key** bypasses RLS - the function updates any user's profile
