-- 0010: Add automated notification when a member is added to a team.
--
-- Mirrors `on_membership_inserted` for committees (in 0004) but for
-- the `team_members` table. The dispatch-push cron job picks up the
-- new notification row and sends the OneSignal push.

create or replace function public.on_team_member_inserted()
returns trigger
language plpgsql
security definer
set search_path = public as $$
declare
  v_team_name text;
begin
  select name into v_team_name from public.teams where id = new.team_id;
  if v_team_name is null then return new; end if;

  perform public.enqueue_notification(
    new.user_id,
    'تمت إضافتك إلى فريق',
    v_team_name,
    'team_added',
    new.team_id::text
  );
  return new;
end $$;

drop trigger if exists team_member_notify on public.team_members;
create trigger team_member_notify
  after insert on public.team_members
  for each row execute function public.on_team_member_inserted();
