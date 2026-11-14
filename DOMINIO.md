# Colocar o Ovo Frito num domínio próprio (Vercel)

1. vercel.com → entrar com o GitHub → **Add New → Project** → escolher o repositório `ovofrito` → **Deploy** (sem mudar nada).
2. Em **Settings → Domains**, adicionar o domínio e seguir as instruções de DNS que a Vercel mostrar.
3. No Supabase, em **Authentication → URL Configuration**, trocar o *Site URL* pelo domínio novo e adicionar o domínio em *Redirect URLs* (senão o link de confirmação de e-mail leva pro endereço antigo).
4. Quando quiser aparecer no Google: pedir pra remover a tag `noindex` do `index.html` e enviar `https://SEU-DOMINIO/sitemap.xml` no Google Search Console.

No domínio próprio as matérias viram `/materia/slug` (com título, descrição e capa nas prévias de link). No GitHub Pages continuam `#materia-slug`.
