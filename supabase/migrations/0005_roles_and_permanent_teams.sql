-- Phase 2 corrections:
--  - Extend club_roles to include board_member, club_leader, club_vice_leader, app_admin
--    (all with president-equivalent permissions)
--  - Add is_permanent flag to teams (cannot be deleted)
--  - Add role column to team_members for leader/vice/member within a team
--  - Update is_club_president to recognize all admin roles
--  - Add lookup helper for phone+universityId login (used by the Flutter login screen)
--  - Store university_id + phone on profiles for display and ID lookups

alter table public.profiles
  add column if not exists university_id text unique,
  add column if not exists phone text;

-- ─── extend allowed club_roles ──────────────────────────────────────
alter table public.club_roles
  drop constraint if exists club_roles_role_check;

alter table public.club_roles
  add constraint club_roles_role_check
  check (role in (
    'president', 'vice_president',
    'board_member', 'club_leader', 'club_vice_leader',
    'app_admin'
  ));

-- ─── extend teams ────────────────────────────────────────────────────
alter table public.teams
  add column if not exists is_permanent boolean not null default false,
  add column if not exists parent_committee_id smallint references public.committees(id);

alter table public.team_members
  add column if not exists role text not null default 'member'
    check (role in ('leader', 'vice_leader', 'member'));

-- ─── helper functions: update president check + add convenience ──────
create or replace function public.is_club_president(p_uid uuid)
returns boolean language sql security definer set search_path = public as $$
  select exists (
    select 1 from club_roles
    where user_id = p_uid
      and role in (
        'president', 'vice_president',
        'board_member', 'club_leader', 'club_vice_leader',
        'app_admin'
      )
  );
$$;

-- Lookup function used by the login screen.
-- Returns the synthetic email for a user whose normalized phone + uni id match.
-- Runs as security definer so the anon client can look up without seeing other rows.
create or replace function public.lookup_login_email(
  p_phone text,
  p_university_id text
) returns text
language plpgsql security definer set search_path = public, auth as $$
declare
  v_user_id uuid;
  v_email   text;
  v_phone_norm text;
begin
  -- normalize phone: keep digits only, strip leading 966 then leading 0
  v_phone_norm := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  if v_phone_norm like '966%' then
    v_phone_norm := substring(v_phone_norm from 4);
  end if;
  if v_phone_norm like '0%' then
    v_phone_norm := substring(v_phone_norm from 2);
  end if;

  select id into v_user_id
  from profiles
  where university_id = p_university_id
    and regexp_replace(coalesce(phone, ''), '\D', '', 'g') = v_phone_norm
  limit 1;

  if v_user_id is null then return null; end if;

  select email into v_email from auth.users where id = v_user_id;
  return v_email;
end $$;

grant execute on function public.lookup_login_email(text, text) to anon, authenticated;

-- ─── RLS: prevent deletion of permanent teams ────────────────────────
drop policy if exists "teams: creator or president can delete" on public.teams;
create policy "teams: delete (non-permanent) by creator or president"
  on public.teams for delete to authenticated
  using (
    not is_permanent and (
      created_by = auth.uid() or is_club_president(auth.uid())
    )
  );

-- Leaders of permanent teams can also update/delete tasks within the team.
-- (For now we keep team_members RLS as-is; team-scoped task perms could
--  layer in later if needed.)
