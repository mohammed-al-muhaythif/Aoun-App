-- 0023: Restrict team creation to club admins only.
--
-- Spec: only club president / vice president / board members /
-- club leader / vice leader / app_admin may create teams.
-- (`is_club_president` already covers all six roles.)

drop policy if exists "teams: any member can create" on public.teams;

create policy "teams: admin only can create"
  on public.teams for insert to authenticated
  with check (
    created_by = auth.uid()
    and is_club_president(auth.uid())
  );
