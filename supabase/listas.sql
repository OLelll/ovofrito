-- =====================================================================
-- OVO FRITO!  ·  Listas dos leitores (filmes pra ver mais tarde etc.)
-- Supabase > SQL Editor > New query > cole tudo > Run. Pode rodar de novo.
-- Cada leitor só enxerga e edita a PRÓPRIA linha.
-- =====================================================================
create table if not exists public.user_lists (
  user_id    uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  data       jsonb not null default '[]'::jsonb check (pg_column_size(data) < 200000),
  updated_at timestamptz not null default now()
);
alter table public.user_lists enable row level security;

drop policy if exists "ul_select" on public.user_lists;
create policy "ul_select" on public.user_lists for select to authenticated using (user_id = auth.uid());
drop policy if exists "ul_insert" on public.user_lists;
create policy "ul_insert" on public.user_lists for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "ul_update" on public.user_lists;
create policy "ul_update" on public.user_lists for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
