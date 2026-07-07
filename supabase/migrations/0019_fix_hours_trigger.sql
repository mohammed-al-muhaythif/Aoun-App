-- 0019: Update the `on_hours_inserted` trigger function — it still
-- referenced the renamed `hours` column after migration 0018 changed
-- it to `minutes`.

create or replace function public.on_hours_inserted()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.enqueue_notification(
    new.user_id,
    '✅ تم تسجيل الدقائق التطوعية',
    'تم تسجيل ' || new.minutes || ' دقيقة بنجاح',
    'hours_logged',
    new.id::text
  );
  return new;
end $$;
