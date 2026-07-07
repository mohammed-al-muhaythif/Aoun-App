/// <reference path="../_shared/deno.d.ts" />
// Edge Function: dispatch-push
// Drains public.notifications rows where push_sent = false and posts them to OneSignal.
// Called on a schedule (every minute) via Supabase Cron or pg_cron + pg_net.
//
// Auth: --no-verify-jwt (invoked by scheduler). Internally checks an x-cron-secret header
// to reject random callers.
//
// Deploy:
//   supabase functions deploy dispatch-push --no-verify-jwt
//   supabase secrets set CRON_SECRET=<random_string>
//
// Schedule (Supabase Cron UI, or pg_cron with pg_net):
//   curl -X POST https://<your-project-ref>.supabase.co/functions/v1/dispatch-push \
//     -H "x-cron-secret: <CRON_SECRET>"

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.0';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SERVICE_KEY  = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const ONESIGNAL_APP_ID  = Deno.env.get('ONESIGNAL_APP_ID')!;
const ONESIGNAL_REST_KEY = Deno.env.get('ONESIGNAL_REST_KEY')!;
const CRON_SECRET = Deno.env.get('CRON_SECRET')!;

const BATCH_SIZE = 100;

Deno.serve(async (req) => {
  if (req.headers.get('x-cron-secret') !== CRON_SECRET) {
    return new Response(JSON.stringify({ ok: false, error: 'forbidden' }), {
      status: 403, headers: { 'Content-Type': 'application/json' },
    });
  }

  const admin = createClient(SUPABASE_URL, SERVICE_KEY);
  const { data: rows, error } = await admin
    .from('notifications')
    .select('id, recipient_id, title, body, related_id, type')
    .eq('push_sent', false)
    .order('created_at', { ascending: true })
    .limit(BATCH_SIZE);
  if (error) {
    return new Response(JSON.stringify({ ok: false, error: error.message }), {
      status: 500, headers: { 'Content-Type': 'application/json' },
    });
  }
  if (!rows || rows.length === 0) {
    return new Response(JSON.stringify({ ok: true, sent: 0 }), {
      headers: { 'Content-Type': 'application/json' },
    });
  }

  let sent = 0, failed = 0;
  for (const r of rows) {
    try {
      const osRes = await fetch('https://api.onesignal.com/notifications', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Key ${ONESIGNAL_REST_KEY}`,
        },
        body: JSON.stringify({
          app_id: ONESIGNAL_APP_ID,
          include_aliases: { external_id: [r.recipient_id] },
          target_channel: 'push',
          headings: { ar: r.title, en: r.title },
          contents: { ar: r.body, en: r.body },
          data: { related_id: r.related_id, type: r.type },
        }),
      });
      if (osRes.ok) {
        await admin.from('notifications').update({ push_sent: true }).eq('id', r.id);
        sent++;
      } else {
        failed++;
      }
    } catch (_) {
      failed++;
    }
  }

  return new Response(JSON.stringify({ ok: true, sent, failed }), {
    headers: { 'Content-Type': 'application/json' },
  });
});
