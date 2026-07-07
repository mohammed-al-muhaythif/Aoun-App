-- 0024: Grant the `app_admin` club role two exclusive god-mode
-- abilities that nobody else has:
--   1. Manage club_roles for ANY member (including removing/demoting
--      the president, putting people on the board, etc.)
--   2. Delete the 4 permanent media sub-teams.
--
-- All other admin-gated actions already work for app_admin because
-- `is_club_president()` includes 'app_admin' in its set since 0005.

-- ─── helper: is the caller app_admin? ────────────────────────────────
create or replace function public.is_app_admin(p_uid uuid)
returns boolean
language sql
security definer
set search_path = public as $$
  select exists (
    select 1 from club_roles
    where user_id = p_uid and role = 'app_admin'
  );
$$;

-- ─── set_club_role RPC (app_admin only) ──────────────────────────────
-- Sets / clears the club_role of a target user. Pass p_role = null to
-- remove the role entirely (back to a plain member).
create or replace function public.set_club_role(
  p_user_id uuid,
  p_role    text  -- null | 'president' | 'vice_president' | 'board_member'
                  --      | 'club_leader' | 'club_vice_leader' | 'app_admin'
) returns void
language plpgsql
security definer
set search_path = public as $$
declare
  v_caller uuid := auth.uid();
begin
  if not is_app_admin(v_caller) then
    raise exception 'only app_admin may change club roles';
  end if;

  if p_role is not null and p_role not in (
    'president', 'vice_president', 'board_member',
    'club_leader', 'club_vice_leader', 'app_admin'
  ) then
    raise exception 'invalid role: %', p_role;
  end if;

  -- one row per user; clear then re-insert
  delete from public.club_roles where user_id = p_user_id;
  if p_role is not null then
    insert into public.club_roles (user_id, role)
    values (p_user_id, p_role);
  end if;
end $$;

grant execute on function public.set_club_role(uuid, text) to authenticated;

-- ─── allow app_admin to delete permanent teams ───────────────────────
drop policy if exists "teams: delete (non-permanent) by creator or president"
  on public.teams;

create policy "teams: delete by app_admin (any) / creator / president (non-perm)"
  on public.teams for delete to authenticated using (
    -- app_admin can delete ANYTHING, including the 4 permanent teams
    is_app_admin(auth.uid())
    -- everyone else: only non-permanent + creator-or-president
    or (
      not is_permanent and (
        created_by = auth.uid() or is_club_president(auth.uid())
      )
    )
  );
