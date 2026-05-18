-- AWAN schema. Run via `supabase db push`.
-- Profiles extend auth.users (Supabase's built-in users table).

create extension if not exists pgcrypto;

create table public.profiles (
  id          uuid primary key references auth.users on delete cascade,
  full_name   text not null,
  onesignal_id text,
  created_at  timestamptz not null default now()
);

create table public.committees (
  id       smallserial primary key,
  name_ar  text not null unique,
  name_en  text not null
);

create table public.committee_memberships (
  user_id      uuid not null references public.profiles on delete cascade,
  committee_id smallint not null references public.committees on delete cascade,
  role         text not null check (role in ('head','vice_head','member')),
  primary key (user_id, committee_id)
);

create table public.club_roles (
  user_id uuid primary key references public.profiles on delete cascade,
  role    text not null check (role in ('president','vice_president'))
);

create table public.tasks (
  id          uuid primary key default gen_random_uuid(),
  title       text not null,
  description text,
  priority    text not null check (priority in ('high','medium','low')),
  status      text not null default 'pending'
              check (status in ('pending','in_progress','completed','overdue')),
  start_date  date,
  due_date    date,
  created_by  uuid references public.profiles,
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.task_assignments (
  task_id       uuid not null references public.tasks on delete cascade,
  assignee_type text not null check (assignee_type in ('user','committee')),
  assignee_id   text not null,
  primary key (task_id, assignee_type, assignee_id)
);

create table public.task_attachments (
  id           uuid primary key default gen_random_uuid(),
  task_id      uuid not null references public.tasks on delete cascade,
  storage_path text not null,
  file_name    text not null,
  file_size    int not null check (file_size > 0 and file_size <= 20971520),
  uploaded_by  uuid references public.profiles,
  uploaded_at  timestamptz not null default now()
);

create table public.task_comments (
  id         uuid primary key default gen_random_uuid(),
  task_id    uuid not null references public.tasks on delete cascade,
  author_id  uuid not null references public.profiles,
  body       text not null,
  created_at timestamptz not null default now()
);

create table public.teams (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  description text,
  created_by  uuid not null references public.profiles,
  created_at  timestamptz not null default now()
);

create table public.team_members (
  team_id uuid not null references public.teams on delete cascade,
  user_id uuid not null references public.profiles on delete cascade,
  primary key (team_id, user_id)
);

create table public.volunteer_hours (
  id            uuid primary key default gen_random_uuid(),
  user_id       uuid not null references public.profiles on delete cascade,
  description   text not null,
  hours         numeric(5,2) not null check (hours > 0 and hours <= 24),
  activity_date date not null,
  notes         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  updated_by    uuid references public.profiles
);

create table public.notifications (
  id           uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references public.profiles on delete cascade,
  title        text not null,
  body         text not null,
  type         text not null,
  related_id   text,
  is_read      boolean not null default false,
  created_at   timestamptz not null default now()
);

create index on public.task_assignments (assignee_type, assignee_id);
create index on public.volunteer_hours  (user_id, activity_date desc);
create index on public.notifications    (recipient_id, is_read, created_at desc);
create index on public.tasks            (status, due_date);
create index on public.committee_memberships (committee_id);
create index on public.task_comments    (task_id, created_at);

-- updated_at trigger helper
create or replace function public.touch_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end $$;

create trigger tasks_touch
  before update on public.tasks
  for each row execute function public.touch_updated_at();

create trigger volunteer_hours_touch
  before update on public.volunteer_hours
  for each row execute function public.touch_updated_at();

-- Seed the 8 committees
insert into public.committees (name_ar, name_en) values
  ('إدارة الأنشطة',     'Activity Management'),
  ('الإعلامية',          'Media'),
  ('العلاقات العامة',    'Public Relations'),
  ('التقنية',            'Technology'),
  ('الإرشادية',          'Guidance'),
  ('الجودة والتطوير',    'Quality & Development'),
  ('إدارة المشاريع',     'Project Management'),
  ('الموارد البشرية',    'Human Resources')
on conflict (name_ar) do nothing;
