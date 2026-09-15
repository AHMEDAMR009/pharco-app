// Creates a new employee account: an Auth user (email = "{code}@pharco.local",
// starting password = the default "123456", same as the original app) plus
// its matching row in public.employees. This is an admin/back-office action —
// employees don't self-register, matching how the original mobile app's
// users were provisioned.
//
// Deploy: supabase functions deploy provision-employee
// Call this from an admin tool (or the Supabase dashboard's function
// invoker), never from the employee-facing Flutter app.

import { createClient } from 'jsr:@supabase/supabase-js@2';

const DEFAULT_PASSWORD = '123456';

// Browsers (unlike curl or mobile apps) block cross-origin fetches without
// these headers, and send a preflight OPTIONS request first.
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const body = await req.json();
    const { code, fullName, email, phone, titleId, territoryId, governorateId, managerId, managerType } = body;

    if (!code || !fullName) {
      return new Response(JSON.stringify({ error: 'Missing "code" or "fullName"' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const admin = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,
    );

    const authEmail = `${String(code).trim().toLowerCase()}@pharco.local`;

    const { data: created, error: createError } = await admin.auth.admin.createUser({
      email: authEmail,
      password: DEFAULT_PASSWORD,
      email_confirm: true,
    });
    if (createError) throw createError;

    const { error: insertError } = await admin.from('employees').insert({
      id: created.user.id,
      code,
      full_name: fullName,
      email: email ?? null,
      phone: phone ?? null,
      title_id: titleId ?? null,
      territory_id: territoryId ?? null,
      governorate_id: governorateId ?? null,
      manager_id: managerId ?? null,
      manager_type: managerType ?? 0,
    });
    if (insertError) {
      // Roll back the auth user so we don't leave an orphaned account.
      await admin.auth.admin.deleteUser(created.user.id);
      throw insertError;
    }

    return new Response(
      JSON.stringify({ success: true, employeeId: created.user.id, authEmail, defaultPassword: DEFAULT_PASSWORD }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    return new Response(JSON.stringify({ error: String(err) }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
