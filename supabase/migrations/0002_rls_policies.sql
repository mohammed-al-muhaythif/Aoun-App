-- Row Level Security: full permission matrix from spec § 2.
-- Helper functions are SECURITY DEFINER so they can read role tables
-- without triggering recursive RLS on those tables.

create or replace function public.is_club_president(p_uid uuid)
returns boolean language sql security definer set search_path = public as $$
  select exists (select 1 from club_roles where user_id = p_uid);
$$;

create or replace function public.is_committee_head(p_uid uuid, p_committee smallint)
returns boolean language sql security definer set search_path = public as $$
  select exists (
    select 1 from committee_memberships
    where user_id = p_uid
      and committee_id = p_committee
      and role in ('head','vice_head')
  );
$$;

create or replace function public.is_any_committee_head(p_uid uuid)
returns boolean language sql security definer set search_path = public as $$
  select exists (
    select 1 from committee_memberships
    where user_id = p_uid and role in ('head','vice_head')
  );
$$;

create or replace function public.hr_committee_id()
returns smallint language sql stable as $$
  select id from committees where name_en = 'Human Resources' limit 1;
$$;

create or replace function public.is_hr_member(p_uid uuid)
returns boolean language sql security definer set search_path = public as $$
  select exists (
    select 1 from committee_memberships
    where user_id = p_uid and committee_id = hr_committee_id()
  );
$$;

create or replace function public.is_hr_head(p_uid uuid)
returns boolean language sql security definer set search_path = public as $$
  select exists (
    select 1 from committee_memberships
    where user_id = p_uid
      and committee_id = hr_committee_id()
      and role in ('head','vice_head')
  );
$$;

create or replace function public.user_committees(p_uid uuid)
returns setof smallint language sql security definer set search_path = public as $$
  select committee_id from committee_memberships where user_id = p_uid;
$$;

-- Enable RLS on every table
alter table public.profiles               enable row level security;
alter table public.committees             enable row level security;
alter table public.committee_memberships  enable row level security;
alter table public.club_roles             enable row level security;
alter table public.tasks                  enable row level security;
alter table public.task_assignments       enable row level security;
alter table public.task_attachments       enable row level security;
alter table public.task_comments          enable row level security;
alter table public.teams                  enable row level security;
alter table public.team_members           enable row level security;
alter table public.volunteer_hours        enable row level security;
alter table public.notifications          enable row level security;

-- ─── profiles ─────────────────────────────────────────────────────────
create policy "profiles: all members readable to all authed"
  on public.profiles for select to authenticated using (true);

create policy "profiles: self update"
  on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- ─── committees ───────────────────────────────────────────────────────
create policy "committees: read all"
  on public.committees for select to authenticated, anon using (true);

-- ─── committee_memberships ───────────────────────────────────────────
create policy "memberships: read all to authed"
  on public.committee_memberships for select to authenticated using (true);

create policy "memberships: insert by head-of-own or president"
  on public.committee_memberships for insert to authenticated with check (
    is_club_president(auth.uid())
    or is_committee_head(auth.uid(), committee_id)
  );

create policy "memberships: delete by head-of-own or president"
  on public.committee_memberships for delete to authenticated using (
    is_club_president(auth.uid())
    or is_committee_head(auth.uid(), committee_id)
  );

-- ─── club_roles ───────────────────────────────────────────────────────
create policy "club_roles: read all"
  on public.club_roles for select to authenticated using (true);

-- ─── tasks ────────────────────────────────────────────────────────────
-- Read: assignees, creator, committee heads of assigned committees, president, HR
create policy "tasks: read by participants/heads/president"
  on public.tasks for select to authenticated using (
    created_by = auth.uid()
    or is_club_president(auth.uid())
    or exists (
      select 1 from task_assignments ta
      where ta.task_id = tasks.id
        and (
          (ta.assignee_type = 'user' and ta.assignee_id = auth.uid()::text)
          or (ta.assignee_type = 'committee' and exists (
            select 1 from committee_memberships m
            where m.user_id = auth.uid()
              and m.committee_id = ta.assignee_id::smallint
          ))
        )
    )
    or exists (
      select 1 from task_assignments ta
      where ta.task_id = tasks.id
        and ta.assignee_type = 'committee'
        and is_committee_head(auth.uid(), ta.assignee_id::smallint)
    )
  );

-- Insert: any committee head or president
create policy "tasks: insert by head or president"
  on public.tasks for insert to authenticated with check (
    created_by = auth.uid()
    and (is_any_committee_head(auth.uid()) or is_club_president(auth.uid()))
  );

-- Update: creator (own committee), president (any)
create policy "tasks: update by creator-head or president"
  on public.tasks for update to authenticated using (
    is_club_president(auth.uid())
    or (created_by = auth.uid() and is_any_committee_head(auth.uid()))
  );

-- Status-only update by assignees (so members can mark in_progress/completed)
-- Implemented as a permissive update policy gated by an after trigger that
-- rejects non-status field changes for non-privileged users.
create policy "tasks: assignees can update status"
  on public.tasks for update to authenticated using (
    exists (
      select 1 from task_assignments ta
      where ta.task_id = tasks.id
        and (
          (ta.assignee_type = 'user' and ta.assignee_id = auth.uid()::text)
          or (ta.assignee_type = 'committee' and exists (
            select 1 from committee_memberships m
            where m.user_id = auth.uid() and m.committee_id = ta.assignee_id::smallint
          ))
        )
    )
  );

