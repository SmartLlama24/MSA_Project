update public.projects p
set status = case
  when exists (
    select 1
    from public.project_steps s
    where s.project_id = p.id
      and s.is_completed
  ) then 'in_progress'
  else 'planned'
end
where p.status <> 'completed';

create function public.sync_project_status_from_steps()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  target_project_id uuid;
begin
  target_project_id := case
    when tg_op = 'DELETE' then old.project_id
    else new.project_id
  end;

  update public.projects p
  set status = case
    when exists (
      select 1
      from public.project_steps s
      where s.project_id = target_project_id
        and s.is_completed
    ) then 'in_progress'
    else 'planned'
  end
  where p.id = target_project_id
    and p.status <> 'completed';

  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

create trigger project_steps_sync_project_status
after insert or delete or update of is_completed
on public.project_steps
for each row
execute function public.sync_project_status_from_steps();
