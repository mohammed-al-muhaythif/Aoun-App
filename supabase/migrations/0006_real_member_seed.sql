-- Pure-SQL seed for real members + permanent teams.
-- Replaces the Edge Function seeder (which hit WORKER_RESOURCE_LIMIT
-- for ~160 sequential admin API calls).
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
select _seed_user('محمد الشتوي',     '442103121', '554144761', 'board_member');
select _seed_user('محمد الجنيدل',    '442101381', '553386412', 'board_member');
select _seed_user('أماسي الدوسري',   '443200521', '593535168', 'board_member');

-- ─── leadership (full admin) ──────────────────────────────────────
select _seed_user('سفانة الهديب',   '443201974', '556577743', 'club_leader');
select _seed_user('ريما العتيبي',   '445203893', '551486791', 'club_vice_leader');
select _seed_user('رائد باطرفي',    '444102729', '532993382', 'club_vice_leader');

-- ─── committee heads / vices ──────────────────────────────────────
select _seed_user('عبدالعزيز الجنيدلي', '446104004', '500927474', null, '[{"name_en":"Human Resources","role":"head"}]');
select _seed_user('ليان الحربي',         '445201946', '563524620', null, '[{"name_en":"Human Resources","role":"vice_head"}]');
select _seed_user('أحمد العبلاني',       '443101921', '592706050', null, '[{"name_en":"Project Management","role":"head"}]');
select _seed_user('شهد السيف',           '444201171', '553127179', null, '[{"name_en":"Project Management","role":"vice_head"}]');
select _seed_user('غلا آل سبيت',         '445200772', '542467161', null, '[{"name_en":"Public Relations","role":"head"}]');
select _seed_user('إبراهيم الفايز',      '445102104', '535754989', null, '[{"name_en":"Public Relations","role":"vice_head"}]');
select _seed_user('شعاع القحطاني',       '444927013', '501596696', null, '[{"name_en":"Public Relations","role":"vice_head"}]');
select _seed_user('ميلاف المشعلي',       '446202812', '555311460', null, '[{"name_en":"Quality & Development","role":"head"}]');
select _seed_user('ديم الرشيد',          '446205075', '504904065', null, '[{"name_en":"Quality & Development","role":"vice_head"}]');
select _seed_user('نور العيد',           '446204832', '543443565', null, '[{"name_en":"Guidance","role":"head"}]');
select _seed_user('داليا الهويمل',       '444202935', '557569290', null, '[{"name_en":"Guidance","role":"vice_head"}]');
select _seed_user('وعد معشي',            '444202508', '558646708', null, '[{"name_en":"Activity Management","role":"head"}]');
select _seed_user('عبدالله الدوسري',     '446103784', '532041372', null, '[{"name_en":"Activity Management","role":"vice_head"}]');
select _seed_user('جود الجارالله',       '445203690', '502114084', null, '[{"name_en":"Activity Management","role":"vice_head"}]');
select _seed_user('فجر العتيبي',         '446008421', '552456281', null, '[{"name_en":"Technology","role":"head"}]');
select _seed_user('أحمد الغامدي',        '445102252', '549236929', null, '[{"name_en":"Technology","role":"vice_head"}]');
select _seed_user('رنا بن دوخي',         '444200725', '558964739', null, '[{"name_en":"Media","role":"head"}]');
select _seed_user('نواف بن راشد',        '445107359', '552466362', null, '[{"name_en":"Media","role":"vice_head"}]');

-- ─── HR members ───────────────────────────────────────────────────
select _seed_user('طرفة عبدالله الطويل', '444202222', '0557389186', null, '[{"name_en":"Human Resources","role":"member"}]');
select _seed_user('لينا عبدالله سعد بن حسين', '446205926', '0551681034', null, '[{"name_en":"Human Resources","role":"member"}]');
select _seed_user('عهد علي اللحيدان',    '446205081', '0505882270', null, '[{"name_en":"Human Resources","role":"member"}]');
select _seed_user('فاطمه عبدالرحمن الحجيري', '444200559', '0552122562', null, '[{"name_en":"Human Resources","role":"member"}]');
select _seed_user('سديم حمد التركي',     '446202940', '0552705751', null, '[{"name_en":"Human Resources","role":"member"}]');
select _seed_user('رفا عبدالله اليحياء', '447205427', '0551841428', null, '[{"name_en":"Human Resources","role":"member"}]');
select _seed_user('جود موسى الهاجري',    '444204516', '0547607064', null, '[{"name_en":"Human Resources","role":"member"}]');
select _seed_user('ساره ابراهيم الضفيان', '446202676', '566445087', null, '[{"name_en":"Human Resources","role":"member"}]');
select _seed_user('جود الغامدي',         '446207187', '0501205880', null, '[{"name_en":"Human Resources","role":"member"}]');
select _seed_user('نوره فيصل الحربي',    '445201575', '500342715', null, '[{"name_en":"Human Resources","role":"member"}]');
select _seed_user('خالد عمار الخالدي',   '444102818', '0557376112', null, '[{"name_en":"Human Resources","role":"member"}]');

