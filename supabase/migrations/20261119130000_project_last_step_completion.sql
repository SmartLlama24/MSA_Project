alter table public.projects
  add column last_step_completed_at timestamptz;

alter table public.projects disable trigger projects_set_updated_at;

update public.projects p
set last_step_completed_at = (
  select max(s.updated_at)
  from public.project_steps s
  where s.project_id = p.id
    and s.is_completed
)
where exists (
  select 1
  from public.project_steps s
  where s.project_id = p.id
    and s.is_completed
);

alter table public.projects enable trigger projects_set_updated_at;

create function public.record_project_step_completion()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op = 'INSERT' then
    if new.is_completed then
      update public.projects
      set last_step_completed_at = now()
      where id = new.project_id;
    end if;
  elsif new.is_completed and not old.is_completed then
    update public.projects
    set last_step_completed_at = now()
    where id = new.project_id;
  end if;

  return new;
end;
$$;

create trigger project_steps_record_completion
after insert or update of is_completed
on public.project_steps
for each row
execute function public.record_project_step_completion();
