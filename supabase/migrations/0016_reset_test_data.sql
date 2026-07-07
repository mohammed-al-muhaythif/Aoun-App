-- 0016: Reset all test/demo data without touching schema, users, or
-- permanent teams.
--
-- Wipes:
--   * volunteer_hours
--   * tasks (cascades to assignments / attachments / comments)
--   * notifications (+ notification_logs if it exists)
--   * non-permanent teams + their members
--
-- Preserves:
--   * profiles, club_roles, committee_memberships
--   * 4 permanent media sub-teams
--   * schema / RLS / functions

delete from public.volunteer_hours;

-- task_assignments / task_attachments / task_comments have
-- `on delete cascade` on tasks (from migration 0001), so deleting tasks
-- wipes them too. We still issue explicit deletes for safety.
delete from public.task_assignments;
delete from public.task_attachments;
delete from public.task_comments;
delete from public.tasks;

delete from public.notifications;

-- notification_logs was mentioned in the spec but never actually
-- created in the schema. Skip it gracefully if it doesn't exist.
do $$ begin
  if to_regclass('public.notification_logs') is not null then
    execute 'delete from public.notification_logs';
  end if;
end $$;

-- non-permanent team members + teams
delete from public.team_members tm
  using public.teams t
  where tm.team_id = t.id and t.is_permanent = false;

delete from public.teams where is_permanent = false;
