-- 0011: change overdue scanner from every 30 minutes to once per day.
--
-- The 30-minute frequency from 0004 generated noisy `task_overdue`
-- notifications. Daily is enough: a task that crossed midnight will
-- be flipped to `overdue` on the next 00:05 UTC run (≈ 03:05 KSA).

-- Drop the old job by name, then schedule the new one.
do $$
declare
  v_jobid bigint;
begin
  select jobid into v_jobid from cron.job where jobname = 'scan-overdue-tasks';
  if v_jobid is not null then
    perform cron.unschedule(v_jobid);
  end if;
end $$;

select cron.schedule(
  'scan-overdue-tasks',
  '5 0 * * *',  -- 00:05 UTC daily ≈ 03:05 Riyadh
  $$update public.tasks
    set status = 'overdue'
    where status in ('pending', 'in_progress')
      and due_date is not null
      and due_date < current_date$$
);
