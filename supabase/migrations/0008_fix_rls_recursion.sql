-- 0008: Fix infinite-recursion in task_assignments / team_members RLS.
--
-- Symptom: PostgrestException 42P17 "infinite recursion detected in
-- policy for relation 'task_assignments'" whenever the client joins
-- tasks with task_assignments (e.g. myVisibleTasksProvider).
--
-- Cause: the `for all` mutate policies on task_assignments and
-- team_members ALSO apply to SELECT. Their `using` clause queries the
-- parent table (`tasks` / `teams`). The parent table's SELECT policy
-- then re-queries the child — cycle.
--
-- Fix: replace the `for all` policies with explicit `for insert /
-- update / delete` policies, so the only SELECT policy on the child
-- table remains the simple `using (true)` one.

drop policy if exists "assignments: mutate by task creator or president"
  on public.task_assignments;

create policy "assignments: insert by task creator or president"
  on public.task_assignments for insert to authenticated
  with check (
    is_club_president(auth.uid())
    or exists (
      select 1 from tasks t where t.id = task_id and t.created_by = auth.uid()
    )
  );

create policy "assignments: update by task creator or president"
  on public.task_assignments for update to authenticated
  using (
    is_club_president(auth.uid())
    or exists (
      select 1 from tasks t where t.id = task_id and t.created_by = auth.uid()
    )
  );

create policy "assignments: delete by task creator or president"
  on public.task_assignments for delete to authenticated
  using (
    is_club_president(auth.uid())
    or exists (
      select 1 from tasks t where t.id = task_id and t.created_by = auth.uid()
    )
  );

drop policy if exists "team_members: mutate by team creator or president"
  on public.team_members;

create policy "team_members: insert by team creator or president"
  on public.team_members for insert to authenticated
  with check (
    is_club_president(auth.uid())
    or exists (
      select 1 from teams t where t.id = team_id and t.created_by = auth.uid()
    )
  );

create policy "team_members: update by team creator or president"
  on public.team_members for update to authenticated
  using (
    is_club_president(auth.uid())
    or exists (
      select 1 from teams t where t.id = team_id and t.created_by = auth.uid()
    )
  );

create policy "team_members: delete by team creator or president"
  on public.team_members for delete to authenticated
  using (
    is_club_president(auth.uid())
    or exists (
      select 1 from teams t where t.id = team_id and t.created_by = auth.uid()
    )
  );
