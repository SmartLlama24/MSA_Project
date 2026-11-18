create table public.painting_schemes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null check (length(trim(name)) > 0),
  description text,
  preview_storage_path text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.painting_scheme_steps (
  id uuid primary key default gen_random_uuid(),
  scheme_id uuid not null references public.painting_schemes(id) on delete cascade,
  step_order integer not null check (step_order >= 1),
  title text not null check (length(trim(title)) > 0),
  description text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (scheme_id, step_order),
  unique (id, scheme_id)
);

create table public.painting_scheme_step_paints (
  step_id uuid not null
    references public.painting_scheme_steps(id) on delete cascade,
  paint_id uuid not null references public.paints(id) on delete restrict,
  primary key (step_id, paint_id)
);

create index painting_schemes_user_updated_idx
  on public.painting_schemes (user_id, updated_at desc);
create index painting_scheme_steps_order_idx
  on public.painting_scheme_steps (scheme_id, step_order);
create index painting_scheme_step_paints_paint_idx
  on public.painting_scheme_step_paints (paint_id);

create trigger painting_schemes_set_updated_at
before update on public.painting_schemes
for each row execute function public.set_updated_at();

create trigger painting_scheme_steps_set_updated_at
before update on public.painting_scheme_steps
for each row execute function public.set_updated_at();

alter table public.painting_schemes enable row level security;
alter table public.painting_scheme_steps enable row level security;
alter table public.painting_scheme_step_paints enable row level security;

create policy "Users can read their painting schemes"
  on public.painting_schemes for select to authenticated
  using ((select auth.uid()) = user_id);
create policy "Users can create their painting schemes"
  on public.painting_schemes for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy "Users can update their painting schemes"
  on public.painting_schemes for update to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);
create policy "Users can delete their painting schemes"
  on public.painting_schemes for delete to authenticated
  using ((select auth.uid()) = user_id);

create policy "Users can read their painting scheme steps"
  on public.painting_scheme_steps for select to authenticated
  using (
    exists (
      select 1 from public.painting_schemes s
      where s.id = scheme_id and s.user_id = (select auth.uid())
    )
  );
create policy "Users can create their painting scheme steps"
  on public.painting_scheme_steps for insert to authenticated
  with check (
    exists (
      select 1 from public.painting_schemes s
      where s.id = scheme_id and s.user_id = (select auth.uid())
    )
  );
create policy "Users can update their painting scheme steps"
  on public.painting_scheme_steps for update to authenticated
  using (
    exists (
      select 1 from public.painting_schemes s
      where s.id = scheme_id and s.user_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.painting_schemes s
      where s.id = scheme_id and s.user_id = (select auth.uid())
    )
  );
create policy "Users can delete their painting scheme steps"
  on public.painting_scheme_steps for delete to authenticated
  using (
    exists (
      select 1 from public.painting_schemes s
      where s.id = scheme_id and s.user_id = (select auth.uid())
    )
  );

create policy "Users can read paints in their painting schemes"
  on public.painting_scheme_step_paints for select to authenticated
  using (
    exists (
      select 1
      from public.painting_scheme_steps step
      join public.painting_schemes scheme on scheme.id = step.scheme_id
      where step.id = step_id and scheme.user_id = (select auth.uid())
    )
  );
create policy "Users can link paints to their painting scheme steps"
  on public.painting_scheme_step_paints for insert to authenticated
  with check (
    exists (
      select 1
      from public.painting_scheme_steps step
      join public.painting_schemes scheme on scheme.id = step.scheme_id
      where step.id = step_id and scheme.user_id = (select auth.uid())
    )
  );
create policy "Users can unlink paints from their painting scheme steps"
  on public.painting_scheme_step_paints for delete to authenticated
  using (
    exists (
      select 1
      from public.painting_scheme_steps step
      join public.painting_schemes scheme on scheme.id = step.scheme_id
      where step.id = step_id and scheme.user_id = (select auth.uid())
    )
  );

revoke all on public.painting_schemes, public.painting_scheme_steps,
  public.painting_scheme_step_paints from public, anon, authenticated;
grant select, insert, update, delete on public.painting_schemes,
  public.painting_scheme_steps, public.painting_scheme_step_paints
  to authenticated;

alter table public.projects
  add column source_scheme_id uuid;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'painting-scheme-previews',
  'painting-scheme-previews',
  false,
  10485760,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

create policy "Users can read their painting scheme preview images"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'painting-scheme-previews'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.painting_schemes scheme
      where scheme.id::text = (storage.foldername(storage.objects.name))[2]
        and scheme.user_id = (select auth.uid())
    )
  );
create policy "Users can upload their painting scheme preview images"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'painting-scheme-previews'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.painting_schemes scheme
      where scheme.id::text = (storage.foldername(storage.objects.name))[2]
        and scheme.user_id = (select auth.uid())
    )
  );
create policy "Users can update their painting scheme preview images"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'painting-scheme-previews'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.painting_schemes scheme
      where scheme.id::text = (storage.foldername(storage.objects.name))[2]
        and scheme.user_id = (select auth.uid())
    )
  )
  with check (
    bucket_id = 'painting-scheme-previews'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.painting_schemes scheme
      where scheme.id::text = (storage.foldername(storage.objects.name))[2]
        and scheme.user_id = (select auth.uid())
    )
  );
create policy "Users can delete their painting scheme preview images"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'painting-scheme-previews'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
    and exists (
      select 1 from public.painting_schemes scheme
      where scheme.id::text = (storage.foldername(storage.objects.name))[2]
        and scheme.user_id = (select auth.uid())
    )
  );

create function public.create_project_from_painting_scheme(
  p_name text,
  p_subject text,
  p_scheme_id uuid
)
returns uuid
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_project_id uuid;
  v_step record;
  v_project_step_id uuid;
begin
  if v_user_id is null then
    raise exception 'A signed-in user is required.';
  end if;

  if not exists (
    select 1
    from public.painting_schemes scheme
    where scheme.id = p_scheme_id
      and scheme.user_id = v_user_id
  ) then
    raise exception 'The selected painting scheme is unavailable.';
  end if;

  insert into public.projects (
    user_id, name, subject, status, progress, source_scheme_id
  )
  values (
    v_user_id, trim(p_name), trim(p_subject), 'planned', 0, p_scheme_id
  )
  returning id into v_project_id;

  for v_step in
    select id, step_order, title, description
    from public.painting_scheme_steps
    where scheme_id = p_scheme_id
    order by step_order
  loop
    insert into public.project_steps (
      project_id, step_order, title, instructions, is_completed
    )
    values (
      v_project_id, v_step.step_order, v_step.title, v_step.description, false
    )
    returning id into v_project_step_id;

    insert into public.step_paints (step_id, paint_id)
    select v_project_step_id, link.paint_id
    from public.painting_scheme_step_paints link
    where link.step_id = v_step.id;
  end loop;

  return v_project_id;
end;
$$;

revoke all on function public.create_project_from_painting_scheme(text, text, uuid)
  from public, anon;
grant execute on function public.create_project_from_painting_scheme(text, text, uuid)
  to authenticated;
