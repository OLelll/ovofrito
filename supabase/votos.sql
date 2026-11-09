-- =====================================================================
-- OVO FRITO!  ·  Notas (frigideirinhas) de verdade, por conta de leitor
--
-- Rode DEPOIS do schema.sql (que cria a tabela "ratings" e "public_stats").
-- Supabase > SQL Editor > New query > cole tudo > Run. Pode rodar de novo.
--
-- O que muda: só quem tem conta (com e-mail confirmado) dá nota, e cada
-- conta tem UMA nota por filme/série (votar de novo troca a nota).
-- O voto antigo, aberto a qualquer navegador, é fechado.
-- =====================================================================

create or replace function public.rate(p_item text, p_stars int)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'entre na sua conta pra votar';
  end if;
  if p_item is null or char_length(p_item) not between 1 and 80
     or p_stars is null or p_stars < 1 or p_stars > 5 then
    raise exception 'voto inválido';
  end if;
  insert into ratings (item_id, voter, stars)
  values (p_item, auth.uid(), p_stars)
  on conflict (item_id, voter)
  do update set stars = excluded.stars, updated_at = now();
end
$$;

create or replace function public.my_ratings()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_object_agg(item_id, stars), '{}'::jsonb)
  from ratings where voter = auth.uid()
$$;

revoke all on function public.rate(text, int) from public, anon;
revoke all on function public.my_ratings()    from public, anon;
grant execute on function public.rate(text, int) to authenticated;
grant execute on function public.my_ratings()    to authenticated;

-- fecha a porta antiga (voto anônimo por navegador)
revoke execute on function public.rate_item(text, uuid, int) from anon, authenticated;
