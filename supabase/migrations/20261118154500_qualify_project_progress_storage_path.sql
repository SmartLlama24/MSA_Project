-- The unqualified `name` inside each projects subquery resolves to
-- projects.name. Explicitly reference the outer Storage object path instead.
drop policy if exists "Users can read project-progress photos"
  on storage.objects;
drop policy if exists "Users can upload project-progress photos"
  on storage.objects;
drop policy if exists "Users can update project-progress photos"
  on storage.objects;
drop policy if exists "Users can delete project-progress photos"
  on storage.objects;

create policy "Users can read project-progress photos"
  on storage.objects
  for select
  to authenticated
  using (
    bucket_id = 'project-progress'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
    and exists (
      select 1
      from public.projects p
      where p.id::text = (storage.foldername(storage.objects.name))[2]
        and p.user_id = (select auth.uid())
    )
  );

create policy "Users can upload project-progress photos"
  on storage.objects
  for insert
  to authenticated
  with check (
    bucket_id = 'project-progress'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
    and exists (
      select 1
      from public.projects p
      where p.id::text = (storage.foldername(storage.objects.name))[2]
        and p.user_id = (select auth.uid())
    )
  );

create policy "Users can update project-progress photos"
  on storage.objects
  for update
  to authenticated
  using (
    bucket_id = 'project-progress'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
    and exists (
      select 1
      from public.projects p
      where p.id::text = (storage.foldername(storage.objects.name))[2]
        and p.user_id = (select auth.uid())
    )
  )
  with check (
    bucket_id = 'project-progress'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
    and exists (
      select 1
      from public.projects p
      where p.id::text = (storage.foldername(storage.objects.name))[2]
        and p.user_id = (select auth.uid())
    )
  );

create policy "Users can delete project-progress photos"
  on storage.objects
  for delete
  to authenticated
  using (
    bucket_id = 'project-progress'
    and array_length(storage.foldername(storage.objects.name), 1) = 2
    and (storage.foldername(storage.objects.name))[1] = (select auth.uid())::text
    and exists (
      select 1
      from public.projects p
      where p.id::text = (storage.foldername(storage.objects.name))[2]
        and p.user_id = (select auth.uid())
    )
  );
