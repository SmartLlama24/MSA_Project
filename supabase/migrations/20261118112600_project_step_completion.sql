alter table public.project_steps
  add column is_completed boolean not null default false;
