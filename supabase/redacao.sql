-- =====================================================================
-- OVO FRITO!  ·  Editor de matérias (rascunhos + imagens)
-- Supabase > SQL Editor > New query > cole tudo > Run. Pode rodar de novo.
-- Precisa do schema.sql antes (usa a função is_admin()).
-- =====================================================================

-- 1) Rascunhos: só a redação (admin) enxerga. Não ficam públicos.
create table if not exists public.drafts (
  id         text primary key check (char_length(id) between 1 and 80),
  data       jsonb not null check (pg_column_size(data) < 2000000),
  updated_at timestamptz not null default now()
);
alter table public.drafts enable row level security;
revoke all on public.drafts from anon;
grant select, insert, update, delete on public.drafts to authenticated;

drop policy if exists "drafts_admin" on public.drafts;
create policy "drafts_admin" on public.drafts
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- 2) Imagens das matérias: leitura pública, envio só pela redação.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('imagens', 'imagens', true, 5242880, array['image/jpeg','image/png','image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg','image/png','image/webp'];

drop policy if exists "imagens_admin_insert" on storage.objects;
create policy "imagens_admin_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'imagens' and public.is_admin());

drop policy if exists "imagens_admin_update" on storage.objects;
create policy "imagens_admin_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'imagens' and public.is_admin());

drop policy if exists "imagens_admin_delete" on storage.objects;
create policy "imagens_admin_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'imagens' and public.is_admin());