-- ─── Project Management members ───────────────────────────────────
select _seed_user('رنيم عايض الشهراني', '443200487', '966505136525', null, '[{"name_en":"Project Management","role":"member"}]');
select _seed_user('ريم السبيعي',         '446205363', '0504549148', null, '[{"name_en":"Project Management","role":"member"}]');
select _seed_user('أسيل يحي العتين',     '446201536', '0540900419', null, '[{"name_en":"Project Management","role":"member"}]');
select _seed_user('نوره نواف العتيبي',   '444201244', '0531173511', null, '[{"name_en":"Project Management","role":"member"}]');
select _seed_user('سعود عبدالعزيز النزال', '446100034', '0531342124', null, '[{"name_en":"Project Management","role":"member"}]');
select _seed_user('روناء مجدي السيد',    '447205724', '0540591715', null, '[{"name_en":"Project Management","role":"member"}]');
select _seed_user('شادن دخيل المسعود',   '444200857', '0552469910', null, '[{"name_en":"Project Management","role":"member"}]');
select _seed_user('جود معيش الحارثي',    '445202474', '0553811032', null, '[{"name_en":"Project Management","role":"member"}]');
select _seed_user('دارين عبدالله الحارثي', '447201850', '0566956836', null, '[{"name_en":"Project Management","role":"member"}]');
select _seed_user('هيا بدر الواصل',      '444926931', '0582137304', null, '[{"name_en":"Project Management","role":"member"}]');
select _seed_user('حلا محمد علي',        '447205762', '0505981344', null, '[{"name_en":"Project Management","role":"member"}]');
select _seed_user('منيرة حمد ال قاسم',   '445201704', '0540472904', null, '[{"name_en":"Project Management","role":"member"}]');

