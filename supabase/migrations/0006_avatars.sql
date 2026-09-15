-- Profile picture support.

alter table public.employees add column if not exists avatar_path text;

insert into storage.buckets (id, name, public) values ('avatars', 'avatars', true)
  on conflict (id) do nothing;

create policy "avatars read" on storage.objects for select using (bucket_id = 'avatars');

-- Employees may only write to their own folder ("{employee_id}/avatar.ext").
create policy "avatars upload own" on storage.objects for insert with check (
  bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
);
create policy "avatars update own" on storage.objects for update using (
  bucket_id = 'avatars' and auth.uid()::text = (storage.foldername(name))[1]
);
