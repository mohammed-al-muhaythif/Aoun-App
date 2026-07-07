-- 0026: Re-assert the tasks SELECT policy (idempotent).
--
-- Symptom on the live project: tasks were visible to ALL members. The
-- correct policy already exists in 0021 but was evidently not applied to the
-- live DB (or RLS was left disabled). This migration guarantees the final
-- state regardless of history: RLS on, the single correct policy in place.
--
-- Visibility matrix (confirmed with product owner):
--   • Club admin/president  → all tasks
--   • Task creator          → their own tasks
--   • Regular member        → tasks assigned to them, or assigned to a
--                             committee they belong to (NOT their colleagues'
--                             individual tasks)
--   • Committee head/vice    → above + tasks assigned to any user in their
--                             committee, and tasks assigned to their committee

alter table public.tasks enable row level security;

-- Drop any prior SELECT policy variants so only the canonical one remains.
drop policy if exists "tasks: read by participants/heads/president" on public.tasks;
drop policy if exists "tasks: read by participants/heads/admin"      on public.tasks;

create policy "tasks: read by participants/heads/admin"
  on public.tasks for select to authenticated using (
    -- 1. super admin
    is_club_president(auth.uid())
    -- 2. creator
    or created_by = auth.uid()
    or exists (
      select 1 from task_assignments ta
      where ta.task_id = tasks.id
        and (
          -- 3. directly assigned user
          (ta.assignee_type = 'user' and ta.assignee_id = auth.uid()::text)
          -- 4. caller is in a committee assigned to the task (whole-committee)
          or (ta.assignee_type = 'committee' and exists (
            select 1 from committee_memberships m
            where m.user_id = auth.uid()
              and m.committee_id = ta.assignee_id::smallint
          ))
          -- 5. caller heads a committee assigned to the task
          or (ta.assignee_type = 'committee'
              and is_committee_head(auth.uid(), ta.assignee_id::smallint))
          -- 6. caller heads a committee that the assigned user belongs to
          or (ta.assignee_type = 'user' and exists (
            select 1
              from committee_memberships head_m
              join committee_memberships assignee_m
                on assignee_m.committee_id = head_m.committee_id
             where head_m.user_id = auth.uid()
               and head_m.role in ('head', 'vice_head')
               and assignee_m.user_id = ta.assignee_id::uuid
          ))
        )
    )
  );
