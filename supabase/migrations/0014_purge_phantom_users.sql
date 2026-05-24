-- 0014: Purge phantom/test users left over from the failed Edge Function
-- seeder that ran before migration 0006 was applied.
--
-- Symptom: opening the committee dashboard shows fabricated members
-- (e.g. "نورة العتيبي" as Technology vice, "فيصل الغامدي" as head).
-- These rows exist in auth.users + profiles + committee_memberships
-- but are not in the canonical 180-member roster.
--
-- Strategy: build the set of canonical user_ids (from the 180
-- university_ids), then cascade-delete every other row across all
-- related tables.

do $$
declare
  v_canonical_unis text[] := array[
    -- ── Board ───────────────────────────────────────────
    '442103121','442101381','443200521',
    -- ── Leadership ──────────────────────────────────────
    '443201974','445203893','444102729',
    -- ── HR ──────────────────────────────────────────────
    '446104004','445201946','444202222','446205926','446205081',
    '444200559','446202940','447205427','444204516','446202676',
    '446207187','445201575','444102818',
    -- ── Project Management ──────────────────────────────
    '443101921','444201171','443200487','446205363','446201536',
    '444201244','446100034','447205724','444200857','445202474',
    '447201850','444926931','447205762','445201704',
    -- ── Public Relations ────────────────────────────────
    '445200772','445102104','444927013','445100050','446206103',
    '447202813','444202580','446202607','222415918','445928504',
    '445927084','2359117419','446103058','445204295','445202127',
    '447200027','445202385','446927152','446203051',
    -- ── Quality & Development ───────────────────────────
    '446202812','446205075','442927748','445201628','444200915',
    '446206547','446207300','447201459','445202351','445204296',
    '445203438','445206345','445203788',
    -- ── Activity Management ─────────────────────────────
    '444202508','446103784','445203690','444926477','445200625',
    '444927065','446208041','445206283','445203169','445105243',
    '446202457','436201149','1133691905','447925680','445200979',
    '446206662','446204938','446202434','446207404','445201659',
    '447205060','445202759','445928512','447204195','447205750',
    '446208016','447203002','445203360','445200658','446204808',
    '446105390','446208018','447203516','446206502','444204724',
    '447202431','444202116','445201608','446207121','447204028',
    '447201482','443204257','444926630','444927190','446203004',
    '442200770','445203925','445203627','445203200','445200836',
    '445204068','447201902','447202915','445203566','446103340',
    '447203256','446202931','447101474','446206003',
    -- ── Technology ──────────────────────────────────────
    '446008421','445102252','444204041','444101749','446202367',
    '446103998','446206804',
    -- ── Guidance ────────────────────────────────────────
    '446204832','444202935','444927039','446206791','444202636',
    '446201281','446205370','446107429','446204883','446202083',
    '446203127','444200245','455201044','447205338','447201460',
    '446203992','445203377',
    -- ── Media (committee head + vice) ───────────────────
    '444200725','445107359',
    -- ── Multi-committee ─────────────────────────────────
    '445201804','445201237','442102790','446204358',
    -- ── Visual Identity team ────────────────────────────
    '444202088','444201049','445202787','446201925','447202479',
    '447205725',
    -- ── Photography team ────────────────────────────────
    '446204886','445105905','447202426','447926963','445202087',
    '447205791','444927123','446203530','447203263','446202974',
    -- ── Content Writing team ────────────────────────────
    '446202651','442200186','446204927','445206332','445201247',
    '445201771',
    -- ── Account Management team ─────────────────────────
    '446206096','445203858','447202690','446203255'
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
                        where university_id = '443201974' limit 1)  -- سفانة الهديب (club_leader)
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
