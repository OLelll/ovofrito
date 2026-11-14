-- =====================================================================
-- FASE 2 · rode SÓ DEPOIS que o site novo (que lê por public_articles)
-- estiver no ar na Vercel e no GitHub Pages. Fecha a leitura pública
-- direta das matérias: agendadas deixam de ser legíveis por visitantes.
-- Admin continua lendo tudo.
-- =====================================================================
drop policy if exists "content_read" on public.content;
create policy "content_read" on public.content
  for select to anon, authenticated
  using (key <> 'articles' or public.is_admin());
