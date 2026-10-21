-- Initial Paintbench schema. Apply with Supabase migrations after reviewing
-- the project and Storage policies for your own deployment.

create table public.paint_brands (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (length(trim(name)) > 0),
  created_at timestamptz not null default now()
);

create table public.paints (
  id uuid primary key default gen_random_uuid(),
  brand_id uuid not null references public.paint_brands(id) on delete restrict,
  name text not null check (length(trim(name)) > 0),
  paint_type text not null check (length(trim(paint_type)) > 0),
  hex_color text check (hex_color is null or hex_color ~ '^#[0-9A-Fa-f]{6}$'),
  created_at timestamptz not null default now(),
  unique (brand_id, name)
);

create table public.projects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  subject text not null check (length(trim(subject)) > 0),
  status text not null default 'planned'
    check (status in ('planned', 'in_progress', 'completed')),
  progress numeric(5, 4) not null default 0
    check (progress >= 0 and progress <= 1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.project_steps (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  step_order integer not null check (step_order >= 1),
  title text not null check (length(trim(title)) > 0),
  instructions text not null check (length(trim(instructions)) > 0),
  technique text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (project_id, step_order)
);

create table public.step_paints (
  step_id uuid not null references public.project_steps(id) on delete cascade,
  paint_id uuid not null references public.paints(id) on delete restrict,
  primary key (step_id, paint_id)
);

create table public.user_paints (
  user_id uuid not null references auth.users(id) on delete cascade,
  paint_id uuid not null references public.paints(id) on delete restrict,
  status text not null
    check (status in ('owned', 'wanted', 'missing')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, paint_id)
);

create table public.project_notes (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  body text not null check (length(trim(body)) > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- This table stores metadata and a private Storage object path, never image bytes.
create table public.project_photos (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references public.projects(id) on delete cascade,
  storage_path text not null unique,
  caption text,
  created_at timestamptz not null default now(),
  check (length(trim(storage_path)) > 0)
);

create index projects_user_updated_idx
  on public.projects (user_id, updated_at desc);
create index paints_brand_idx
  on public.paints (brand_id);
create index step_paints_paint_idx
  on public.step_paints (paint_id);
create index user_paints_paint_idx
  on public.user_paints (paint_id);
create index user_paints_status_idx
  on public.user_paints (user_id, status);
create index project_notes_project_idx
  on public.project_notes (project_id);
create index project_photos_project_idx
  on public.project_photos (project_id);

create function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger projects_set_updated_at
before update on public.projects
for each row execute function public.set_updated_at();

create trigger project_steps_set_updated_at
before update on public.project_steps
for each row execute function public.set_updated_at();

create trigger user_paints_set_updated_at
before update on public.user_paints
for each row execute function public.set_updated_at();

create trigger project_notes_set_updated_at
before update on public.project_notes
for each row execute function public.set_updated_at();

alter table public.paint_brands enable row level security;
alter table public.paints enable row level security;
alter table public.projects enable row level security;
alter table public.project_steps enable row level security;
alter table public.step_paints enable row level security;
alter table public.user_paints enable row level security;
alter table public.project_notes enable row level security;
alter table public.project_photos enable row level security;

create policy "Authenticated users can read paint brands"
  on public.paint_brands for select to authenticated
  using (true);

create policy "Authenticated users can read paints"
  on public.paints for select to authenticated
  using (true);

create policy "Users can read their projects"
  on public.projects for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can create their projects"
  on public.projects for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their projects"
  on public.projects for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete their projects"
  on public.projects for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can read their project steps"
  on public.project_steps for select to authenticated
  using (
    exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  );
create policy "Users can create their project steps"
  on public.project_steps for insert to authenticated
  with check (
    exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  );
create policy "Users can update their project steps"
  on public.project_steps for update to authenticated
  using (
    exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  );
create policy "Users can delete their project steps"
  on public.project_steps for delete to authenticated
  using (
    exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  );

create policy "Users can read paints linked to their steps"
  on public.step_paints for select to authenticated
  using (
    exists (
      select 1
      from public.project_steps s
      join public.projects p on p.id = s.project_id
      where s.id = step_id
        and p.user_id = (select auth.uid())
    )
  );
create policy "Users can link paints to their steps"
  on public.step_paints for insert to authenticated
  with check (
    exists (
      select 1
      from public.project_steps s
      join public.projects p on p.id = s.project_id
      where s.id = step_id
        and p.user_id = (select auth.uid())
    )
  );
create policy "Users can unlink paints from their steps"
  on public.step_paints for delete to authenticated
  using (
    exists (
      select 1
      from public.project_steps s
      join public.projects p on p.id = s.project_id
      where s.id = step_id
        and p.user_id = (select auth.uid())
    )
  );

create policy "Users can read their paint inventory"
  on public.user_paints for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can add paints to their inventory"
  on public.user_paints for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their paint inventory"
  on public.user_paints for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can remove paints from their inventory"
  on public.user_paints for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can read notes on their projects"
  on public.project_notes for select to authenticated
  using (
    exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  );
create policy "Users can create notes on their projects"
  on public.project_notes for insert to authenticated
  with check (
    exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  );
create policy "Users can update notes on their projects"
  on public.project_notes for update to authenticated
  using (
    exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  );
create policy "Users can delete notes on their projects"
  on public.project_notes for delete to authenticated
  using (
    exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  );

create policy "Users can read photos on their projects"
  on public.project_photos for select to authenticated
  using (
    starts_with(
      storage_path,
      (select auth.uid())::text || '/' || project_id::text || '/'
    )
    and exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  );
create policy "Users can add photos to their projects"
  on public.project_photos for insert to authenticated
  with check (
    starts_with(
      storage_path,
      (select auth.uid())::text || '/' || project_id::text || '/'
    )
    and exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  );
create policy "Users can update photos on their projects"
  on public.project_photos for update to authenticated
  using (
    starts_with(
      storage_path,
      (select auth.uid())::text || '/' || project_id::text || '/'
    )
    and exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  )
  with check (
    starts_with(
      storage_path,
      (select auth.uid())::text || '/' || project_id::text || '/'
    )
    and exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  );
create policy "Users can delete photos on their projects"
  on public.project_photos for delete to authenticated
  using (
    starts_with(
      storage_path,
      (select auth.uid())::text || '/' || project_id::text || '/'
    )
    and exists (
      select 1
      from public.projects p
      where p.id = project_id
        and p.user_id = (select auth.uid())
    )
  );

revoke all on public.paint_brands, public.paints
  from public, anon, authenticated;
revoke all on public.projects, public.project_steps, public.step_paints,
     public.user_paints, public.project_notes, public.project_photos
  from public, anon, authenticated;

grant usage on schema public to authenticated;
grant select on public.paint_brands, public.paints to authenticated;
grant select, insert, update, delete
  on public.projects, public.project_steps, public.step_paints,
     public.user_paints, public.project_notes, public.project_photos
  to authenticated;

-- A project photo object path is {user UUID}/{project UUID}/{file name}.
insert into storage.buckets (id, name, public)
values ('project-progress', 'project-progress', false)
on conflict (id) do update set public = false;

create policy "Users can manage photos in their own projects"
  on storage.objects for all to authenticated
  using (
    bucket_id = 'project-progress'
    and array_length(storage.foldername(name), 1) = 2
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1
      from public.projects p
      where p.id::text = (storage.foldername(name))[2]
        and p.user_id = (select auth.uid())
    )
  )
  with check (
    bucket_id = 'project-progress'
    and array_length(storage.foldername(name), 1) = 2
    and (storage.foldername(name))[1] = (select auth.uid())::text
    and exists (
      select 1
      from public.projects p
      where p.id::text = (storage.foldername(name))[2]
        and p.user_id = (select auth.uid())
    )
  );
