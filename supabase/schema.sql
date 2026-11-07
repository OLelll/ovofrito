-- =====================================================================
-- OVO FRITO!  ·  Parte 1: tabelas e regras de segurança
--
-- Como usar: Supabase > SQL Editor > New query > cole tudo > Run.
-- Pode rodar de novo sem medo: ele não apaga nada que já exista.
-- =====================================================================

-- ---------------------------------------------------------------------
-- 1) ADMINS
-- Só quem está nesta lista pode editar o site. Quem já tem usuário criado
-- no Authentication na hora que você roda este script vira admin.
-- (Gente que se cadastrar depois NÃO vira admin.)
-- ---------------------------------------------------------------------
create table if not exists public.admins (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.admins enable row level security;

insert into public.admins (user_id)
select id from auth.users
on conflict do nothing;

create or replace function public.is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (select 1 from public.admins where user_id = auth.uid())
$$;

-- ---------------------------------------------------------------------
-- 2) CONTEÚDO DO SITE
-- Cada linha guarda um bloco do site em JSON: movies, series, articles,
-- ticker, interviews, nacional, poll, review, texts.
-- Todo mundo lê. Só admin escreve.
-- ---------------------------------------------------------------------
create table if not exists public.content (
  key        text primary key check (char_length(key) between 1 and 60),
  value      jsonb not null,
  updated_at timestamptz not null default now()
);
alter table public.content enable row level security;

drop policy if exists "content_read" on public.content;
create policy "content_read" on public.content
  for select to anon, authenticated using (true);

drop policy if exists "content_admin_write" on public.content;
create policy "content_admin_write" on public.content
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end
$$;

drop trigger if exists content_touch on public.content;
create trigger content_touch before update on public.content
  for each row execute function public.touch_updated_at();

-- ---------------------------------------------------------------------
-- 3) VOTOS DOS LEITORES
-- Ninguém mexe nestas tabelas direto. Tudo passa pelas funções da seção 4,
-- que validam o voto. "voter" é um código aleatório que cada navegador
-- guarda e que nunca aparece pra outras pessoas.
-- ---------------------------------------------------------------------
create table if not exists public.ratings (
  item_id    text not null check (char_length(item_id) between 1 and 80),
  voter      uuid not null,
  stars      smallint not null check (stars between 1 and 5),
  updated_at timestamptz not null default now(),
  primary key (item_id, voter)
);

create table if not exists public.poll_votes (
  poll_id    text not null check (char_length(poll_id) between 1 and 80),
  voter      uuid not null,
  option_id  text not null check (char_length(option_id) between 1 and 80),
  updated_at timestamptz not null default now(),
  primary key (poll_id, voter)
);

create table if not exists public.review_votes (
  review_id  text not null check (char_length(review_id) between 1 and 80),
  voter      uuid not null,
  agree      boolean not null,
  updated_at timestamptz not null default now(),
  primary key (review_id, voter)
);

create table if not exists public.suggestions (
  id         uuid primary key default gen_random_uuid(),
  title      text not null check (char_length(title) between 2 and 60),
  why        text not null check (char_length(why) between 8 and 140),
  author     text not null default 'Anônimo(a)' check (char_length(author) <= 24),
  voter      uuid not null,
  hidden     boolean not null default false,   -- o admin pode esconder indicações
  created_at timestamptz not null default now()
);

create table if not exists public.suggestion_votes (
  suggestion_id uuid not null references public.suggestions(id) on delete cascade,
  voter         uuid not null,
  primary key (suggestion_id, voter)
);

alter table public.ratings          enable row level security;
alter table public.poll_votes       enable row level security;
alter table public.review_votes     enable row level security;
alter table public.suggestions      enable row level security;
alter table public.suggestion_votes enable row level security;

-- Visitantes não têm acesso direto a nada disso.
revoke all on public.admins, public.ratings, public.poll_votes, public.review_votes,
              public.suggestions, public.suggestion_votes from anon, authenticated;
