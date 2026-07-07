-- Pure-SQL seed for demo members + permanent teams.
-- Replaces the Edge Function seeder (which hit WORKER_RESOURCE_LIMIT
-- for ~160 sequential admin API calls).
--
-- NOTE: the roster below is PLACEHOLDER DEMO DATA (fake names, phones,
-- and university IDs). Replace it with your club's real roster before
-- deploying for actual use — the same _seed_user calls work for any
-- number of members.
--
-- Idempotent: re-running re-syncs profile/memberships/roles for any
-- existing seeded user and bcrypts the latest phone as password.
--
-- Synthetic auth: email = <university_id>@awan.club, password = normalized phone.

-- pgcrypto is enabled project-wide on Supabase and lives in the
-- `extensions` schema. We do NOT create/move it here (that would error
-- if it's already installed in another schema). We qualify the function
-- calls as `extensions.crypt` / `extensions.gen_salt` below.

-- ─── helper: create-or-sync one user + profile + memberships + club_role ───
create or replace function public._seed_user(
  p_name        text,
  p_uni         text,
  p_phone       text,
  p_club_role   text default null,
  p_committees  jsonb default '[]'::jsonb  -- [{"name_en":"...", "role":"member|vice_head|head"}]
) returns uuid
language plpgsql security definer
set search_path = public, auth, extensions as $$
declare
  v_email   text;
  v_phone   text;
  v_pwhash  text;
  v_user_id uuid;
  c         jsonb;
  v_cid     smallint;
begin
  -- normalize phone (mirror lookup_login_email logic)
  v_phone := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  if v_phone like '966%' then v_phone := substring(v_phone from 4); end if;
  if v_phone like '0%' then v_phone := substring(v_phone from 2); end if;
  v_email  := p_uni || '@awan.club';
  -- schema-qualified call so it works even if search_path is restricted
  v_pwhash := extensions.crypt(v_phone, extensions.gen_salt('bf'));

  -- find or create the auth user
  select id into v_user_id from auth.users where email = v_email;

  if v_user_id is null then
    v_user_id := gen_random_uuid();
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at,
      confirmation_token, email_change, email_change_token_new, recovery_token
    ) values (
      '00000000-0000-0000-0000-000000000000',
      v_user_id, 'authenticated', 'authenticated',
      v_email, v_pwhash,
      now(),
      '{"provider":"email","providers":["email"]}'::jsonb,
      jsonb_build_object('full_name', p_name),
      now(), now(),
      '', '', '', ''
    );
    insert into auth.identities (
      id, provider_id, user_id, identity_data, provider,
      last_sign_in_at, created_at, updated_at
    ) values (
      gen_random_uuid(), v_user_id::text, v_user_id,
      jsonb_build_object('sub', v_user_id::text, 'email', v_email),
      'email', now(), now(), now()
    );
  else
    update auth.users
       set encrypted_password = v_pwhash,
           raw_user_meta_data = jsonb_build_object('full_name', p_name),
           updated_at = now()
     where id = v_user_id;
  end if;

  -- profile
  insert into public.profiles (id, full_name, university_id, phone)
  values (v_user_id, p_name, p_uni, v_phone)
  on conflict (id) do update set
    full_name     = excluded.full_name,
    university_id = excluded.university_id,
    phone         = excluded.phone;

  -- memberships (reset)
  delete from public.committee_memberships where user_id = v_user_id;
  for c in select * from jsonb_array_elements(p_committees) loop
    select id into v_cid from public.committees where name_en = c->>'name_en';
    if v_cid is not null then
      insert into public.committee_memberships (user_id, committee_id, role)
      values (v_user_id, v_cid, c->>'role');
    end if;
  end loop;

  -- club_role (reset)
  delete from public.club_roles where user_id = v_user_id;
  if p_club_role is not null then
    insert into public.club_roles (user_id, role) values (v_user_id, p_club_role);
  end if;

  return v_user_id;
end $$;

