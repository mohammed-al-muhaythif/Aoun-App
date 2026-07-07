-- 0012: revert task_assignments SELECT policy to `using (true)`.
--
-- The 0009 hardening tied this policy to "task readable" via a
-- subquery on `tasks`. That re-introduced the same recursion that
-- 0008 fixed: tasks SELECT queries task_assignments → task_assignments
-- SELECT queries tasks → loop.
--
-- Trade-off: any authenticated member can read the full task-assignment
-- graph (who is assigned to which task). That's an info-level leak in
-- a closed club app — acceptable. Task BODY visibility is still gated
-- properly by the tasks SELECT policy, and attachments/comments are
-- gated through tasks. Only the assignment links are listable.

drop policy if exists "assignments: read for task readers"
  on public.task_assignments;

create policy "assignments: read all to authed"
  on public.task_assignments for select to authenticated
  using (true);
