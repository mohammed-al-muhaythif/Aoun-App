-- 0015: foundation for the member-management feature.
--
-- Adds:
--   * profiles.major (التخصص الدراسي)
--   * RPC add_member         — create auth user + profile + membership
--   * RPC update_member_info — edit name/phone/uni/major (password updates with phone)
--   * RPC delete_member      — remove a user from the system (cascade)
--   * RPC change_member_role — promote/demote within a committee
--   * RPC remove_from_committee — drop the membership row only
--
-- All RPCs are SECURITY DEFINER with their own authorization check, so
-- they bypass RLS for the writes but enforce the spec's permission
-- matrix internally (committee head only for own committee, HR / admin
-- for everything).

-- ─── new column ──────────────────────────────────────────────────────
alter table public.profiles
  add column if not exists major text;

-- ─── permission helpers ──────────────────────────────────────────────
-- Returns true if the caller is HR head/vice or full admin.
create or replace function public.is_hr_or_admin(p_uid uuid)
returns boolean language sql security definer set search_path = public, extensions as $$
  select is_hr_head(p_uid) or is_club_president(p_uid);
$$;

-- ─── add_member RPC ──────────────────────────────────────────────────
-- Creates a new club member. Caller must be committee head/vice of
-- p_committee_id, OR HR head, OR admin.
create or replace function public.add_member(
  p_full_name     text,
  p_university_id text,
  p_phone         text,
  p_major         text,
  p_committee_id  smallint,
  p_role          text default 'member'  -- 'member' | 'vice_head'  (head reserved for HR/admin)
) returns uuid
language plpgsql security definer set search_path = public, auth, extensions as $$
declare
  v_caller uuid := auth.uid();
  v_phone_norm text;
  v_email text;
  v_pwhash text;
  v_user_id uuid;
begin
  -- authorization
  if not (
    is_hr_or_admin(v_caller)
    or is_committee_head(v_caller, p_committee_id)
  ) then
    raise exception 'not authorized';
  end if;

  -- only HR/admin may create heads (regular committee heads cap at vice_head)
  if p_role = 'head' and not is_hr_or_admin(v_caller) then
    raise exception 'only HR/admin may grant head role';
  end if;
  if p_role not in ('member','vice_head','head') then
    raise exception 'invalid role: %', p_role;
  end if;

  -- normalize phone
  v_phone_norm := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  if v_phone_norm like '966%' then v_phone_norm := substring(v_phone_norm from 4); end if;
  if v_phone_norm like '0%' then v_phone_norm := substring(v_phone_norm from 2); end if;
  if length(v_phone_norm) < 9 then raise exception 'invalid phone'; end if;

  v_email := p_university_id || '@awan.club';
  v_pwhash := extensions.crypt(v_phone_norm, extensions.gen_salt('bf'));

  -- reject duplicate uni_id
  if exists (select 1 from public.profiles where university_id = p_university_id) then
    raise exception 'university id already exists';
  end if;

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
    jsonb_build_object('full_name', p_full_name),
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

  insert into public.profiles (id, full_name, university_id, phone, major)
  values (v_user_id, p_full_name, p_university_id, v_phone_norm, p_major);

  insert into public.committee_memberships (user_id, committee_id, role)
  values (v_user_id, p_committee_id, p_role);

  return v_user_id;
end $$;

grant execute on function public.add_member(text, text, text, text, smallint, text)
  to authenticated;

-- ─── update_member_info RPC ──────────────────────────────────────────
-- Permissioned edit of profile fields. If phone changes the auth
-- password is updated to match (normalized phone is the password).
create or replace function public.update_member_info(
  p_user_id       uuid,
  p_full_name     text,
  p_phone         text,
  p_university_id text,
  p_major         text
) returns void
language plpgsql security definer set search_path = public, auth, extensions as $$
declare
  v_caller uuid := auth.uid();
  v_phone_norm text;
  v_old_phone text;
  v_allowed boolean := false;
