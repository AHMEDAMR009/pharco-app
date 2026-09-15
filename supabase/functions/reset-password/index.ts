// Resets an employee's login password to the fixed default "Ph@123" —
// mirrors the original app's admin/self-service reset (no email, no link:
// these accounts don't have real inboxes, so the "reset" is just re-arming a
// known default password, exactly like the original ResetPassword flow).
//
// Deploy: supabase functions deploy reset-password
// Calls Supabase Auth's admin API, so it must run server-side with the
// service-role key — never embed that key in the Flutter app.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const DEFAULT_RESET_PASSWORD = 'Ph@123';

// Browsers (unlike curl or mobile apps) block cross-origin fetches without
// these headers, and send a preflight OPTIONS request first — both must be
// handled or the Flutter Web build's "Forgot password?" call fails silently
// with a generic "Failed to fetch".
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const { code } = await req.json();
    if (!code || typeof code !== 'string') {
      return new Response(JSON.stringify({ error: 'Missing "code"' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const { data: employee, error: lookupError } = await admin
      .from('employees')
      .select('id')
      .eq('code', code.trim())
      .maybeSingle();

    if (lookupError) throw lookupError;
    if (!employee) {
      return new Response(JSON.stringify({ error: 'No employee found with that code' }), {
        status: 404,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { error: updateError } = await admin.auth.admin.updateUserById(employee.id, {
      password: DEFAULT_RESET_PASSWORD,
    });
    if (updateError) throw updateError;

    return new Response(JSON.stringify({ success: true }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
