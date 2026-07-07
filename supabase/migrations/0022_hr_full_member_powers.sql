-- 0022: Expand `is_hr_or_admin` to include ALL Human Resources committee
-- members (not just head/vice_head).
--
-- Per spec: HR committee head + vice + every regular HR member can
-- manage members across all committees (edit info, add/remove, promote
-- up to head, delete from system).
--
-- Touches RPC helpers from 0015. The committee-membership policies in
-- 0002 still gate at the table level on top of these.

create or replace function public.is_hr_or_admin(p_uid uuid)
returns boolean
language sql
security definer
set search_path = public, extensions as $$
  select is_club_president(p_uid) or is_hr_member(p_uid);
$$;

-- Broaden committee_memberships insert / delete to recognize HR members
-- as well as committee heads / admins.
drop policy if exists "memberships: insert by head-of-own or president"
  on public.committee_memberships;
drop policy if exists "memberships: delete by head-of-own or president"
  on public.committee_memberships;

create policy "memberships: insert by head-of-own / hr / president"
  on public.committee_memberships for insert to authenticated
  with check (
    is_club_president(auth.uid())
    or is_hr_member(auth.uid())
    or is_committee_head(auth.uid(), committee_id)
  );

create policy "memberships: update by head-of-own / hr / president"
  on public.committee_memberships for update to authenticated
  using (
    is_club_president(auth.uid())
    or is_hr_member(auth.uid())
    or is_committee_head(auth.uid(), committee_id)
  );

create policy "memberships: delete by head-of-own / hr / president"
  on public.committee_memberships for delete to authenticated
  using (
    is_club_president(auth.uid())
    or is_hr_member(auth.uid())
    or is_committee_head(auth.uid(), committee_id)
  );
