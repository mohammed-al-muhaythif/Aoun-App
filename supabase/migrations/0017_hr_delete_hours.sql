-- 0017: Broaden volunteer_hours DELETE to all HR committee members
-- + club president/board/leader/admin (already covered by is_club_president).
--
-- Previous policy (from 0002) allowed: self, president, hr_head only.
-- Now: any HR member can delete any row.

drop policy if exists "hours: delete same as update" on public.volunteer_hours;

create policy "hours: delete (self / hr-any / president / committee-head-own)"
  on public.volunteer_hours for delete to authenticated using (
    user_id = auth.uid()
    or is_club_president(auth.uid())
    or is_hr_member(auth.uid())  -- entire HR committee, not just head
    or exists (
      select 1 from committee_memberships me
      join committee_memberships them
        on them.committee_id = me.committee_id
      where me.user_id = auth.uid()
        and me.role in ('head','vice_head')
        and them.user_id = volunteer_hours.user_id
    )
  );
