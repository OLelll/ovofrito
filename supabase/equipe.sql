-- Equipe: admins dão (e tiram) acesso de admin a contas de leitores, pelo painel.
-- Só funciona pra quem já é admin. Contas sem e-mail confirmado/existente não são encontradas.
create or replace function public.list_admins()
returns table(user_id uuid, email text)
language plpgsql stable security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'sem permissão'; end if;
  return query select a.user_id, u.email::text from public.admins a left join auth.users u on u.id = a.user_id order by u.email;
end $$;

create or replace function public.add_admin_by_email(p_email text)
returns text
language plpgsql security definer set search_path = public, auth as $$
declare uid uuid;
begin
  if not public.is_admin() then raise exception 'sem permissão'; end if;
  select id into uid from auth.users where lower(email) = lower(trim(p_email)) limit 1;
  if uid is null then raise exception 'conta não encontrada: a pessoa precisa criar a conta no site primeiro'; end if;
  insert into public.admins(user_id) values (uid) on conflict do nothing;
  return 'ok';
end $$;

create or replace function public.remove_admin(p_user uuid)
returns text
language plpgsql security definer set search_path = public, auth as $$
begin
  if not public.is_admin() then raise exception 'sem permissão'; end if;
  if p_user = auth.uid() then raise exception 'você não pode tirar o próprio acesso'; end if;
  delete from public.admins where user_id = p_user;
  return 'ok';
end $$;

revoke all on function public.list_admins(), public.add_admin_by_email(text), public.remove_admin(uuid) from public, anon;
grant execute on function public.list_admins(), public.add_admin_by_email(text), public.remove_admin(uuid) to authenticated;
