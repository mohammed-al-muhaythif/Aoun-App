-- 0013: Correct committee/team classifications to match the canonical
-- member roster.
--
-- Bug found: migration 0006 seeded all permanent-team members as
-- `Media` committee members. Per the canonical roster the Media
-- committee has ONLY 2 people (head + vice_head). Everyone else listed
-- under "media" should be a member of a permanent sub-team
-- (team_members table) — not the Media committee.
--
-- This migration:
--   1. Removes incorrect Media committee_memberships
--   2. Re-seeds team_members for the 4 permanent teams with their
--      full canonical member rosters
--
-- NOTE: university IDs below are the placeholder demo IDs seeded in
-- migration 0006. If you replaced the demo roster, update these too.

-- ─── 1. Remove wrong Media committee memberships ────────────────────
-- Keep only the Media head and vice_head.
do $$
declare
  v_media smallint;
begin
  select id into v_media from public.committees where name_en = 'Media';
  if v_media is null then return; end if;

  delete from public.committee_memberships cm
   using public.profiles p
   where cm.user_id = p.id
     and cm.committee_id = v_media
     and p.university_id not in ('400000019', '400000020');
end $$;

-- ─── 2. Re-seed permanent team members ──────────────────────────────
-- Wipe existing team_members for permanent teams, then re-insert from
-- the canonical roster. Idempotent — safe to re-run.
do $$
declare
  v_team_visual    uuid;
  v_team_photo     uuid;
  v_team_content   uuid;
  v_team_accounts  uuid;
begin
  select id into v_team_visual   from public.teams
    where is_permanent = true and name = 'فريق الهوية البصرية';
  select id into v_team_photo    from public.teams
    where is_permanent = true and name = 'فريق التصوير والمونتاج';
  select id into v_team_content  from public.teams
    where is_permanent = true and name = 'فريق كتابة المحتوى';
  select id into v_team_accounts from public.teams
    where is_permanent = true and name = 'فريق إدارة الحسابات';

  -- clear all existing team_members for these 4 teams
  delete from public.team_members
   where team_id in (v_team_visual, v_team_photo, v_team_content, v_team_accounts);

  -- helper macro via inline insert: (team_id, uni_id, role)
  insert into public.team_members (team_id, user_id, role)
  select team_data.tid, p.id, team_data.role
    from (values
      -- ─── فريق الهوية البصرية ───────────────────────────
      (v_team_visual,   '400000030', 'leader'),
      (v_team_visual,   '400000031', 'vice_leader'),
      (v_team_visual,   '400000038', 'member'),
      -- ─── فريق التصوير والمونتاج ────────────────────────
      (v_team_photo,    '400000032', 'leader'),
      (v_team_photo,    '400000033', 'vice_leader'),
      (v_team_photo,    '400000039', 'member'),
      -- ─── فريق كتابة المحتوى ─────────────────────────────
      (v_team_content,  '400000034', 'leader'),
      (v_team_content,  '400000035', 'vice_leader'),
      -- ─── فريق إدارة الحسابات ───────────────────────────
      (v_team_accounts, '400000036', 'leader'),
      (v_team_accounts, '400000037', 'vice_leader')
    ) as team_data(tid, uni_id, role)
    join public.profiles p on p.university_id = team_data.uni_id
   where team_data.tid is not null;
end $$;
