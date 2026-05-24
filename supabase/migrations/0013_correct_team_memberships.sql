-- 0013: Correct committee/team classifications to match the canonical
-- member roster.
--
-- Bug found: migration 0006 seeded all permanent-team members
-- (28 people) as `Media` committee members. Per the canonical roster
-- the Media committee has ONLY 2 people (head + vice_head). Everyone
-- else listed under "media" should be a member of a permanent sub-team
-- (team_members table) — not the Media committee.
--
-- This migration:
--   1. Removes incorrect Media committee_memberships (28 people)
--   2. Re-seeds team_members for the 4 permanent teams with their
--      full canonical member rosters

-- ─── 1. Remove wrong Media committee memberships ────────────────────
-- Keep only رنا بن دوخي (head) and نواف بن راشد (vice_head).
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
     and p.university_id not in ('444200725', '445107359');
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
      (v_team_visual,   '444202088', 'leader'),       -- لينا القحطاني
      (v_team_visual,   '445201804', 'vice_leader'),  -- ديالا السلمي
      (v_team_visual,   '444201049', 'member'),       -- نوف المطيري
      (v_team_visual,   '445202787', 'member'),       -- هيا الراشد
      (v_team_visual,   '446201925', 'member'),       -- نورة بن شاهين
      (v_team_visual,   '447202479', 'member'),       -- فاطمة الكريمي
      (v_team_visual,   '447205725', 'member'),       -- جمانه وجدي
      -- ─── فريق التصوير والمونتاج ────────────────────────
      (v_team_photo,    '446204886', 'leader'),       -- ديما الدويش
      (v_team_photo,    '445105905', 'vice_leader'),  -- عبدالله السبيعي
      (v_team_photo,    '447202426', 'member'),       -- شهد الزاكي
      (v_team_photo,    '447926963', 'member'),       -- ليان العاتي
      (v_team_photo,    '445202087', 'member'),       -- حنان الشقراوي
      (v_team_photo,    '447205791', 'member'),       -- سلوى دع
      (v_team_photo,    '444927123', 'member'),       -- رغد السعدي
      (v_team_photo,    '446203530', 'member'),       -- رزان فقيه
      (v_team_photo,    '447203263', 'member'),       -- ساره الدوسري
      (v_team_photo,    '446202974', 'member'),       -- ليان الاحمد
      -- ─── فريق كتابة المحتوى ─────────────────────────────
      (v_team_content,  '446202651', 'leader'),       -- سارة المقري
      (v_team_content,  '442200186', 'vice_leader'),  -- منار القحطاني
      (v_team_content,  '446204927', 'member'),       -- هيا الوهيبي
      (v_team_content,  '445206332', 'member'),       -- شادن المنهالي
      (v_team_content,  '445201247', 'member'),       -- ريناد السبيعي
      (v_team_content,  '446204358', 'member'),       -- حصه النزهان (also Activities)
      (v_team_content,  '445201771', 'member'),       -- نوف بن غنام
      -- ─── فريق إدارة الحسابات ───────────────────────────
      (v_team_accounts, '446206096', 'leader'),       -- سارة القرني
      (v_team_accounts, '445203858', 'vice_leader'),  -- غالية الخرعان
      (v_team_accounts, '447202690', 'member'),       -- يارا المقحم
      (v_team_accounts, '446203255', 'member')        -- رغد باجبع
    ) as team_data(tid, uni_id, role)
    join public.profiles p on p.university_id = team_data.uni_id
   where team_data.tid is not null;
end $$;
