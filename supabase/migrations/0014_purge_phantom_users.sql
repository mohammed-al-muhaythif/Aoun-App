-- 0014: Purge phantom/test users left over from the failed Edge Function
-- seeder that ran before migration 0006 was applied.
--
-- Symptom: opening the committee dashboard shows fabricated members
-- that exist in auth.users + profiles + committee_memberships but are
-- not in the canonical roster.
--
-- Strategy: build the set of canonical user_ids (from the seeded
-- university_ids), then cascade-delete every other row across all
-- related tables.
--
-- NOTE: university IDs below are the placeholder demo IDs seeded in
-- migration 0006. If you replaced the demo roster, update these too.

do $$
declare
  v_canonical_unis text[] := array[
    -- ── Board ───────────────────────────────────────────
    '400000001','400000002',
    -- ── Leadership ──────────────────────────────────────
    '400000003','400000004',
    -- ── Committee heads / vices ─────────────────────────
    '400000005','400000006','400000007','400000008','400000009',
    '400000010','400000011','400000012','400000013','400000014',
    '400000015','400000016','400000017','400000018','400000019',
    '400000020',
    -- ── App admin ───────────────────────────────────────
    '400000021',
    -- ── Committee members ───────────────────────────────
    '400000022','400000023','400000024','400000025','400000026',
    '400000027','400000028',
    -- ── Multi-committee ─────────────────────────────────
    '400000029',
    -- ── Permanent-team leaders / vices / members ────────
    '400000030','400000031','400000032','400000033','400000034',
    '400000035','400000036','400000037','400000038','400000039'
  ];
  v_keep_user_ids uuid[];
  v_phantom_count int;
begin
  -- Build the set of user_ids that are allowed to remain.
  select array_agg(id) into v_keep_user_ids
    from public.profiles
   where university_id = any(v_canonical_unis);

  if v_keep_user_ids is null then
    raise notice 'No canonical users found — aborting purge.';
    return;
  end if;

  -- How many phantom users are we about to remove?
  select count(*) into v_phantom_count
    from public.profiles
   where id <> all(v_keep_user_ids);
  raise notice 'Purging % phantom users.', v_phantom_count;

  -- ─── delete dependent rows by user_id ───────────────────
  delete from public.team_members
    where user_id <> all(v_keep_user_ids);

  delete from public.committee_memberships
    where user_id <> all(v_keep_user_ids);

  delete from public.club_roles
    where user_id <> all(v_keep_user_ids);

  delete from public.volunteer_hours
    where user_id <> all(v_keep_user_ids);

  delete from public.notifications
    where recipient_id <> all(v_keep_user_ids);

  -- task_assignments uses text 'user' assignee_id
  delete from public.task_assignments
    where assignee_type = 'user'
      and assignee_id::uuid <> all(v_keep_user_ids);

  delete from public.task_comments
    where author_id <> all(v_keep_user_ids);

  delete from public.task_attachments
    where uploaded_by is not null
      and uploaded_by <> all(v_keep_user_ids);

  -- Tasks created by phantom users: keep the task but null the creator
  -- so we don't lose work. (Likely there are zero such tasks since
  -- phantoms never logged in.)
  update public.tasks
     set created_by = null
   where created_by is not null
     and created_by <> all(v_keep_user_ids);

  -- Teams created by phantoms: same approach
  update public.teams
     set created_by = (select id from public.profiles
                        where university_id = '400000003' limit 1)  -- club_leader
   where created_by is not null
     and created_by <> all(v_keep_user_ids);

  -- ─── delete the profile + auth rows last ────────────────
  delete from public.profiles
    where id <> all(v_keep_user_ids);

  delete from auth.identities
    where user_id <> all(v_keep_user_ids);

  delete from auth.users
    where id <> all(v_keep_user_ids);

  raise notice 'Purge complete. Remaining users: %',
    (select count(*) from public.profiles);
end $$;