revoke all on public.content from anon, authenticated;
grant select on public.content to anon, authenticated;
grant insert, update, delete on public.content to authenticated;

-- Admin pode ler os votos e moderar as indicações.
grant select on public.ratings, public.poll_votes, public.review_votes,
                public.suggestion_votes to authenticated;
grant select, update, delete on public.suggestions to authenticated;

drop policy if exists "ratings_admin_read" on public.ratings;
create policy "ratings_admin_read" on public.ratings
  for select to authenticated using (public.is_admin());

drop policy if exists "poll_votes_admin_read" on public.poll_votes;
create policy "poll_votes_admin_read" on public.poll_votes
  for select to authenticated using (public.is_admin());

drop policy if exists "review_votes_admin_read" on public.review_votes;
create policy "review_votes_admin_read" on public.review_votes
  for select to authenticated using (public.is_admin());

drop policy if exists "suggestion_votes_admin_read" on public.suggestion_votes;
create policy "suggestion_votes_admin_read" on public.suggestion_votes
  for select to authenticated using (public.is_admin());

drop policy if exists "suggestions_admin" on public.suggestions;
create policy "suggestions_admin" on public.suggestions
  for all to authenticated
  using (public.is_admin()) with check (public.is_admin());

-- ---------------------------------------------------------------------
-- 4) FUNÇÕES QUE O SITE CHAMA
-- ---------------------------------------------------------------------

-- Nota de 1 a 5 ovos. Votar de novo troca a nota.
create or replace function public.rate_item(p_item text, p_voter uuid, p_stars int)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_item is null or p_voter is null or p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'voto inválido';
  end if;
  insert into ratings (item_id, voter, stars)
  values (left(p_item, 80), p_voter, p_stars)
  on conflict (item_id, voter)
  do update set stars = excluded.stars, updated_at = now();
end
$$;

