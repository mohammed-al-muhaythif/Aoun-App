-- 0018: Switch volunteer_hours.hours (numeric 0..24) to minutes (int, > 0).
--
-- The table is already empty after 0016, so there are no values to
-- convert — we just rename the column, drop the 24-hour constraint,
-- and re-create with a positive-integer check.
--
-- The aggregate RPC `get_hours_leaderboard` is recreated to return
-- `total_minutes int` instead of `total_hours numeric`.

-- ── drop old check + rename + retype ───────────────────────────────
alter table public.volunteer_hours
  drop constraint if exists volunteer_hours_hours_check;

alter table public.volunteer_hours
  rename column hours to minutes;

alter table public.volunteer_hours
  alter column minutes type int using minutes::int;

alter table public.volunteer_hours
  add constraint volunteer_hours_minutes_check check (minutes > 0);

-- ── recreate the leaderboard RPC with minutes ──────────────────────
drop function if exists public.get_hours_leaderboard(date, date, int, int);

create or replace function public.get_hours_leaderboard(
  p_start date default null,
  p_end date default null,
  p_committee_id int default null,
  p_limit int default 50
)
returns table (
  user_id uuid,
  full_name text,
  primary_committee_ar text,
  primary_role text,
  total_minutes int,
  session_count int,
  last_activity date
)
language sql
stable
security invoker
as $$
  select
    p.id as user_id,
    p.full_name,
    (
      select c.name_ar
        from committees c
        join committee_memberships cm on cm.committee_id = c.id
       where cm.user_id = p.id
       order by case cm.role
                  when 'head' then 0
                  when 'vice_head' then 1
                  else 2
                end
       limit 1
    ) as primary_committee_ar,
    (
      select cm.role
        from committee_memberships cm
       where cm.user_id = p.id
       order by case cm.role
                  when 'head' then 0
                  when 'vice_head' then 1
                  else 2
                end
       limit 1
    ) as primary_role,
    coalesce(sum(vh.minutes), 0)::int as total_minutes,
    count(vh.id)::int as session_count,
    max(vh.activity_date) as last_activity
  from profiles p
  left join volunteer_hours vh
    on vh.user_id = p.id
   and (p_start is null or vh.activity_date >= p_start)
   and (p_end is null or vh.activity_date <= p_end)
  where (
    p_committee_id is null
    or exists (
      select 1
        from committee_memberships cm
       where cm.user_id = p.id
         and cm.committee_id = p_committee_id
    )
  )
  group by p.id, p.full_name
  having coalesce(sum(vh.minutes), 0) > 0 or p_committee_id is not null
  order by total_minutes desc, p.full_name
  limit greatest(p_limit, 1);
$$;

grant execute on function public.get_hours_leaderboard(date, date, int, int)
  to authenticated;
