alter table public.project_steps
  add constraint project_steps_id_project_id_key
  unique (id, project_id);

alter table public.project_photos
  add column project_step_id uuid;

alter table public.project_photos
  add constraint project_photos_step_project_fkey
  foreign key (project_step_id, project_id)
  references public.project_steps (id, project_id)
  on delete cascade;

create index project_photos_step_idx
  on public.project_photos (project_step_id)
  where project_step_id is not null;

alter table public.project_photos
  add constraint project_photos_project_id_id_key
  unique (project_id, id);

alter table public.projects
  add column cover_photo_id uuid;

alter table public.projects
  add constraint projects_cover_photo_fkey
  foreign key (id, cover_photo_id)
  references public.project_photos (project_id, id)
  on delete set null (cover_photo_id);

create function public.ensure_project_cover_is_reference_photo()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.cover_photo_id is not null and not exists (
    select 1
    from public.project_photos photo
    where photo.id = new.cover_photo_id
      and photo.project_id = new.id
      and photo.project_step_id is null
  ) then
    raise exception 'A project cover must be one of its reference photos.';
  end if;

  return new;
end;
$$;

create trigger projects_cover_photo_guard
before insert or update of cover_photo_id
on public.projects
for each row
execute function public.ensure_project_cover_is_reference_photo();

update storage.buckets
set file_size_limit = 10485760,
    allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp']
where id = 'project-progress';
