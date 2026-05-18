/// <reference path="../_shared/deno.d.ts" />
// DEPRECATED — use the SQL seed in supabase/migrations/0006_real_member_seed.sql instead.
//
// This Edge Function couldn't seed ~160 users in a single invocation
// (WORKER_RESOURCE_LIMIT after admin API roundtrips). The migration runs
// purely inside Postgres via bcrypt(crypt()), no HTTP per user.
//
// Keeping a no-op handler so the deployed function URL doesn't 404 mysteriously.

Deno.serve(() =>
  new Response(
    JSON.stringify({
      ok: false,
      deprecated: true,
      message:
        'Seeding moved to SQL. Run: supabase db push (migration 0006_real_member_seed.sql).',
    }),
    { status: 410, headers: { 'Content-Type': 'application/json' } },
  ),
);