-- ─── board (full admin) ───────────────────────────────────────────
select _seed_user('عضو مجلس الإدارة 1 (تجريبي)', '400000001', '0500000001', 'board_member');
select _seed_user('عضو مجلس الإدارة 2 (تجريبي)', '400000002', '0500000002', 'board_member');

-- ─── leadership (full admin) ──────────────────────────────────────
select _seed_user('قائد النادي (تجريبي)',       '400000003', '0500000003', 'club_leader');
select _seed_user('نائب قائد النادي (تجريبي)',  '400000004', '0500000004', 'club_vice_leader');

-- ─── committee heads / vices ──────────────────────────────────────
select _seed_user('رئيس الموارد البشرية (تجريبي)',  '400000005', '0500000005', null, '[{"name_en":"Human Resources","role":"head"}]');
select _seed_user('نائب الموارد البشرية (تجريبي)',  '400000006', '0500000006', null, '[{"name_en":"Human Resources","role":"vice_head"}]');
select _seed_user('رئيس إدارة المشاريع (تجريبي)',   '400000007', '0500000007', null, '[{"name_en":"Project Management","role":"head"}]');
select _seed_user('نائب إدارة المشاريع (تجريبي)',   '400000008', '0500000008', null, '[{"name_en":"Project Management","role":"vice_head"}]');
select _seed_user('رئيس العلاقات العامة (تجريبي)',  '400000009', '0500000009', null, '[{"name_en":"Public Relations","role":"head"}]');
select _seed_user('نائب العلاقات العامة (تجريبي)',  '400000010', '0500000010', null, '[{"name_en":"Public Relations","role":"vice_head"}]');
select _seed_user('رئيس الجودة والتطوير (تجريبي)',  '400000011', '0500000011', null, '[{"name_en":"Quality & Development","role":"head"}]');
select _seed_user('نائب الجودة والتطوير (تجريبي)',  '400000012', '0500000012', null, '[{"name_en":"Quality & Development","role":"vice_head"}]');
select _seed_user('رئيس الإرشاد (تجريبي)',          '400000013', '0500000013', null, '[{"name_en":"Guidance","role":"head"}]');
select _seed_user('نائب الإرشاد (تجريبي)',          '400000014', '0500000014', null, '[{"name_en":"Guidance","role":"vice_head"}]');
select _seed_user('رئيس إدارة الأنشطة (تجريبي)',    '400000015', '0500000015', null, '[{"name_en":"Activity Management","role":"head"}]');
select _seed_user('نائب إدارة الأنشطة (تجريبي)',    '400000016', '0500000016', null, '[{"name_en":"Activity Management","role":"vice_head"}]');
select _seed_user('رئيس التقنية (تجريبي)',          '400000017', '0500000017', null, '[{"name_en":"Technology","role":"head"}]');
select _seed_user('نائب التقنية (تجريبي)',          '400000018', '0500000018', null, '[{"name_en":"Technology","role":"vice_head"}]');
select _seed_user('رئيس الإعلام (تجريبي)',          '400000019', '0500000019', null, '[{"name_en":"Media","role":"head"}]');
select _seed_user('نائب الإعلام (تجريبي)',          '400000020', '0500000020', null, '[{"name_en":"Media","role":"vice_head"}]');

-- ─── app admin (Technology member) ────────────────────────────────
select _seed_user('مشرف التطبيق (تجريبي)',          '400000021', '0500000021', 'app_admin', '[{"name_en":"Technology","role":"member"}]');

