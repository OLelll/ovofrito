-- =====================================================================
-- Ovo Frito · blindagem do banco · FASE 1 (só adiciona coisas e tira
-- permissões que o site atual não usa; não muda o que o site faz hoje)
-- =====================================================================

-- 1) Matérias publicadas, já filtradas no servidor (agendadas ficam de fora).
--    O site e as funções da Vercel passam a ler por aqui.
create or replace function public.public_articles()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_agg(e.a order by e.ord), '[]'::jsonb)
  from content c,
       jsonb_array_elements(c.value) with ordinality as e(a, ord)
  where c.key = 'articles'
    and jsonb_typeof(c.value) = 'array'
    and ( (e.a->>'pubAt') is null
          or (e.a->>'pubAt') !~ '^\d{4}-\d{2}-\d{2}T'
          or (e.a->>'pubAt')::timestamptz <= now() )
$$;
revoke all on function public.public_articles() from public;
grant execute on function public.public_articles() to anon, authenticated;

-- 2) Funções antigas de votação anônima: o site atual não usa nenhuma.
--    Qualquer visitante podia forjar eleitores e lotar a tabela de indicações.
revoke all on function public.vote_poll(text, uuid, text)               from public, anon, authenticated;
revoke all on function public.vote_review(text, uuid, boolean)          from public, anon, authenticated;
revoke all on function public.submit_suggestion(text, text, text, uuid) from public, anon, authenticated;
revoke all on function public.upvote_suggestion(uuid, uuid, boolean)    from public, anon, authenticated;
revoke all on function public.my_votes(uuid)                            from public, anon, authenticated;

-- 3) Aviso do Supabase: fixa o search_path da função de data de atualização.
alter function public.touch_updated_at() set search_path = public;

-- 4) Histórico de versões: guarda as últimas 50 versões de cada bloco do site
--    (matérias, ranking, textos...). Se alguém apagar ou sobrescrever tudo,
--    dá pra voltar atrás. Só admin lê; ninguém escreve direto.
create table if not exists public.content_history (
  id       bigserial primary key,
  key      text        not null,
  value    jsonb       not null,
  saved_at timestamptz not null default now(),
  saved_by uuid        default auth.uid()
);
alter table public.content_history enable row level security;
revoke all on public.content_history from anon, authenticated;
grant select on public.content_history to authenticated;
drop policy if exists "history_admin_read" on public.content_history;
create policy "history_admin_read" on public.content_history
  for select to authenticated using (public.is_admin());
create index if not exists content_history_key_id on public.content_history (key, id desc);

create or replace function public.content_snapshot()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' or old.value is distinct from new.value then
    insert into content_history (key, value) values (old.key, old.value);
    delete from content_history
     where key = old.key
       and id not in (select id from content_history where key = old.key order by id desc limit 50);
  end if;
  return coalesce(new, old);
end $$;
revoke all on function public.content_snapshot() from public, anon, authenticated;

drop trigger if exists content_snapshot on public.content;
create trigger content_snapshot
  after update or delete on public.content
  for each row execute function public.content_snapshot();
