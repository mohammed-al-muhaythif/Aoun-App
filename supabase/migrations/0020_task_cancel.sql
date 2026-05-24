-- 0020: add a 'cancelled' status for tasks + broaden delete permission.
--
-- Changes:
--   1. tasks.status check: add 'cancelled' to the allowed values
--   2. tasks DELETE RLS: allow the task's creator (not just admin /
--      committee head of an assigned committee)
--   3. tasks UPDATE RLS: allow the creator to change status (covers the
--      cancel action without granting full edit rights)
--
-- Overdue scanner (0011) already excludes finalized statuses — it only
-- flips pending/in_progress, so cancelled tasks are safe.

-- ─── 1. extend the status check ──────────────────────────────────────
alter table public.tasks
  drop constraint if exists tasks_status_check;

alter table public.tasks
  add constraint tasks_status_check
  check (status in ('pending', 'in_progress', 'completed', 'overdue', 'cancelled'));

-- ─── 2. broaden DELETE to include the creator ────────────────────────
drop policy if exists "tasks: delete by committee_head (own) or president"
  on public.tasks;

create policy "tasks: delete by creator / head / president"
  on public.tasks for delete to authenticated using (
    is_club_president(auth.uid())
    or created_by = auth.uid()
    or exists (
      select 1 from task_assignments ta
      where ta.task_id = tasks.id
        and ta.assignee_type = 'committee'
        and is_committee_head(auth.uid(), ta.assignee_id::smallint)
    )
  );

-- ─── 3. UPDATE policy: add creator path (used for cancel) ────────────
drop policy if exists "tasks: update by creator-head or president"
  on public.tasks;

create policy "tasks: update by creator / head / president"
  on public.tasks for update to authenticated using (
    is_club_president(auth.uid())
    or created_by = auth.uid()
    or exists (
      select 1 from task_assignments ta
      where ta.task_id = tasks.id
        and ta.assignee_type = 'committee'
        and is_committee_head(auth.uid(), ta.assignee_id::smallint)
    )
  );
