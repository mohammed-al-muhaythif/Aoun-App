-- 0021: Re-write the tasks SELECT policy so committee heads see ALL
-- tasks where any of their committee's members is assigned (not just
-- tasks assigned to the committee as a whole).
--
-- Visibility matrix:
--   * Club admin (is_club_president = president/vice/board/leader/vice-leader/app_admin)
--       → all tasks
--   * Regular member
--       → tasks assigned to them, or to a committee they're a member of
--   * Committee head/vice-head
--       → above + tasks assigned to any user who is in their committee

drop policy if exists "tasks: read by participants/heads/president"
  on public.tasks;

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
          -- 4. caller is in a committee assigned to the task
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
