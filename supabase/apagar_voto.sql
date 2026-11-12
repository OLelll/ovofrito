-- Permite ao leitor apagar a própria nota.
create or replace function public.unrate(p_item text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if auth.uid() is null then
    raise exception 'entre na sua conta';
  end if;
  delete from ratings where item_id = p_item and voter = auth.uid();
end
$$;
revoke all on function public.unrate(text) from public, anon;
grant execute on function public.unrate(text) to authenticated;
