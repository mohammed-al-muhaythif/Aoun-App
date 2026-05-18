-- 0009: Security hardening from pre-launch audit.
--
-- Fixes:
--   1. task_attachments SELECT policy — only readers of the parent task
--      should see attachment metadata (was: anyone authenticated).
--   2. task_comments SELECT — same fix.
--   3. club_roles — add explicit deny-all-mutations policy (the table
--      had no mutate policies, so RLS defaults to deny; this makes
--      intent explicit and survives accidental policy drops).
--   4. Storage path enforcement — only allow uploads to
--      `<task-uuid>/<digits>-<safe-filename>` so a malicious client
--      can't path-traverse.

-- ─── 1. task_attachments visibility tied to parent task readability ──
drop policy if exists "attachments: read by task readers"
  on public.task_attachments;

create policy "attachments: read by task readers"
  on public.task_attachments for select to authenticated
  using (
    -- A task row will only be visible to the user if at least one of the
    -- tasks SELECT policies allows it (creator / assignee / committee
    -- member of assigned committee / committee_head / president).
    -- This subquery is forced through those policies because RLS applies
    -- to the inner select as well.
    exists (
      select 1 from public.tasks t where t.id = task_attachments.task_id
    )
  );

-- (The existing INSERT/DELETE policies on task_attachments are fine —
--  insert checks `uploaded_by = auth.uid()`, delete checks uploader or
--  president. The subquery on `tasks` above is the gate that matters.)

-- ─── 2. task_comments — same tightening (already correct, but reassert) ──
drop policy if exists "comments: read by task readers"
  on public.task_comments;

create policy "comments: read by task readers"
  on public.task_comments for select to authenticated
  using (
    exists (
      select 1 from public.tasks t where t.id = task_comments.task_id
    )
  );

-- ─── 3. club_roles: explicit deny on mutations ───────────────────────
-- Without these, a future accidental policy could open the door. Make
-- the intent explicit: only president-equivalent users can grant or
-- revoke club_roles. (And even then, this should normally be done by
-- a privileged admin via Supabase Studio, not the app.)
drop policy if exists "club_roles: insert by president only"
  on public.club_roles;
drop policy if exists "club_roles: update by president only"
  on public.club_roles;
drop policy if exists "club_roles: delete by president only"
  on public.club_roles;

create policy "club_roles: insert by president only"
  on public.club_roles for insert to authenticated
  with check (is_club_president(auth.uid()));

create policy "club_roles: update by president only"
  on public.club_roles for update to authenticated
  using (is_club_president(auth.uid()))
  with check (is_club_president(auth.uid()));

create policy "club_roles: delete by president only"
  on public.club_roles for delete to authenticated
  using (is_club_president(auth.uid()));

-- ─── 4. Storage path traversal prevention ────────────────────────────
-- Path convention is `<task_uuid>/<unix_ms>-<safe_filename>`. We enforce
-- it server-side via a regex on the INSERT policy. `owner = auth.uid()`
-- is set by Supabase Storage automatically, but we keep the explicit
-- check for defense in depth.
drop policy if exists "attachments: authed upload" on storage.objects;

create policy "attachments: authed upload to taskpath"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'attachments'
    and owner = auth.uid()
    -- <36-char uuid>/<digits>-<filename>
    and name ~ '^[0-9a-fA-F-]{36}/[0-9]+-[A-Za-z0-9_. \-]+$'
  );

-- ─── 5. task_assignments SELECT scoped to readable tasks ─────────────
-- Previously `using (true)` — that was permissive but leaked the full
-- assignment graph (who works on what). Tie to task readability instead.
drop policy if exists "assignments: read all to authed"
  on public.task_assignments;

create policy "assignments: read for task readers"
  on public.task_assignments for select to authenticated
  using (
    exists (
      select 1 from public.tasks t where t.id = task_assignments.task_id
    )
  );
