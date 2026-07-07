-- 0027: Server-side guard so volunteer hours can never be logged for a
-- future date (the date picker already caps at today, but this enforces it
-- for every code path). A CHECK constraint can't use current_date (not
-- immutable), so we use a BEFORE trigger.

create or replace function public.reject_future_hours()
returns trigger language plpgsql as $$
begin
  if new.activity_date > current_date then
    raise exception 'لا يمكن تسجيل ساعات بتاريخ مستقبلي';
  end if;
  return new;
end $$;

drop trigger if exists no_future_hours on public.volunteer_hours;
create trigger no_future_hours
  before insert or update on public.volunteer_hours
  for each row execute function public.reject_future_hours();