-- ─── PR members ───────────────────────────────────────────────────
select _seed_user('حسن يحيى ال خالص',   '445100050', '0530553131', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('تاله هاني الحارثي',   '446206103', '0500265564', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('سديم سعود أبابطين',   '447202813', '0554633900', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('انيسه صالح الرحيمي',  '444202580', '0536215813', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('نوره عبدالكريم الدواس', '446202607', '0591101402', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('أرياف عبدالله القحطاني', '222415918', '0530634775', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('نوف مرزوق العتيبي',   '445928504', '0554850895', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('وعد سلطان العتيبي',   '445927084', '0580802330', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('إيمان نجيب العساف',   '2359117419', '0545990914', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('أصيل علي القحطاني',   '446103058', '0543350079', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('لينا محمد العفتان',   '445204295', '0533764047', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('فيّ عبدالله العمراني', '445202127', '0582291987', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('غلا هادي الخذامي',    '447200027', '0550780949', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('نجد عبدالله المسعود', '445202385', '0506480862', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('نجود اسماعيل السماعيل', '446927152', '0505221176', null, '[{"name_en":"Public Relations","role":"member"}]');
select _seed_user('هديل فيصل القحطاني',  '446203051', '0537978824', null, '[{"name_en":"Public Relations","role":"member"}]');

-- ─── Quality & Development members ────────────────────────────────
select _seed_user('شوق موسى ال مسيعد',   '442927748', '0561918246', null, '[{"name_en":"Quality & Development","role":"member"}]');
select _seed_user('دينا محمد الشهري',    '445201628', '0550332234', null, '[{"name_en":"Quality & Development","role":"member"}]');
select _seed_user('شاديه شباب البقمي',   '444200915', '0501544326', null, '[{"name_en":"Quality & Development","role":"member"}]');
select _seed_user('سارة عبدالله الحوطي', '446206547', '0533194041', null, '[{"name_en":"Quality & Development","role":"member"}]');
select _seed_user('نوف محمد بن معمر',    '446207300', '0532685572', null, '[{"name_en":"Quality & Development","role":"member"}]');
select _seed_user('دانة محمد الحوشاني',  '447201459', '0581600323', null, '[{"name_en":"Quality & Development","role":"member"}]');
select _seed_user('أفنان سلمان العنقري', '445202351', '0581129252', null, '[{"name_en":"Quality & Development","role":"member"}]');
select _seed_user('ساره عبدالعزيز العامر', '445204296', '0507740821', null, '[{"name_en":"Quality & Development","role":"member"}]');
select _seed_user('خوله حسين قنطاش',     '445203438', '0500749135', null, '[{"name_en":"Quality & Development","role":"member"}]');
select _seed_user('روان مضر العاني',     '445206345', '0535661946', null, '[{"name_en":"Quality & Development","role":"member"}]');
select _seed_user('مريم ابوبكر باجنيد',  '445203788', '570187906', null, '[{"name_en":"Quality & Development","role":"member"}]');

-- ─── Activity Management members ──────────────────────────────────
select _seed_user('رهف عليان مجرشي',     '444926477', '532265774', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('دانا بندر المطيري',   '445200625', '0551691041', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('سارة مرزوق المطيري',  '444927065', '0566214561', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('منى زياد جبلاوي',     '446208041', '0552290062', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('يُمن حديد',           '445206283', '0502052210', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('هيفاء خالد السعدون',  '445203169', '0541200536', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('عبدالرحمن بن فهد العتيبي', '445105243', '0552487259', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('يارا سعد القرون',     '446202457', '0534322522', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('العنود عبدالرحمم الرويس', '436201149', '0509600737', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('شذا سعود المنيف',     '1133691905', '0565027577', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('مرام سامي السعيد',    '447925680', '0557346527', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('ريوف ابراهيم الغميان', '445200979', '0551986035', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('جود راشد العنزي',     '446206662', '0559672250', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('مرام عايد الخثعمي',   '446204938', '0551243040', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('افنان عبدالرحمن الحريقي', '446202434', '0550098878', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('اسماء حازم سعيد',     '446207404', '0543799091', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('ابرار محمد العتيبي',  '445201659', '551097698', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('فاطمة عبدالعزيز المجيش', '447205060', '0501961589', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('شهد محمد القحطاني',   '445202759', '0531827885', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('عريب ابراهيم الشيحه', '445928512', '580858860', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('الهنوف احمد البشيري', '447204195', '503031250', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('رهف محمد ناجي',       '447205750', '0508745275', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('رزاز طارق فضل الله محمد', '446208016', '0581980233', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('البتول اكرم كاتب',    '447203002', '0580392679', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('طيف عبدالله الشنقيطي', '445203360', '0566819344', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('جنان عبدالله الغربي', '445200658', '502916525', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('شمس محمد التويجري',   '446204808', '0583592829', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('احمد حسين العويشي',   '446105390', '0576415191', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('سدره حسان الحديد',    '446208018', '0580827725', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('نوره وليد بن دوخي',   '447203516', '0567173719', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('رزان معيض الشهري',    '446206502', '0501775852', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('تيماء بلال المحروق',  '444204724', '0506420103', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('شجون عبدالعزيز الشبانات', '447202431', '0555234390', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('طيف عبدالعزيز القاسم', '444202116', '0502113225', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('فرح عبدالله اليوسف',  '445201608', '0556706606', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('نوف سعد القحطاني',    '446207121', '0566552473', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('رزان مصلح المطيري',   '447204028', '0565835543', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('الكادي علي العتيبي',  '447201482', '0501628065', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('شهد تركي بن طالب',    '443204257', '0502932640', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('هيفاء عبد الكريم الشبانات', '444926630', '0537307619', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('جود عبدالله العصيل',  '444927190', '0591325500', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('سلطانه خالد الكلدي',  '446203004', '0538049566', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('ارام عماد البراهيم',  '442200770', '0539114714', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('نوير سعد السهلي',     '445203925', '0554787117', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('بدور خالد الجندل',    '445203627', '0595519952', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('اميره علي مهاوش',     '445203200', '0502367863', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('حنين عمر الطحيني',    '445200836', '0502900836', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('غلا محمد المنصور',    '445204068', '0531264122', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('ليان خالد الشمري',    '447201902', '0501346926', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('يارا إبراهيم القباني', '447202915', '534549170', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('منيره ثلاب الشرافي',  '445203566', '0541514674', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('مؤيد جمعة الطقيقي',   '446103340', '0551707009', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('رويدا سلطان الدعلان', '447203256', '0532065668', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('جنى عبدالعزيز الهويش', '446202931', '0509042120', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('سعد بن ابوناصر',      '447101474', '554612435', null, '[{"name_en":"Activity Management","role":"member"}]');
select _seed_user('ريم فهد القحطاني',    '446206003', '532145457', null, '[{"name_en":"Activity Management","role":"member"}]');

-- ─── Technology members (محمد المحيذيف = app_admin) ───────────────
select _seed_user('عائشة محمد ابراهيم',  '444204041', '0551298562', null, '[{"name_en":"Technology","role":"member"}]');
select _seed_user('محمد عبدالله آل رشود', '444101749', '0556774847', null, '[{"name_en":"Technology","role":"member"}]');
select _seed_user('عالية خالد القحطاني', '446202367', '0501083355', null, '[{"name_en":"Technology","role":"member"}]');
select _seed_user('محمد عبدالله المحيذيف', '446103998', '0530466740', 'app_admin', '[{"name_en":"Technology","role":"member"}]');
select _seed_user('دلال محمد بن لويبه',  '446206804', '0504491488', null, '[{"name_en":"Technology","role":"member"}]');

-- ─── Guidance members ─────────────────────────────────────────────
select _seed_user('هيا علي القحطاني',    '444927039', '0507317715', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('ريانه فايز العنزي',   '446206791', '0549070985', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('جنا خالد الشبانات',   '444202636', '0505438122', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('رنا هيثم الربيعه',    '446201281', '0502445207', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('تولين محمد الشهري',   '446205370', '0559230627', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('يوسف حسن يحيى ال بلابل', '446107429', '0530303895', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('رنا خالد بن نخيلان',  '446204883', '0599271188', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('هديل حمد الحناكي',    '446202083', '0567146691', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('ساره عائض القحطاني',  '446203127', '0552690204', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('اروى نايف الغامدي',   '444200245', '0558081771', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('منيره عبدالعزيز العيسى', '455201044', '0568989089', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('ساره فهد بن شنار',    '447205338', '0505323805', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('ليان بنت محمد الوطيان', '447201460', '0557701261', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('جوري محمد ال سفيان',  '446203992', '0533246936', null, '[{"name_en":"Guidance","role":"member"}]');
select _seed_user('دانه عبدالكريم الزهراني', '445203377', '0508631563', null, '[{"name_en":"Guidance","role":"member"}]');

-- ─── Media members ────────────────────────────────────────────────
select _seed_user('نوف سعود المطيري',    '444201049', '0557386141', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('هيا عبدالاله الراشد', '445202787', '552126083', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('نورة بنت وليد بن شاهين', '446201925', '0501601797', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('فاطمة تركي الكريمي',  '447202479', '0563086620', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('جمانه صلاح الدين وجدي', '447205725', '0570986987', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('شهد محمد الزاكي',     '447202426', '0570717860', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('ليان سلطان العاتي',   '447926963', '532313118', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('حنان حسين الشقراوي',  '445202087', '0551063873', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('سلوى عبدالرحمن دع',   '447205791', '0534616029', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('رغد سبيل السعدي',     '444927123', '548614855', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('رزان علي فقيه',       '446203530', '0557139179', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('ساره ناصر الدوسري',   '447203263', '530055299', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('ليان سعود الاحمد',    '446202974', '500544896', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('هيا عبدالعزيز الوهيبي', '446204927', '0501758924', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('شادن محمد المنهالي',  '445206332', '0500391766', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('ريناد زايد السبيعي',  '445201247', '0559801392', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('نوف فهد بن غنام',     '445201771', '0532021165', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('يارا عاصم المقحم',    '447202690', '0573573011', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('رغد علي باجبع',       '446203255', '550024209', null, '[{"name_en":"Media","role":"member"}]');

-- ─── multi-committee members (ONE user, multiple memberships) ─────
select _seed_user('ديالا خلف السلمي', '445201804', '0581312082', null, '[{"name_en":"Media","role":"member"},{"name_en":"Quality & Development","role":"member"}]');
select _seed_user('نورة عبدالعزيز العجمي', '445201237', '0559885075', null, '[{"name_en":"Human Resources","role":"member"},{"name_en":"Quality & Development","role":"member"}]');
select _seed_user('أحمد يوسف العضياني', '442102790', '508440285', null, '[{"name_en":"Project Management","role":"member"},{"name_en":"Technology","role":"member"}]');
select _seed_user('حصه عبدالرحمن النزهان', '446204358', '0550781522', null, '[{"name_en":"Activity Management","role":"member"},{"name_en":"Media","role":"member"}]');

-- ─── permanent-team leaders / vices (not in committee rosters above) ─
select _seed_user('لينا القحطاني',     '444202088', '504631880', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('ديما الدويش',       '446204886', '551507105', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('عبدالله السبيعي',   '445105905', '557931014', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('سارة المقري',       '446202651', '545127162', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('منار القحطاني',     '442200186', '532899523', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('سارة القرني',       '446206096', '502864941', null, '[{"name_en":"Media","role":"member"}]');
select _seed_user('غالية الخرعان',     '445203858', '533661977', null, '[{"name_en":"Media","role":"member"}]');

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
      'leader', '444202088', 'vice', '445201804'),
    jsonb_build_object('name', 'فريق التصوير والمونتاج', 'desc', 'تصوير ومونتاج الفعاليات',
      'leader', '446204886', 'vice', '445105905'),
    jsonb_build_object('name', 'فريق كتابة المحتوى', 'desc', 'كتابة وإعداد المحتوى للقنوات',
      'leader', '446202651', 'vice', '442200186'),
    jsonb_build_object('name', 'فريق إدارة الحسابات', 'desc', 'إدارة حسابات النادي على وسائل التواصل',
      'leader', '446206096', 'vice', '445203858')
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