-- Voto na enquete. Votar de novo troca a opção.
create or replace function public.vote_poll(p_poll text, p_voter uuid, p_option text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_poll is null or p_voter is null or p_option is null then
    raise exception 'voto inválido';
  end if;
  insert into poll_votes (poll_id, voter, option_id)
  values (left(p_poll, 80), p_voter, left(p_option, 80))
  on conflict (poll_id, voter)
  do update set option_id = excluded.option_id, updated_at = now();
end
$$;

-- "Concordo / nem a pau" da resenha.
create or replace function public.vote_review(p_review text, p_voter uuid, p_agree boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_review is null or p_voter is null or p_agree is null then
    raise exception 'voto inválido';
  end if;
  insert into review_votes (review_id, voter, agree)
  values (left(p_review, 80), p_voter, p_agree)
  on conflict (review_id, voter)
  do update set agree = excluded.agree, updated_at = now();
end
$$;

-- Indicação de filme ou série (máximo 5 por pessoa por dia).
create or replace function public.submit_suggestion(p_title text, p_why text, p_author text, p_voter uuid)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
begin
  if p_voter is null then
    raise exception 'voto inválido';
  end if;
  if (select count(*) from suggestions
       where voter = p_voter and created_at > now() - interval '1 day') >= 5 then
    raise exception 'limite diário de indicações';
  end if;
  insert into suggestions (title, why, author, voter)
  values (
    btrim(p_title),
    btrim(p_why),
    coalesce(nullif(btrim(p_author), ''), 'Anônimo(a)'),
    p_voter
  )
  returning id into new_id;
  return new_id;
end
$$;

-- Curtir (ou tirar a curtida de) uma indicação.
create or replace function public.upvote_suggestion(p_id uuid, p_voter uuid, p_on boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if p_id is null or p_voter is null then
    raise exception 'voto inválido';
  end if;
  if not exists (select 1 from suggestions where id = p_id and not hidden) then
    raise exception 'indicação não encontrada';
  end if;
  if coalesce(p_on, true) then
    insert into suggestion_votes (suggestion_id, voter)
    values (p_id, p_voter)
    on conflict do nothing;
  else
    delete from suggestion_votes where suggestion_id = p_id and voter = p_voter;
  end if;
end
$$;

-- Placar de todo mundo, numa chamada só.
create or replace function public.public_stats()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'ratings', coalesce((
      select jsonb_object_agg(item_id, jsonb_build_object('n', n, 'sum', s))
      from (select item_id, count(*) as n, sum(stars) as s from ratings group by item_id) r
    ), '{}'::jsonb),
    'poll', coalesce((
      select jsonb_object_agg(poll_id, opts)
      from (
        select poll_id, jsonb_object_agg(option_id, c) as opts
        from (select poll_id, option_id, count(*) as c from poll_votes group by poll_id, option_id) x
        group by poll_id
      ) y
    ), '{}'::jsonb),
    'review', coalesce((
      select jsonb_object_agg(review_id, jsonb_build_object('yes', y, 'no', n))
      from (
        select review_id,
               count(*) filter (where agree)     as y,
               count(*) filter (where not agree) as n
        from review_votes group by review_id
      ) z
    ), '{}'::jsonb),
    'suggestions', coalesce((
      select jsonb_agg(jsonb_build_object(
               'id', t.id, 'title', t.title, 'why', t.why, 'author', t.author, 'votes', t.votes
             ) order by t.votes desc, t.created_at desc)
      from (
        select s.id, s.title, s.why, s.author, s.created_at, coalesce(v.c, 0) as votes
        from suggestions s
        left join (select suggestion_id, count(*) as c from suggestion_votes group by suggestion_id) v
               on v.suggestion_id = s.id
        where not s.hidden
        order by coalesce(v.c, 0) desc, s.created_at desc
        limit 50
      ) t
    ), '[]'::jsonb)
  )
$$;

-- O que ESTE navegador já votou (pra mostrar sua nota e sua escolha).
create or replace function public.my_votes(p_voter uuid)
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select jsonb_build_object(
    'ratings', coalesce((select jsonb_object_agg(item_id, stars) from ratings where voter = p_voter), '{}'::jsonb),
    'poll',    coalesce((select jsonb_object_agg(poll_id, option_id) from poll_votes where voter = p_voter), '{}'::jsonb),
    'review',  coalesce((select jsonb_object_agg(review_id, agree) from review_votes where voter = p_voter), '{}'::jsonb),
    'suggestion_votes', coalesce((select jsonb_agg(suggestion_id) from suggestion_votes where voter = p_voter), '[]'::jsonb),
    'my_suggestions',   coalesce((select jsonb_agg(id) from suggestions where voter = p_voter), '[]'::jsonb)
  )
$$;

-- Quem pode chamar o quê.
revoke all on function public.rate_item(text, uuid, int)                  from public;
revoke all on function public.vote_poll(text, uuid, text)                 from public;
revoke all on function public.vote_review(text, uuid, boolean)            from public;
revoke all on function public.submit_suggestion(text, text, text, uuid)   from public;
revoke all on function public.upvote_suggestion(uuid, uuid, boolean)      from public;
revoke all on function public.public_stats()                              from public;
revoke all on function public.my_votes(uuid)                              from public;

grant execute on function public.rate_item(text, uuid, int)                to anon, authenticated;
grant execute on function public.vote_poll(text, uuid, text)               to anon, authenticated;
grant execute on function public.vote_review(text, uuid, boolean)          to anon, authenticated;
grant execute on function public.submit_suggestion(text, text, text, uuid) to anon, authenticated;
grant execute on function public.upvote_suggestion(uuid, uuid, boolean)    to anon, authenticated;
grant execute on function public.public_stats()                            to anon, authenticated;
grant execute on function public.my_votes(uuid)                            to anon, authenticated;
