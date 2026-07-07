-- 0028: Deliver AUTOMATED notifications (task assigned, comment, hours
-- logged, member added, overdue, ...) as DEVICE PUSH within seconds.
--
-- Those are inserted into public.notifications with push_sent = false and
-- previously relied on the dispatch-push edge function being pinged by an
-- (unreliable) external GitHub cron. Instead, this statement-level trigger
-- pings dispatch-push via pg_net right after the rows are inserted, so they
-- are drained and pushed immediately — server-side, no external scheduler.
--
-- NOTE: replace REPLACE_WITH_PROJECT_REF and REPLACE_WITH_CRON_SECRET below
-- with your Supabase project ref and the CRON_SECRET value configured in the
-- project's Edge Function secrets (Settings → Edge Functions → Secrets).
-- The send-push path inserts rows with push_sent=true, so this never
-- double-sends them.

create or replace function public.ping_dispatch_push()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  perform net.http_post(
    url := 'https://REPLACE_WITH_PROJECT_REF.supabase.co/functions/v1/dispatch-push',
    body := '{}'::jsonb,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-cron-secret', 'REPLACE_WITH_CRON_SECRET'
    )
  );
  return null;
end $$;

drop trigger if exists notifications_auto_dispatch on public.notifications;
create trigger notifications_auto_dispatch
  after insert on public.notifications
  for each statement
  execute function public.ping_dispatch_push();