begin
  if v_caller = p_user_id then
    v_allowed := true;  -- self-edit allowed
  elsif is_hr_or_admin(v_caller) then
    v_allowed := true;
  else
    -- committee head/vice of any committee the target is in
    select exists (
      select 1 from committee_memberships cm
       where cm.user_id = p_user_id
         and is_committee_head(v_caller, cm.committee_id)
    ) into v_allowed;
  end if;
  if not v_allowed then raise exception 'not authorized'; end if;

  v_phone_norm := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  if v_phone_norm like '966%' then v_phone_norm := substring(v_phone_norm from 4); end if;
  if v_phone_norm like '0%' then v_phone_norm := substring(v_phone_norm from 2); end if;

  select regexp_replace(coalesce(phone, ''), '\D', '', 'g') into v_old_phone
    from public.profiles where id = p_user_id;

  update public.profiles
     set full_name     = p_full_name,
         phone         = v_phone_norm,
         university_id = p_university_id,
         major         = p_major
   where id = p_user_id;

  -- mirror university_id change into the synthetic email
  update auth.users
     set email = p_university_id || '@awan.club',
         updated_at = now()
   where id = p_user_id;

  -- password = phone; rotate if phone changed
  if v_phone_norm <> v_old_phone then
    update auth.users
       set encrypted_password = extensions.crypt(v_phone_norm, extensions.gen_salt('bf')),
           updated_at = now()
     where id = p_user_id;
  end if;
end $$;

grant execute on function public.update_member_info(uuid, text, text, text, text)
  to authenticated;

-- ─── change_member_role RPC ──────────────────────────────────────────
-- Promotes/demotes within a committee. Head grants reserved to HR/admin.
create or replace function public.change_member_role(
  p_user_id      uuid,
  p_committee_id smallint,
  p_new_role     text  -- 'member' | 'vice_head' | 'head'
) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_caller uuid := auth.uid();
begin
  if not (
    is_hr_or_admin(v_caller)
    or is_committee_head(v_caller, p_committee_id)
  ) then
    raise exception 'not authorized';
  end if;
  if p_new_role = 'head' and not is_hr_or_admin(v_caller) then
    raise exception 'only HR/admin may grant head role';
  end if;
  if p_new_role not in ('member','vice_head','head') then
    raise exception 'invalid role';
  end if;

  update public.committee_memberships
     set role = p_new_role
   where user_id = p_user_id and committee_id = p_committee_id;
end $$;

grant execute on function public.change_member_role(uuid, smallint, text)
  to authenticated;

-- ─── remove_from_committee RPC ───────────────────────────────────────
-- Drops only this one committee_membership row. User stays in the
-- system and in other committees if any.
create or replace function public.remove_from_committee(
  p_user_id      uuid,
  p_committee_id smallint
) returns void
language plpgsql security definer set search_path = public, extensions as $$
declare
  v_caller uuid := auth.uid();
begin
  if not (
    is_hr_or_admin(v_caller)
    or is_committee_head(v_caller, p_committee_id)
  ) then
    raise exception 'not authorized';
  end if;
  delete from public.committee_memberships
   where user_id = p_user_id and committee_id = p_committee_id;
end $$;

grant execute on function public.remove_from_committee(uuid, smallint)
  to authenticated;

-- ─── delete_member RPC ───────────────────────────────────────────────
-- Full removal — HR head / admin only.
create or replace function public.delete_member(p_user_id uuid)
returns void
language plpgsql security definer set search_path = public, auth, extensions as $$
declare
  v_caller uuid := auth.uid();
begin
  if not is_hr_or_admin(v_caller) then
    raise exception 'not authorized';
  end if;
  if v_caller = p_user_id then
    raise exception 'cannot delete yourself';
  end if;

  delete from public.team_members where user_id = p_user_id;
  delete from public.committee_memberships where user_id = p_user_id;
  delete from public.club_roles where user_id = p_user_id;
  delete from public.volunteer_hours where user_id = p_user_id;
  delete from public.notifications where recipient_id = p_user_id;
  delete from public.task_assignments
    where assignee_type = 'user' and assignee_id = p_user_id::text;
  delete from public.task_comments where author_id = p_user_id;
  update public.tasks set created_by = null where created_by = p_user_id;
  delete from public.profiles where id = p_user_id;
  delete from auth.identities where user_id = p_user_id;
  delete from auth.users where id = p_user_id;
end $$;

grant execute on function public.delete_member(uuid) to authenticated;