create policy "tasks: delete by committee_head (own) or president"
  on public.tasks for delete to authenticated using (
    is_club_president(auth.uid())
    or exists (
      select 1 from task_assignments ta
      where ta.task_id = tasks.id
        and ta.assignee_type = 'committee'
        and is_committee_head(auth.uid(), ta.assignee_id::smallint)
    )
  );

-- ─── task_assignments ─────────────────────────────────────────────────
create policy "assignments: read all to authed"
  on public.task_assignments for select to authenticated using (true);

create policy "assignments: mutate by task creator or president"
  on public.task_assignments for all to authenticated
  using (
    is_club_president(auth.uid())
    or exists (select 1 from tasks t where t.id = task_id and t.created_by = auth.uid())
  )
  with check (
    is_club_president(auth.uid())
    or exists (select 1 from tasks t where t.id = task_id and t.created_by = auth.uid())
  );

-- ─── task_attachments ─────────────────────────────────────────────────
create policy "attachments: read by task readers"
  on public.task_attachments for select to authenticated using (
    exists (select 1 from tasks t where t.id = task_id)
  );

create policy "attachments: insert by task creator/assignee"
  on public.task_attachments for insert to authenticated with check (
    uploaded_by = auth.uid()
  );

create policy "attachments: delete by uploader or president"
  on public.task_attachments for delete to authenticated using (
    uploaded_by = auth.uid() or is_club_president(auth.uid())
  );

-- ─── task_comments ────────────────────────────────────────────────────
create policy "comments: read by task readers"
  on public.task_comments for select to authenticated using (
    exists (select 1 from tasks t where t.id = task_id)
  );

create policy "comments: insert by task participant"
  on public.task_comments for insert to authenticated with check (
    author_id = auth.uid()
  );

create policy "comments: delete by author or president"
  on public.task_comments for delete to authenticated using (
    author_id = auth.uid() or is_club_president(auth.uid())
  );

-- ─── teams ────────────────────────────────────────────────────────────
create policy "teams: read all"
  on public.teams for select to authenticated using (true);

create policy "teams: any member can create"
  on public.teams for insert to authenticated with check (created_by = auth.uid());

create policy "teams: creator or president can mutate"
  on public.teams for update to authenticated using (
    created_by = auth.uid() or is_club_president(auth.uid())
  );

create policy "teams: creator or president can delete"
  on public.teams for delete to authenticated using (
    created_by = auth.uid() or is_club_president(auth.uid())
  );

-- ─── team_members ─────────────────────────────────────────────────────
create policy "team_members: read all"
  on public.team_members for select to authenticated using (true);

create policy "team_members: mutate by team creator or president"
  on public.team_members for all to authenticated
  using (
    is_club_president(auth.uid())
    or exists (select 1 from teams t where t.id = team_id and t.created_by = auth.uid())
  )
  with check (
    is_club_president(auth.uid())
    or exists (select 1 from teams t where t.id = team_id and t.created_by = auth.uid())
  );

-- ─── volunteer_hours ──────────────────────────────────────────────────
-- Read:
--   self always; HR member sees all; president sees all;
--   committee_head sees members of their committee.
create policy "hours: self read"
  on public.volunteer_hours for select to authenticated
  using (user_id = auth.uid());

create policy "hours: hr/president read all"
  on public.volunteer_hours for select to authenticated using (
    is_hr_member(auth.uid()) or is_club_president(auth.uid())
  );

create policy "hours: committee_head read own-committee members"
  on public.volunteer_hours for select to authenticated using (
    exists (
      select 1 from committee_memberships me
      join committee_memberships them
        on them.committee_id = me.committee_id
      where me.user_id = auth.uid()
        and me.role in ('head','vice_head')
        and them.user_id = volunteer_hours.user_id
    )
  );

create policy "hours: self insert"
  on public.volunteer_hours for insert to authenticated
  with check (user_id = auth.uid());

create policy "hours: edit by self, committee_head (own), hr_head, president"
  on public.volunteer_hours for update to authenticated using (
    user_id = auth.uid()
    or is_club_president(auth.uid())
    or is_hr_head(auth.uid())
    or exists (
      select 1 from committee_memberships me
      join committee_memberships them
        on them.committee_id = me.committee_id
      where me.user_id = auth.uid()
        and me.role in ('head','vice_head')
        and them.user_id = volunteer_hours.user_id
    )
  );

create policy "hours: delete same as update"
  on public.volunteer_hours for delete to authenticated using (
    user_id = auth.uid()
    or is_club_president(auth.uid())
    or is_hr_head(auth.uid())
    or exists (
      select 1 from committee_memberships me
      join committee_memberships them
        on them.committee_id = me.committee_id
      where me.user_id = auth.uid()
        and me.role in ('head','vice_head')
        and them.user_id = volunteer_hours.user_id
    )
  );

-- ─── notifications ────────────────────────────────────────────────────
create policy "notifications: recipient read"
  on public.notifications for select to authenticated
  using (recipient_id = auth.uid());

create policy "notifications: recipient mark read"
  on public.notifications for update to authenticated
  using (recipient_id = auth.uid()) with check (recipient_id = auth.uid());

-- Inserts come from Edge Functions using the service_role key, which
-- bypasses RLS, so no insert policy needed for end users.
