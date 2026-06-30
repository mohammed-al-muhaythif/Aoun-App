-- 0025: The hours honor-leaderboard must be visible to EVERY member of the
-- initiative — not just HR / admins.
--
-- The aggregate RPC `get_hours_leaderboard` was SECURITY INVOKER, so a
-- regular member (RLS policy "hours: self read") only aggregated their own
-- rows → the leaderboard showed just themselves. Recreate it as
-- SECURITY DEFINER (with a pinned search_path) so it aggregates everyone's
-- totals, while still exposing only name + committee + totals (never the
-- private description / notes of individual entries).

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
security definer
set search_path = public
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
