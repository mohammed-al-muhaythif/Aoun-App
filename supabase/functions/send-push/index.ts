/// <reference path="../_shared/deno.d.ts" />
// Edge Function: send-push
// Sends a OneSignal push to one or more users (by Supabase user id used as external_id).
//
// Body: { user_ids: string[], title: string, body: string, related_id?: string }
// Returns: { ok: true } | { ok: false, error: string }
//
// Auth: requires the standard Supabase JWT (caller must be authenticated).
// Permission check (manual composer use):
//   Only club president/vice + committee heads/vice + Technology members may send.
//
// Deploy: supabase functions deploy send-push
// Secret:  supabase secrets set ONESIGNAL_REST_KEY=os_v2_app_...
//          supabase secrets set ONESIGNAL_APP_ID=abb7b442-f4dc-4e76-a7fa-80a721ec2739

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const ONESIGNAL_APP_ID  = Deno.env.get('ONESIGNAL_APP_ID')!;
const ONESIGNAL_REST_KEY = Deno.env.get('ONESIGNAL_REST_KEY')!;
const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

function corsHeaders() {
  return {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
  };
}

// Allowed senders (per product spec):
//   - All club_roles (president / vice / board / leader / vice-leader / app_admin)
//   - All committee heads and vice-heads (any committee)
//   - All members of the Technology committee
// Plain members from other committees: blocked.
async function isAllowedSender(jwt: string): Promise<boolean> {
  const user = createClient(SUPABASE_URL, SERVICE_KEY, {
    global: { headers: { Authorization: jwt } },
  });
  const { data: { user: u } } = await user.auth.getUser();
  if (!u) return false;

  const admin = createClient(SUPABASE_URL, SERVICE_KEY);

  // 1. Any club_roles entry → allow.
  const { data: club } = await admin.from('club_roles')
    .select('role').eq('user_id', u.id).maybeSingle();
  if (club) return true;

  // 2. Otherwise check committee memberships.
  const { data: ms } = await admin.from('committee_memberships')
    .select('role, committees!inner(name_en)')
    .eq('user_id', u.id);
  if (!ms) return false;
  for (const m of ms as Array<{ role: string; committees: { name_en: string } }>) {
    if (m.role === 'head' || m.role === 'vice_head') return true;
    if (m.committees.name_en === 'Technology') return true;
  }
  return false;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders() });
  }

  try {
    const jwt = req.headers.get('Authorization');
    if (!jwt) {
      return new Response(JSON.stringify({ ok: false, error: 'no jwt' }), {
        status: 401, headers: { ...corsHeaders(), 'Content-Type': 'application/json' },
      });
    }
    if (!await isAllowedSender(jwt)) {
      return new Response(JSON.stringify({ ok: false, error: 'forbidden' }), {
        status: 403, headers: { ...corsHeaders(), 'Content-Type': 'application/json' },
      });
    }

    const { user_ids, title, body, related_id } = await req.json();
    if (!Array.isArray(user_ids) || user_ids.length === 0 || !title || !body) {
      return new Response(JSON.stringify({ ok: false, error: 'bad payload' }), {
        status: 400, headers: { ...corsHeaders(), 'Content-Type': 'application/json' },
      });
    }

    // 1. Write in-app notification rows (so they appear in the bell instantly).
    const admin = createClient(SUPABASE_URL, SERVICE_KEY);
    await admin.from('notifications').insert(
      user_ids.map((uid: string) => ({
        recipient_id: uid,
        title, body,
        type: 'manual',
        related_id: related_id ?? null,
        push_sent: true,  // we send below; avoid double-send via dispatcher
      })),
    );

    // 2. Send the OneSignal push.
    const osRes = await fetch('https://api.onesignal.com/notifications', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Key ${ONESIGNAL_REST_KEY}`,
      },
      body: JSON.stringify({
        app_id: ONESIGNAL_APP_ID,
        include_aliases: { external_id: user_ids },
        target_channel: 'push',
        headings: { ar: title, en: title },
        contents: { ar: body, en: body },
        data: { related_id: related_id ?? null },
      }),
    });
    const osBody = await osRes.text();
    if (!osRes.ok) {
      return new Response(JSON.stringify({ ok: false, error: osBody }), {
        status: 502, headers: { ...corsHeaders(), 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ ok: true, onesignal: JSON.parse(osBody) }), {
      headers: { ...corsHeaders(), 'Content-Type': 'application/json' },
    });
  } catch (e) {
    return new Response(JSON.stringify({ ok: false, error: String(e) }), {
      status: 500, headers: { ...corsHeaders(), 'Content-Type': 'application/json' },
    });
  }
});
