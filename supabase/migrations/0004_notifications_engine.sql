-- Phase 2: automated notifications + overdue task scanner.
--
-- Architecture:
--   1. Triggers on tasks/comments/hours/memberships insert into
--      public.notifications with push_sent = false.
--   2. Realtime subscription in the Flutter app picks up new rows
--      instantly for in-app bell + badge.
--   3. The dispatch-push Edge Function (scheduled via pg_cron) reads
--      unsent rows and POSTs them to OneSignal, then flips push_sent.
--   4. A separate pg_cron job flips in_progress/pending tasks past
--      due_date to status = 'overdue', which itself fires a trigger.

create extension if not exists pg_net;
create extension if not exists pg_cron;

-- ─── extend the notifications table ──────────────────────────────────
alter table public.notifications
  add column if not exists push_sent boolean not null default false;

create index if not exists notifications_unsent_idx
  on public.notifications (push_sent, created_at)
  where push_sent = false;

-- ─── helper: enqueue a notification row ──────────────────────────────
create or replace function public.enqueue_notification(
  p_recipient uuid,
  p_title text,
  p_body text,
  p_type text,
  p_related_id text default null
) returns void
language plpgsql security definer set search_path = public as $$
begin
  if p_recipient is null then return; end if;
  insert into public.notifications (recipient_id, title, body, type, related_id)
  values (p_recipient, p_title, p_body, p_type, p_related_id);
end $$;

-- ─── trigger: task INSERT → notify assignees ─────────────────────────
create or replace function public.on_task_inserted()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  r record;
begin
  -- After INSERT, assignments may not exist yet (often inserted next).
  -- We rely on the task_assignments trigger below for the user-facing notify.
  return new;
end $$;

create or replace function public.on_assignment_inserted()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_task   tasks%rowtype;
  v_user_ids uuid[];
  u uuid;
begin
  select * into v_task from tasks where id = new.task_id;
  if not found then return new; end if;

  if new.assignee_type = 'user' then
    v_user_ids := array[new.assignee_id::uuid];
  else
    select array_agg(user_id) into v_user_ids
    from committee_memberships
    where committee_id = new.assignee_id::smallint;
  end if;

  if v_user_ids is null then return new; end if;

  foreach u in array v_user_ids loop
    perform enqueue_notification(
      u,
      'تم تعيين مهمة جديدة لك',
      v_task.title,
      'task_assigned',
      v_task.id::text
    );
  end loop;
  return new;
end $$;

drop trigger if exists task_assigned_notify on public.task_assignments;
create trigger task_assigned_notify
  after insert on public.task_assignments
  for each row execute function public.on_assignment_inserted();

-- ─── trigger: task status change (completed / overdue) ───────────────
create or replace function public.on_task_status_changed()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  recipients uuid[];
  u uuid;
  v_title text;
  v_body text;
begin
  if new.status = old.status then return new; end if;

  -- Recipients = creator + all user assignees + members of assigned committees
  select array_agg(distinct uid) into recipients from (
    select new.created_by as uid where new.created_by is not null
    union
    select assignee_id::uuid as uid from task_assignments
      where task_id = new.id and assignee_type = 'user'
    union
    select m.user_id as uid from task_assignments ta
      join committee_memberships m on m.committee_id = ta.assignee_id::smallint
      where ta.task_id = new.id and ta.assignee_type = 'committee'
  ) s;

  if new.status = 'completed' then
    v_title := '🎉 تم إكمال المهمة';
    v_body := new.title;
  elsif new.status = 'overdue' then
    v_title := 'مهمتك تجاوزت موعدها';
    v_body := new.title;
  else
    return new;
  end if;

  if recipients is null then return new; end if;
  foreach u in array recipients loop
    perform enqueue_notification(
      u, v_title, v_body,
      case new.status when 'completed' then 'task_completed' else 'task_overdue' end,
      new.id::text
    );
  end loop;
  return new;
end $$;

drop trigger if exists task_status_notify on public.tasks;
create trigger task_status_notify
  after update of status on public.tasks
  for each row execute function public.on_task_status_changed();

-- ─── trigger: comment INSERT → notify task participants ──────────────
create or replace function public.on_comment_inserted()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_task tasks%rowtype;
  v_author text;
  recipients uuid[];
  u uuid;
begin
  select * into v_task from tasks where id = new.task_id;
  if not found then return new; end if;

  select full_name into v_author from profiles where id = new.author_id;

  select array_agg(distinct uid) into recipients from (
    select v_task.created_by as uid where v_task.created_by is not null
    union
    select assignee_id::uuid from task_assignments
      where task_id = v_task.id and assignee_type = 'user'
    union
    select m.user_id from task_assignments ta
      join committee_memberships m on m.committee_id = ta.assignee_id::smallint
      where ta.task_id = v_task.id and ta.assignee_type = 'committee'
  ) s
  where uid <> new.author_id;  -- don't notify the commenter themselves

  if recipients is null then return new; end if;
  foreach u in array recipients loop
    perform enqueue_notification(
      u,
      'تعليق جديد على ' || v_task.title,
      coalesce(v_author, 'عضو') || ': ' || substr(new.body, 1, 80),
      'comment_added',
      v_task.id::text
    );
  end loop;
  return new;
end $$;

drop trigger if exists comment_notify on public.task_comments;
create trigger comment_notify
  after insert on public.task_comments
  for each row execute function public.on_comment_inserted();

-- ─── trigger: hours INSERT → confirmation to logger ──────────────────
create or replace function public.on_hours_inserted()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform enqueue_notification(
    new.user_id,
    '✅ تم تسجيل الساعات التطوعية',
    'تم تسجيل ' || new.hours || ' ساعة بنجاح',
    'hours_logged',
    new.id::text
  );
  return new;
end $$;

drop trigger if exists hours_logged_notify on public.volunteer_hours;
create trigger hours_logged_notify
  after insert on public.volunteer_hours
  for each row execute function public.on_hours_inserted();

-- ─── trigger: committee_memberships INSERT → notify added member ─────
create or replace function public.on_membership_inserted()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  v_name_ar text;
begin
  select name_ar into v_name_ar from committees where id = new.committee_id;
  perform enqueue_notification(
    new.user_id,
    'تمت إضافتك إلى لجنة',
    v_name_ar,
    'member_added',
    new.committee_id::text
  );
  return new;
end $$;

drop trigger if exists membership_notify on public.committee_memberships;
create trigger membership_notify
  after insert on public.committee_memberships
  for each row execute function public.on_membership_inserted();

-- ─── overdue scanner (pg_cron, every 30 min) ─────────────────────────
-- Flips tasks past their due date. The status-change trigger above
-- then emits the actual notification.
select cron.schedule(
  'scan-overdue-tasks',
  '*/30 * * * *',
  $$update public.tasks
    set status = 'overdue'
    where status in ('pending', 'in_progress')
      and due_date is not null
      and due_date < current_date$$
);

-- ─── enable realtime on notifications, task_comments, tasks ──────────
alter publication supabase_realtime add table public.notifications;
alter publication supabase_realtime add table public.task_comments;
alter publication supabase_realtime add table public.tasks;
alter publication supabase_realtime add table public.volunteer_hours;