-- ─── committee members ────────────────────────────────────────────
select _seed_user('عضو الموارد البشرية (تجريبي)',   '400000022', '0500000022', null, '[{"name_en":"Human Resources","role":"member"}]');
select _seed_user('عضو إدارة المشاريع (تجريبي)',    '400000023', '0500000023', null, '[{"name_en":"Project Management","role":"member"}]');
select _seed_user('عضو العلاقات العامة (تجريبي)',   '400000024', '0500000024', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('عضو الجودة والتطوير (تجريبي)',   '400000025', '0500000025', null, '[{"name_en":"Quality & Development","role":"member"}]');
select _seed_user('عضو الإرشاد (تجريبي)',           '400000026', '0500000026', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('عضو إدارة الأنشطة (تجريبي)',     '400000027', '0500000027', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('عضو التقنية (تجريبي)',           '400000028', '0500000028', null, '[{"name_en":"Technology","role":"member"}]');

-- ─── multi-committee member (ONE user, multiple memberships) ──────
select _seed_user('عضو متعدد اللجان (تجريبي)', '400000029', '0500000029', null, '[{"name_en":"Human Resources","role":"member"},{"name_en":"Quality & Development","role":"member"}]');

-- ─── permanent-team leaders / vices / members ─────────────────────
-- (seeded as Media committee members here; migration 0013 moves them
--  to team_members and keeps only head + vice in the Media committee)
select _seed_user('قائد فريق الهوية البصرية (تجريبي)',    '400000030', '0500000030', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('نائب فريق الهوية البصرية (تجريبي)',    '400000031', '0500000031', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('قائد فريق التصوير والمونتاج (تجريبي)', '400000032', '0500000032', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('نائب فريق التصوير والمونتاج (تجريبي)', '400000033', '0500000033', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('قائد فريق كتابة المحتوى (تجريبي)',     '400000034', '0500000034', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('نائب فريق كتابة المحتوى (تجريبي)',     '400000035', '0500000035', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('قائد فريق إدارة الحسابات (تجريبي)',    '400000036', '0500000036', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('نائب فريق إدارة الحسابات (تجريبي)',    '400000037', '0500000037', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('عضو فريق الهوية البصرية (تجريبي)',     '400000038', '0500000038', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('عضو فريق التصوير والمونتاج (تجريبي)',  '400000039', '0500000039', null, '[{"name_en":"Media","role":"member"}]');

-- ─── permanent teams under Media ──────────────────────────────────
delete from public.team_members tm
  using public.teams t
  where tm.team_id = t.id and t.is_permanent = true;
delete from public.teams where is_permanent = true;

do $$
declare
  v_media smallint;
  v_team uuid;
  v_leader uuid;
  v_vice uuid;
  v_teams jsonb := jsonb_build_array(
    jsonb_build_object('name', 'فريق الهوية البصرية', 'desc', 'تصميم وإدارة الهوية البصرية للنادي',
      'leader', '400000030', 'vice', '400000031'),
    jsonb_build_object('name', 'فريق التصوير والمونتاج', 'desc', 'تصوير ومونتاج الفعاليات',
      'leader', '400000032', 'vice', '400000033'),
    jsonb_build_object('name', 'فريق كتابة المحتوى', 'desc', 'كتابة وإعداد المحتوى للقنوات',
      'leader', '400000034', 'vice', '400000035'),
    jsonb_build_object('name', 'فريق إدارة الحسابات', 'desc', 'إدارة حسابات النادي على وسائل التواصل',
      'leader', '400000036', 'vice', '400000037')
  );
  t jsonb;
begin
  select id into v_media from public.committees where name_en = 'Media';
  for t in select * from jsonb_array_elements(v_teams) loop
    select id into v_leader from public.profiles where university_id = t->>'leader';
    select id into v_vice   from public.profiles where university_id = t->>'vice';
    if v_leader is null or v_vice is null then
      continue;
    end if;
    insert into public.teams (name, description, created_by, is_permanent, parent_committee_id)
    values (t->>'name', t->>'desc', v_leader, true, v_media)
    returning id into v_team;
    insert into public.team_members (team_id, user_id, role) values
      (v_team, v_leader, 'leader'),
      (v_team, v_vice,   'vice_leader');
  end loop;
end $$;

-- Cleanup: keep the helper around for re-seeding; comment out the drop
-- if you want a one-shot. We keep it so re-running `supabase db push`
-- (which re-applies the migration only once) plus manual SELECT calls
-- can resync individuals.
-- drop function public._seed_user(text, text, text, text, jsonb);
